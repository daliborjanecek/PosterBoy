import AVFoundation

// MARK: - VideoLooper

/// Manages an AVPlayer with automatic looping and autoplay.
///
/// Uses AVPlayerLooper with AVQueuePlayer for seamless gapless looping.
/// Retains the looper and player for the lifetime of this object.
final class VideoLooper {

    let player: AVQueuePlayer
    private let playerItem: AVPlayerItem
    private var looper: AVPlayerLooper?

    /// Create a looping video player.
    /// - Parameter url: URL to the video file.
    init(url: URL) {
        let asset = AVURLAsset(url: url)
        self.playerItem = AVPlayerItem(asset: asset)
        self.player = AVQueuePlayer(items: [playerItem])

        // AVPlayerLooper needs to be retained — it manages the loop internally
        self.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(asset: asset))

        // Mute by default — AR overlays usually don't need audio
        player.isMuted = true
    }

    /// Start playback.
    func play() {
        player.play()
    }

    /// Pause playback.
    func pause() {
        player.pause()
    }

    /// Clean up resources.
    func stop() {
        player.pause()
        looper?.disableLooping()
        looper = nil
    }
}
