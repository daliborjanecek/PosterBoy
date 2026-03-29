import SwiftUI
import RealityKit

// MARK: - PosterView

/// A SwiftUI view that displays an AR camera feed and overlays images or videos
/// on detected reference images.
///
/// Usage:
/// ```swift
/// // Single overlay
/// PosterView(content: .image(anchor: "poster1", overlay: myImage))
///
/// // Multiple overlays with callbacks
/// PosterView(contents: [
///     .image(anchor: "poster1", overlay: heroImage)
///         .onDetected { print("Poster 1 found") },
///     .video(anchor: "poster2", overlay: videoURL)
/// ])
/// .onAnchorDetected { name in print("Detected: \(name)") }
/// .onAnchorLost { name in print("Lost: \(name)") }
/// ```
///
/// **Requirements:**
/// - Add an AR Resource Group to your Xcode project with reference images.
/// - Set the physical size for each reference image in the Xcode inspector.
/// - Add `NSCameraUsageDescription` to Info.plist.
public struct PosterView: UIViewRepresentable {

    // MARK: Properties

    private let contents: [PosterContent]
    private let resourceGroupName: String
    private var globalDetectedHandler: ((String) -> Void)?
    private var globalLostHandler: ((String) -> Void)?

    /// Controls whether the AR overlay layer is active.
    /// When `false`, only the camera feed is shown. When `true`, AR tracking starts and overlays appear.
    private var isActive: Bool

    /// Controls person occlusion — whether people (e.g. hands) appear in front of AR overlays.
    private var personOcclusion: PersonOcclusionMode

    // MARK: Initializers

    /// Create a PosterView with a single overlay.
    /// - Parameters:
    ///   - content: The overlay to display on the detected anchor.
    ///   - resourceGroup: Name of the AR Resource Group in the Xcode asset catalog.
    ///     Defaults to `"AR Resources"`.
    ///   - isActive: When `false` (default), only the camera feed is shown.
    ///     Set to `true` to start AR tracking and show overlays.
    ///   - personOcclusion: Whether people/hands appear in front of AR overlays.
    ///     Use `.automatic` to enable occlusion on supported devices. Defaults to `.disabled`.
    public init(content: PosterContent, resourceGroup: String = "AR Resources", isActive: Bool = true, personOcclusion: PersonOcclusionMode = .automatic) {
        self.contents = [content]
        self.resourceGroupName = resourceGroup
        self.isActive = isActive
        self.personOcclusion = personOcclusion
    }

    /// Create a PosterView with multiple overlays.
    /// - Parameters:
    ///   - contents: Array of overlays, each tied to a different anchor.
    ///   - resourceGroup: Name of the AR Resource Group in the Xcode asset catalog.
    ///     Defaults to `"AR Resources"`.
    ///   - isActive: When `false` (default), only the camera feed is shown.
    ///     Set to `true` to start AR tracking and show overlays.
    ///   - personOcclusion: Whether people/hands appear in front of AR overlays.
    ///     Use `.automatic` to enable occlusion on supported devices. Defaults to `.disabled`.
    public init(contents: [PosterContent], resourceGroup: String = "AR Resources", isActive: Bool = true, personOcclusion: PersonOcclusionMode = .automatic) {
        self.contents = contents
        self.resourceGroupName = resourceGroup
        self.isActive = isActive
        self.personOcclusion = personOcclusion
    }

    // MARK: Modifier-style callbacks

    /// Called when any anchor is detected or resumes tracking.
    /// - Parameter handler: Closure receiving the anchor name.
    public func onAnchorDetected(_ handler: @escaping (String) -> Void) -> PosterView {
        var copy = self
        copy.globalDetectedHandler = handler
        return copy
    }

    /// Called when any anchor loses tracking.
    /// - Parameter handler: Closure receiving the anchor name.
    public func onAnchorLost(_ handler: @escaping (String) -> Void) -> PosterView {
        var copy = self
        copy.globalLostHandler = handler
        return copy
    }

    // MARK: UIViewRepresentable

    public func makeCoordinator() -> PosterARCoordinator {
        PosterARCoordinator(
            contents: contents,
            resourceGroupName: resourceGroupName,
            personOcclusion: personOcclusion,
            onDetected: globalDetectedHandler,
            onLost: globalLostHandler
        )
    }

    public func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Disable rendering features not needed for image tracking
        arView.renderOptions = [
            .disableDepthOfField,
            .disableMotionBlur
        ]

        context.coordinator.setup(arView: arView)

        if isActive {
            context.coordinator.startTracking()
        }

        return arView
    }

    public func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.setActive(isActive)
    }

    public static func dismantleUIView(_ uiView: ARView, coordinator: PosterARCoordinator) {
        coordinator.cleanup()
        uiView.session.pause()
    }
}
