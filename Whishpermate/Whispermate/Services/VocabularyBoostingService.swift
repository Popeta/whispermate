import FluidAudio
import Foundation
import WhisperMateShared

/// Поднимает доменные термины из пользовательского словаря на этапе распознавания.
///
/// До этого словарь правил только готовый текст (пост-замены в `TranscriptionOutputFilter`):
/// Parakeet выдавал "вискер мейт", а таблица чинила строку по точному совпадению.
/// Здесь работает CTC-рескоринг (подход NeMo CTC-WS): отдельная CTC-модель прогоняется
/// по тому же аудио, и слово заменяется на термин из словаря, если акустика ближе к
/// термину, чем к тому, что выбрал TDT-декодер. Формы, которых нет в таблице замен,
/// тоже чинятся — сравнение идёт по звуку, а не по строке.
///
/// Пост-замены остаются: они нормализуют регистр и написание уже поверх этого.
actor VocabularyBoostingService {
    static let shared = VocabularyBoostingService()

    // MARK: - Feature flag

    private static let enabledKey = "vocabularyBoostingEnabled"

    /// 🚨 ПО УМОЛЧАНИЮ ВЫКЛЮЧЕНО — замер 07.09.2026 на записях Vitalii.
    ///
    /// CTC-рескоринг опирается на модель `parakeet-ctc-110m`, а она обучена ТОЛЬКО
    /// на английском. Над русской речью её акустические оценки — шум, и словарь
    /// из латинских терминов затирает русские слова. Замер на реальной диктовке
    /// («Марина скинула онбординг Коинснэп»), словарь из 5 терминов:
    ///
    ///   без бустинга      → «Посмотри файл в телеграмме… онбординг Коинснэп…»
    ///   бустинг, дефолты  → «Caffeinate watchlist в watchlist watchlist Watchlist…»
    ///   бустинг, rescue off → текст не изменился (и «Коинснэп» тоже НЕ починился)
    ///
    /// Порог `minSimilarity` не спасает: 0.85 и 0.55 дают одинаковый мусор —
    /// ломает не он, а acoustic rescue pass. Поэтому даже при включении флага
    /// rescue держим выключенным.
    ///
    /// Включать имеет смысл только под диктовку НА АНГЛИЙСКОМ:
    /// `defaults write com.whispermate.macos.debug vocabularyBoostingEnabled -bool true`
    static var isEnabled: Bool {
        AppDefaults.shared.bool(forKey: enabledKey)
    }

    /// Acoustic rescue — источник затирания русских слов (#724 в FluidAudio).
    /// Держим выключенным всегда, даже когда бустинг включён.
    private static let rescorerConfig = VocabularyRescorer.Config(spotterRescueEnabled: false)

    // MARK: - State

    private var session: VocabularyBoostingSession?
    /// Сигнатура словаря, на котором собрана текущая сессия. Меняется словарь — пересобираем.
    private var loadedSignature: String?
    /// Один раз упавшая загрузка не должна дёргать сеть на каждой диктовке.
    private var loadFailed = false

    private init() {}

    // MARK: - Public API

    /// Термин для бустинга — это то, что мы хотим ВИДЕТЬ, а не то, что слышится.
    /// Для записи «AI dictation → AIDictation» бустим `AIDictation`, а `AI dictation`
    /// кладём в алиасы: рескорер ищет и по нему тоже.
    struct Term: Hashable, Sendable {
        let text: String
        let aliases: [String]

        init(text: String, aliases: [String] = []) {
            self.text = text
            self.aliases = aliases
        }
    }

    /// Построить (или переиспользовать) сессию бустинга под текущий словарь.
    ///
    /// Первый вызов тянет CTC-модель (~50 МБ) в общий кэш FluidAudio — дальше берётся с диска.
    func prepare(terms: [Term]) async {
        guard Self.isEnabled else { return }

        let usable = Self.usableTerms(terms)
        guard !usable.isEmpty else {
            session = nil
            loadedSignature = nil
            return
        }

        let signature = Self.signature(for: usable)
        if signature == loadedSignature, session != nil { return }
        if loadFailed { return }

        do {
            let ctcModels = try await CtcModels.downloadAndLoad(variant: .ctc110m)
            let tokenizer = try await CtcTokenizer.load(
                from: CtcModels.defaultCacheDirectory(for: .ctc110m)
            )

            let vocabularyTerms: [CustomVocabularyTerm] = usable.compactMap { term in
                let tokenIds = tokenizer.encode(term.text)
                guard !tokenIds.isEmpty else {
                    DebugLog.info(
                        "Term '\(term.text)' produced no CTC tokens, skipped",
                        context: "VocabularyBoosting")
                    return nil
                }
                return CustomVocabularyTerm(
                    text: term.text,
                    aliases: term.aliases.isEmpty ? nil : term.aliases,
                    ctcTokenIds: tokenIds
                )
            }

            guard !vocabularyTerms.isEmpty else {
                session = nil
                loadedSignature = nil
                return
            }

            let context = CustomVocabularyContext(terms: vocabularyTerms)
            session = try await VocabularyBoostingSession(
                vocabulary: context, ctcModels: ctcModels, config: Self.rescorerConfig)
            loadedSignature = signature

            DebugLog.info(
                "Vocabulary boosting ready with \(vocabularyTerms.count) term(s)",
                context: "VocabularyBoosting")
        } catch {
            // Бустинг — необязательный слой. Не смог подняться — диктовка работает как раньше.
            loadFailed = true
            session = nil
            loadedSignature = nil
            DebugLog.error(
                "Vocabulary boosting unavailable: \(error.localizedDescription)",
                context: "VocabularyBoosting")
        }
    }

    /// Переписать транскрипт по акустике. Возвращает исходный текст, если сессии нет
    /// или заменять нечего.
    ///
    /// - Parameters:
    ///   - text: транскрипт от Parakeet
    ///   - tokenTimings: тайминги токенов, тот же отсчёт времени, что у `audioSamples`
    ///   - audioSamples: то же аудио 16 кГц моно, по которому получен транскрипт
    func rescore(
        text: String,
        tokenTimings: [TokenTiming]?,
        audioSamples: [Float]
    ) async -> String {
        guard Self.isEnabled, let session else { return text }
        guard let tokenTimings, !tokenTimings.isEmpty, !audioSamples.isEmpty else { return text }

        guard let output = await session.rescore(
            text: text, tokenTimings: tokenTimings, audioSamples: audioSamples)
        else { return text }

        guard output.wasModified else { return text }

        let applied = output.replacements
            .filter { $0.shouldReplace }
            .map { "\($0.originalWord) → \($0.replacementWord ?? "")" }
            .joined(separator: ", ")
        DebugLog.info("Vocabulary boosting applied: \(applied)", context: "VocabularyBoosting")

        return output.text
    }

    /// Сбросить сессию (например, при выходе из локального режима).
    func reset() {
        session = nil
        loadedSignature = nil
        loadFailed = false
    }

    // MARK: - Helpers

    /// Библиотека сама отбрасывает термины короче `minTermLength` (3 символа) — короткие
    /// слова дают ложные срабатывания («or» → «VR»). Отсекаем здесь же, чтобы сигнатура
    /// не менялась из-за терминов, которые всё равно не доедут.
    private static func usableTerms(_ terms: [Term]) -> [Term] {
        var seen = Set<String>()
        return terms.compactMap { term in
            let text = term.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 3 else { return nil }
            guard seen.insert(text.lowercased()).inserted else { return nil }
            let aliases = term.aliases
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.lowercased() != text.lowercased() }
            return Term(text: text, aliases: aliases)
        }
    }

    private static func signature(for terms: [Term]) -> String {
        terms
            .map { "\($0.text)|\($0.aliases.joined(separator: ","))" }
            .sorted()
            .joined(separator: "\n")
    }
}
