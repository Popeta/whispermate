import AppKit

/// Manages sound feedback for recording lifecycle events.
/// Restored from backup-170677f after upstream removed it.
/// Plays macOS system sounds at key transitions: recording start/stop, success, error.
class SoundFeedbackManager {
    static let shared = SoundFeedbackManager()

    // MARK: - Private Properties

    /// UserDefaults key for sound feedback toggle
    private static let soundFeedbackKey = "soundFeedbackEnabled"

    // MARK: - Public API

    /// Whether sound feedback is enabled
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.soundFeedbackKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.soundFeedbackKey) }
    }

    private init() {
        // Register default value (enabled by default)
        UserDefaults.standard.register(defaults: [Self.soundFeedbackKey: true])
    }

    /// Play sound when recording starts (Fn pressed)
    func playRecordingStartSound() {
        guard isEnabled else { return }
        playSystemSound("Tink")
    }

    /// Play sound when recording stops (Fn released, processing begins)
    func playRecordingStopSound() {
        guard isEnabled else { return }
        playSystemSound("Pop")
    }

    /// Play sound when transcription + paste completes successfully
    func playSuccessSound() {
        guard isEnabled else { return }
        playSystemSound("Glass")
    }

    /// Play sound when an error occurs (transcription failed, paste failed, etc.)
    func playErrorSound() {
        guard isEnabled else { return }
        NSSound.beep()
    }

    // MARK: - Private Methods

    /// Play a macOS system sound by name from /System/Library/Sounds/
    private func playSystemSound(_ name: String) {
        if let sound = NSSound(named: name) {
            sound.play()
        }
    }
}
