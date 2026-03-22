import UIKit

// MARK: - PosterContent

/// Defines what media to overlay on a detected AR image anchor.
///
/// Usage:
/// ```swift
/// // Static image overlay
/// .image(anchor: "poster1", overlay: UIImage(named: "hero")!)
///
/// // Looping video overlay
/// .video(anchor: "poster2", overlay: Bundle.main.url(forResource: "trailer", withExtension: "mp4")!)
///
/// // With per-anchor callbacks
/// .image(anchor: "poster1", overlay: myImage)
///     .onDetected { print("Found poster 1") }
///     .onLost { print("Lost poster 1") }
/// ```
public struct PosterContent {

    // MARK: Media type

    public enum MediaType {
        case image(UIImage)
        case video(URL)
    }

    // MARK: Properties

    /// Name of the reference image in the AR Resource Group (must match exactly).
    public let anchor: String

    /// The media to project onto the detected anchor.
    public let media: MediaType

    /// When `true`, the image overlay uses `PhysicallyBasedMaterial` that reacts
    /// to AR environment lighting. When `false` (default), uses `UnlitMaterial`
    /// for a bright, always-visible overlay.
    ///
    /// Has no effect on video overlays — `VideoMaterial` is always unlit.
    public let lit: Bool

    /// Called when this specific anchor starts being tracked.
    var detectedHandler: (() -> Void)?

    /// Called when this specific anchor stops being tracked.
    var lostHandler: (() -> Void)?

    // MARK: Factory methods

    /// Create an image overlay that will be projected on the detected anchor.
    /// - Parameters:
    ///   - anchor: Name of the reference image in AR Resource Group.
    ///   - overlay: The image to display. Its size on screen matches the anchor's physical size.
    ///   - lit: If `true`, the overlay reacts to AR environment lighting.
    ///     Default is `false` (bright, unlit). Has no effect on video.
    public static func image(anchor: String, overlay: UIImage, lit: Bool = false) -> PosterContent {
        PosterContent(anchor: anchor, media: .image(overlay), lit: lit)
    }

    /// Create a video overlay that auto-plays in a loop on the detected anchor.
    /// - Parameters:
    ///   - anchor: Name of the reference image in AR Resource Group.
    ///   - overlay: URL to the video file (local or remote).
    ///   - lit: Ignored for video (`VideoMaterial` is always unlit). Included for API consistency.
    public static func video(anchor: String, overlay: URL, lit: Bool = false) -> PosterContent {
        PosterContent(anchor: anchor, media: .video(overlay), lit: lit)
    }

    // MARK: Callback modifiers

    /// Add a handler called when this anchor is detected or resumes tracking.
    public func onDetected(_ handler: @escaping () -> Void) -> PosterContent {
        var copy = self
        copy.detectedHandler = handler
        return copy
    }

    /// Add a handler called when this anchor loses tracking.
    public func onLost(_ handler: @escaping () -> Void) -> PosterContent {
        var copy = self
        copy.lostHandler = handler
        return copy
    }
}
