import ARKit
import RealityKit
import AVFoundation

// MARK: - PersonOcclusionMode

/// Controls whether and how people are occluded in front of AR overlays.
public enum PersonOcclusionMode {
    /// No person occlusion — AR overlays always appear on top (default on unsupported devices).
    case disabled

    /// Automatically selects the best available mode:
    /// - LiDAR devices: depth-based occlusion (most realistic)
    /// - Face ID devices without LiDAR: 2D segmentation
    /// - Older devices: silently falls back to no occlusion
    case automatic
}

// MARK: - PosterARCoordinator

/// Manages the AR session, image anchor detection, entity creation, and tracking callbacks.
///
/// Acts as `ARSessionDelegate` and creates RealityKit entities when image anchors
/// are detected. Handles both image and video overlays.
@MainActor
public class PosterARCoordinator: NSObject, @preconcurrency ARSessionDelegate {

    // MARK: Configuration

    private let contents: [PosterContent]
    private let resourceGroupName: String
    private let personOcclusion: PersonOcclusionMode

    // MARK: Global callbacks

    private let onDetected: ((String) -> Void)?
    private let onLost: ((String) -> Void)?

    // MARK: State

    private weak var arView: ARView?

    /// Fast lookup: anchor name → content definition
    private var contentMap: [String: PosterContent] = [:]

    /// Anchor entities added to the scene, keyed by anchor name
    private var anchorEntities: [String: AnchorEntity] = [:]

    /// Current tracking state per anchor name
    private var trackingState: [String: Bool] = [:]

    /// Video loopers retained for the lifetime of the overlay
    private var videoLoopers: [String: VideoLooper] = [:]

    /// Whether the AR image tracking session is currently running
    private var isTrackingActive = false

    // MARK: Init

    init(
        contents: [PosterContent],
        resourceGroupName: String,
        personOcclusion: PersonOcclusionMode,
        onDetected: ((String) -> Void)?,
        onLost: ((String) -> Void)?
    ) {
        self.contents = contents
        self.resourceGroupName = resourceGroupName
        self.personOcclusion = personOcclusion
        self.onDetected = onDetected
        self.onLost = onLost
        super.init()

        for content in contents {
            contentMap[content.anchor] = content
        }
    }

    // MARK: - Setup

    /// Attach the ARView and register as session delegate, but do not start AR tracking yet.
    /// Call `startTracking()` to begin image detection and overlay display.
    func setup(arView: ARView) {
        self.arView = arView
        arView.session.delegate = self
    }

    /// Start the AR image tracking session and enable overlays.
    /// Safe to call multiple times — subsequent calls are ignored if already active.
    func startTracking() {
        guard let arView = arView, !isTrackingActive else { return }

        // Load reference images from the app's AR Resource Group
        guard let allReferenceImages = ARReferenceImage.referenceImages(
            inGroupNamed: resourceGroupName,
            bundle: Bundle.main
        ) else {
            print("[PosterBoy] ⚠️ AR Resource Group '\(resourceGroupName)' not found in main bundle.")
            return
        }

        // Only track images that have a matching PosterContent
        let anchorNames = Set(contents.map(\.anchor))
        let trackingImages = allReferenceImages.filter { image in
            guard let name = image.name else { return false }
            return anchorNames.contains(name)
        }

        guard !trackingImages.isEmpty else {
            print("[PosterBoy] ⚠️ No matching reference images found. Check that anchor names match AR Resource Group image names.")
            return
        }

        // ARWorldTrackingConfiguration supports person occlusion unlike ARImageTrackingConfiguration
        let config = ARWorldTrackingConfiguration()
        config.detectionImages = trackingImages
        config.maximumNumberOfTrackedImages = trackingImages.count

        // Apply best available person occlusion based on device capabilities
        applyPersonOcclusion(to: config)

        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        isTrackingActive = true
    }

