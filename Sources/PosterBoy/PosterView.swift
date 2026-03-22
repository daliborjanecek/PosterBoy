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

    // MARK: Initializers

    /// Create a PosterView with a single overlay.
    /// - Parameters:
    ///   - content: The overlay to display on the detected anchor.
    ///   - resourceGroup: Name of the AR Resource Group in the Xcode asset catalog.
    ///     Defaults to `"AR Resources"`.
    public init(content: PosterContent, resourceGroup: String = "AR Resources") {
        self.contents = [content]
        self.resourceGroupName = resourceGroup
    }

    /// Create a PosterView with multiple overlays.
    /// - Parameters:
    ///   - contents: Array of overlays, each tied to a different anchor.
    ///   - resourceGroup: Name of the AR Resource Group in the Xcode asset catalog.
    ///     Defaults to `"AR Resources"`.
    public init(contents: [PosterContent], resourceGroup: String = "AR Resources") {
        self.contents = contents
        self.resourceGroupName = resourceGroup
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
            onDetected: globalDetectedHandler,
            onLost: globalLostHandler
        )
    }

    public func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Disable unnecessary rendering features for better performance
        arView.renderOptions = [
            .disablePersonOcclusion,
            .disableDepthOfField,
            .disableMotionBlur
        ]

        context.coordinator.configure(arView: arView)
        return arView
    }

    public func updateUIView(_ uiView: ARView, context: Context) {
        // Contents are immutable after init — no dynamic updates needed.
        // If you need to change overlays, swap the entire PosterView.
    }

    public static func dismantleUIView(_ uiView: ARView, coordinator: PosterARCoordinator) {
        coordinator.cleanup()
        uiView.session.pause()
    }
}
