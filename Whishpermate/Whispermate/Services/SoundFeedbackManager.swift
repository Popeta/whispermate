import AppKit

/// Manages sound feedback for recording lifecycle events
class SoundFeedbackManager {
    static let shared = SoundFeedbackManager()

    /// UserDefaults key for sound feedback toggle
    private static let soundFeedbackKey = "soundFeedbackEnabled"

    /// Whether sound feedback is enabled
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.soundFeedbackKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.soundFeedbackKey) }
    }

    private init() {
        // Register default value (enabled by default)
        UserDefaults.standard.register(defaults: [Self.soundFeedbackKey: true])
    }

    /// Play sound when recording starts
    func playRecordingStartSound() {
        guard isEnabled else { return }
        playSystemSound("Tink")
    }

    /// Play sound when recording stops (processing begins)
    func playRecordingStopSound() {
        guard isEnabled else { return }
        playSystemSound("Pop")
    }

    /// Play sound when transcription completes successfully
    func playSuccessSound() {
        guard isEnabled else { return }
        playSystemSound("Glass")
    }

    /// Play sound when an error occurs
    func playErrorSound() {
        guard isEnabled else { return }
        NSSound.beep()
    }

    /// Play a system sound by name
    private func playSystemSound(_ name: String) {
        if let sound = NSSound(named: name) {
            sound.play()
        }
    }
}