    /// Apply the best available person occlusion mode to the configuration.
    private func applyPersonOcclusion(to config: ARWorldTrackingConfiguration) {
        guard personOcclusion != .disabled else { return }

        // Try depth-based occlusion first (requires LiDAR)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
            print("[PosterBoy] Person occlusion: depth-based (LiDAR)")
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            // Fallback: 2D segmentation (Face ID devices without LiDAR)
            config.frameSemantics.insert(.personSegmentation)
            print("[PosterBoy] Person occlusion: 2D segmentation (no LiDAR)")
        } else {
            print("[PosterBoy] Person occlusion: not supported on this device")
        }
    }

    /// Stop AR tracking and hide all overlays.
    func stopTracking() {
        guard isTrackingActive else { return }
        arView?.session.pause()
        isTrackingActive = false

        // Hide all existing overlays
        for entity in anchorEntities.values {
            entity.isEnabled = false
        }
        for looper in videoLoopers.values {
            looper.pause()
        }
    }

    /// Activate or deactivate AR tracking based on the provided flag.
    func setActive(_ active: Bool) {
        if active {
            startTracking()
        } else {
            stopTracking()
        }
    }

    /// Stop tracking and release all resources.
    func cleanup() {
        for (_, looper) in videoLoopers {
            looper.stop()
        }
        videoLoopers.removeAll()
        anchorEntities.removeAll()
        trackingState.removeAll()
    }

    // MARK: - ARSessionDelegate

    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            guard
                let imageAnchor = anchor as? ARImageAnchor,
                let name = imageAnchor.referenceImage.name,
                let content = contentMap[name]
            else { continue }

            addOverlay(for: imageAnchor, content: content)
        }
    }

    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard
                let imageAnchor = anchor as? ARImageAnchor,
                let name = imageAnchor.referenceImage.name,
                contentMap[name] != nil
            else { continue }

            let wasTracked = trackingState[name] ?? false
            let isNowTracked = imageAnchor.isTracked

            if isNowTracked && !wasTracked {
                // Anchor regained tracking
                trackingState[name] = true
                anchorEntities[name]?.isEnabled = true
                videoLoopers[name]?.play()

                contentMap[name]?.detectedHandler?()
                onDetected?(name)
            } else if !isNowTracked && wasTracked {
                // Anchor lost tracking
                trackingState[name] = false
                anchorEntities[name]?.isEnabled = false
                videoLoopers[name]?.pause()

                contentMap[name]?.lostHandler?()
                onLost?(name)
            }
        }
    }

    // MARK: - Overlay creation

    private func addOverlay(for imageAnchor: ARImageAnchor, content: PosterContent) {
        guard let arView = arView else { return }

        let name = content.anchor
        let physicalSize = imageAnchor.referenceImage.physicalSize

        // Create anchor entity bound to the detected image
        let anchorEntity = AnchorEntity(anchor: imageAnchor)

        // Create a plane matching the physical size of the reference image
        // generatePlane(width:depth:) creates a horizontal (XZ) plane,
        // which aligns with the image anchor's coordinate system
        let mesh = MeshResource.generatePlane(
            width: Float(physicalSize.width),
            depth: Float(physicalSize.height)
        )

        let material: RealityKit.Material

        switch content.media {
        case .image(let overlayImage):
            material = makeImageMaterial(from: overlayImage, lit: content.lit)

        case .video(let url):
            let looper = VideoLooper(url: url)
            material = VideoMaterial(avPlayer: looper.player)
            looper.play()
            videoLoopers[name] = looper
        }

        let overlayEntity = ModelEntity(mesh: mesh, materials: [material])

        // Slight Y offset to prevent z-fighting with the real surface
        overlayEntity.position.y = 0.001

        anchorEntity.addChild(overlayEntity)
        arView.scene.addAnchor(anchorEntity)

        anchorEntities[name] = anchorEntity
        trackingState[name] = true

        // Fire initial detection callbacks
        content.detectedHandler?()
        onDetected?(name)
    }

    // MARK: - Material helpers

    private func makeImageMaterial(from image: UIImage, lit: Bool) -> RealityKit.Material {
        guard let cgImage = image.cgImage else {
            print("[PosterBoy] ⚠️ Could not get CGImage from overlay UIImage. Using fallback color.")
            var fallback = UnlitMaterial()
            fallback.color = .init(tint: .magenta)
            return fallback
        }

        do {
            let texture = try TextureResource.generate(
                from: cgImage,
                options: .init(semantic: .color)
            )

            if lit {
                // PhysicallyBasedMaterial reacts to AR environment lighting
                var material = PhysicallyBasedMaterial()
                material.baseColor = .init(tint: .white, texture: .init(texture))
                material.roughness = .init(floatLiteral: 0.5)
                material.metallic = .init(floatLiteral: 0.0)
                return material
            } else {
                // UnlitMaterial ignores lighting — bright and always visible
                var material = UnlitMaterial()
                material.color = .init(tint: .white, texture: .init(texture))
                return material
            }
        } catch {
            print("[PosterBoy] ⚠️ Failed to create texture: \(error.localizedDescription)")
            var fallback = UnlitMaterial()
            fallback.color = .init(tint: .magenta)
            return fallback
        }
    }
}
