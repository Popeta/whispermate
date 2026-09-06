import AVFoundation
internal import Combine
import FluidAudio
import Foundation
import WhisperMateShared

/// On-device transcription service using NVIDIA Parakeet model via FluidAudio
/// Provides private, offline, low-latency speech recognition on Apple Silicon
class ParakeetTranscriptionService: ObservableObject {
    static let shared = ParakeetTranscriptionService()

    // MARK: - Types

    enum ServiceState {
        case notInitialized
        case downloading
        case initializing
        case ready
        case transcribing
        case error(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    // MARK: - Published Properties

    @Published var state: ServiceState = .notInitialized
    @Published var isModelDownloaded: Bool = false

    // MARK: - Private Properties

    private var asrManager: AsrManager?
    private var models: AsrModels?
    private let audioConverter = AudioConverter()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Download and initialize the Parakeet model (v3 multilingual)
    func initialize() async throws {
        guard case .notInitialized = state else {
            DebugLog.info("Already initialized or in progress", context: "ParakeetTranscriptionService")
            return
        }

        await MainActor.run {
            self.state = .downloading
        }

        do {
            DebugLog.info("Downloading Parakeet v3 multilingual model...", context: "ParakeetTranscriptionService")

            // Download v3 multilingual model (will use cache if already downloaded)
            let downloadedModels = try await AsrModels.downloadAndLoad(version: .v3)

            await MainActor.run {
                self.state = .initializing
                self.models = downloadedModels
            }

            DebugLog.info("Initializing ASR manager...", context: "ParakeetTranscriptionService")

            // Initialize ASR manager (FluidAudio API: loadModels(_:))
            let manager = AsrManager(config: .default)
            try await manager.loadModels(downloadedModels)

            await MainActor.run {
                self.asrManager = manager
                self.state = .ready
                self.isModelDownloaded = true
            }

            DebugLog.info("Parakeet model ready", context: "ParakeetTranscriptionService")

            // Словарь поднимаем отдельно и не блокируя готовность: не поднялся —
            // диктовка работает как раньше, без бустинга.
            Task { await Self.prepareVocabularyBoosting() }

        } catch {
            DebugLog.error("Failed to initialize Parakeet: \(error.localizedDescription)", context: "ParakeetTranscriptionService")
            await MainActor.run {
                self.state = .error(error.localizedDescription)
            }
            throw error
        }
    }

    /// Transcribe audio file to text
    /// - Parameter audioURL: URL to audio file (any format supported by AVFoundation)
    /// - Returns: Transcribed text
    func transcribe(audioURL: URL) async throws -> String {
        // Initialize if needed
        if case .notInitialized = state {
            try await initialize()
        }

        guard let manager = asrManager else {
            throw NSError(domain: "ParakeetTranscriptionService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "ASR manager not initialized"])
        }

        await MainActor.run {
            self.state = .transcribing
        }

        defer {
            Task { @MainActor in
                self.state = .ready
            }
        }

        do {
            DebugLog.info("Transcribing audio file via FluidAudio (URL-based, auto-resample)...", context: "ParakeetTranscriptionService")

            // FluidAudio 0.15.x: состояние декодера держит вызывающая сторона.
            // Каждая диктовка независима, поэтому состояние всегда свежее —
            // иначе контекст предыдущей записи протекал бы в следующую.
            var decoderState = TdtDecoderState.make()

            // transcribe(_:decoderState:) принимает любой формат, понятный AVFoundation,
            // и сам ресемплит в 16 кГц моно.
            let result = try await manager.transcribe(audioURL, decoderState: &decoderState)

            DebugLog.info("Transcription complete: \(result.text.prefix(100))...", context: "ParakeetTranscriptionService")

            return await boostVocabulary(in: result, audioURL: audioURL)

        } catch {
            DebugLog.error("Transcription failed: \(error.localizedDescription)", context: "ParakeetTranscriptionService")
            throw error
        }
    }

    // MARK: - Vocabulary boosting

    /// Собрать сессию бустинга под включённые записи словаря.
    ///
    /// Термин для бустинга — это то, что мы хотим видеть в тексте (`replacement`),
    /// а то, что слышится вместо него (`trigger`), идёт алиасом.
    static func prepareVocabularyBoosting() async {
        let terms: [VocabularyBoostingService.Term] = await MainActor.run {
            DictionaryManager.shared.entries
                .filter { $0.isEnabled }
                .map { entry in
                    if let replacement = entry.replacement, !replacement.isEmpty {
                        return VocabularyBoostingService.Term(
                            text: replacement, aliases: [entry.trigger])
                    }
                    return VocabularyBoostingService.Term(text: entry.trigger)
                }
        }

        await VocabularyBoostingService.shared.prepare(terms: terms)
    }

    /// Переписать распознанный текст по акустике, если словарь поднят.
    ///
    /// Рескореру нужно то же аудио в 16 кГц моно, по которому получен транскрипт,
    /// и тайминги токенов на том же отсчёте времени.
    private func boostVocabulary(in result: ASRResult, audioURL: URL) async -> String {
        guard VocabularyBoostingService.isEnabled else { return result.text }
        guard let tokenTimings = result.tokenTimings, !tokenTimings.isEmpty else {
            return result.text
        }

        do {
            let samples = try audioConverter.resampleAudioFile(audioURL)
            return await VocabularyBoostingService.shared.rescore(
                text: result.text, tokenTimings: tokenTimings, audioSamples: samples)
        } catch {
            DebugLog.error(
                "Vocabulary boosting skipped, resample failed: \(error.localizedDescription)",
                context: "ParakeetTranscriptionService")
            return result.text
        }
    }

    /// Cleanup resources
    func cleanup() {
        let manager = asrManager
        asrManager = nil
        models = nil
        Task {
            await manager?.cleanup()
            await MainActor.run {
                self.state = .notInitialized
                self.isModelDownloaded = false
            }
        }
    }
}
