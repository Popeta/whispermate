# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Обзор проекта

**WhisperMate** — macOS приложение для голосовой транскрипции с глобальным hotkey, автопастой и AI-форматированием текста.

- **Платформы:** macOS 14+ (основное), iOS 15+ (через WhisperMateIOS target)
- **Стек:** Swift 5.0/6.0, SwiftUI, AVFoundation, CoreML, FluidAudio (Parakeet local STT), Sparkle (auto-update)
- **Версия:** актуальная из upstream `writingmate/aidictation` (sync 2026-04-10)
- **Локальный форк:** независим от writingmate.ai (Supabase Auth удалён намеренно)

## Команды разработки

```bash
# Открыть проект
cd Whishpermate && open Whispermate.xcodeproj

# Debug сборка (ad-hoc подпись, без Keychain промптов)
xcodebuild -project Whishpermate/Whispermate.xcodeproj -scheme Whispermate -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO build

# Release сборка
xcodebuild -project Whishpermate/Whispermate.xcodeproj -scheme Whispermate -configuration Release build

# Установка Debug сборки
cp -R ~/Library/Developer/Xcode/DerivedData/Whispermate-*/Build/Products/Debug/Whispermate.app ~/Applications/

# Подпись и нотаризация (когда запрошен релиз)
./sign-and-notarize.sh
```

## Структура проекта

```
whispermate/
├── Whishpermate/                          # Xcode project root
│   ├── Whispermate.xcodeproj
│   ├── Whispermate/                       # macOS app (основное)
│   │   ├── WhispermateApp.swift           # Entry point
│   │   ├── Views/
│   │   │   ├── ContentView.swift          # Главное окно
│   │   │   ├── SettingsView.swift         # Настройки (с API Picker)
│   │   │   └── OnboardingView.swift       # Permissions wizard
│   │   ├── Services/                      # 30+ сервисов
│   │   │   ├── AudioRecorder.swift        # AVAudioRecorder + AVAudioEngine
│   │   │   ├── OpenAIClient.swift         # Cloud unified API client
│   │   │   ├── ParakeetTranscriptionService.swift  # Local STT (FluidAudio)
│   │   │   ├── HotkeyManager.swift        # Global hotkey
│   │   │   ├── AppState.swift             # Centralized state
│   │   │   ├── AudioDeviceManager.swift   # Mic device picker
│   │   │   ├── ClipboardManager.swift     # Clipboard handling
│   │   │   ├── CommandModeManager.swift   # Command mode
│   │   │   ├── LaunchAtLoginManager.swift # Auto-launch
│   │   │   ├── NetworkMonitor.swift       # Network state
│   │   │   ├── ScreenCaptureManager.swift # OCR context
│   │   │   ├── TranscriptionOutputFilter.swift  # Output filter
│   │   │   ├── UpdateManager.swift        # Sparkle auto-update
│   │   │   └── ...
│   │   └── Models/
│   ├── WhisperMateShared/                 # Shared framework (macOS + iOS)
│   ├── WhisperMateKeyboard/               # iOS keyboard extension
│   └── WhisperMateIOS/                    # iOS app
├── AIDictation.Windows/                   # Windows .NET app (не наш фокус)
└── sign-and-notarize.sh
```

## Архитектура

### Audio Pipeline
```
Hotkey press → AudioRecorder.startRecording()
    → AVAudioRecorder (m4a file) + AVAudioEngine (visualization)
    → VoiceActivityDetector (Silero VAD CoreML)
    → Provider switch:
        ├─ Cloud: OpenAIClient.transcribe() (Groq / OpenAI / Custom)
        └─ Local: ParakeetTranscriptionService.transcribe() (FluidAudio + Parakeet TDT v3)
    → TextFormattingManager (LLM tone/style — optional, cloud-only)
    → PasteHelper.copyAndPaste()
    → HistoryManager.save()
```

### Ключевые Singletons
- `HotkeyManager.shared` — глобальный хоткей
- `OverlayWindowManager.shared` — floating UI при записи
- `OnboardingManager.shared` — permission flow
- `ToneStyleManager.shared` — per-app форматирование
- `DictionaryManager.shared` — custom глоссарии
- `ParakeetTranscriptionService.shared` — локальный STT движок
- `AppState.shared` — централизованное состояние

### API Providers
**Transcription:**
- **Parakeet (Local)** — NVIDIA Parakeet TDT v3 через FluidAudio. Локально, бесплатно, без интернета. Russian ~5.5–7% WER, Ukrainian ~6.8–7.2% WER. Apple Neural Engine. **Рекомендуемый дефолт.**
- **Groq** — `whisper-large-v3-turbo` (cloud, fast, free tier)
- **OpenAI** — `whisper-1` (cloud)
- **Custom** — любой OpenAI-совместимый endpoint

**LLM (для post-processing rules):** Groq, OpenAI (gpt-4o), Anthropic (claude-3-5-sonnet), Custom

### Whisper Temperature
Cloud-провайдеры (Groq/OpenAI/Custom) используют `temperature: 0.2` (в `OpenAIClient.swift`).
- `0` вызывает repetition loop (залипание на одном токене, например "Скор. Скор. Скор.")
- `0.2` — минимальная вариативность, предотвращает loop без потери точности

### Parakeet Model
- **Источник:** HuggingFace `FluidInference/parakeet-tdt-0.6b-v3-coreml`
- **Размер:** ~1.5 GB
- **Кэш:** `~/.cache/fluidaudio/Models/`
- **Загрузка:** автоматическая при первом использовании через `AsrModels.downloadAndLoad(version: .v3)`
- **Audio:** требует 16 kHz mono PCM Float32 — конвертация через FluidAudio's `AudioConverter`

### Хранилище
- **Keychain** — API ключи (`KeychainHelper.swift`)
- **UserDefaults** — настройки (provider, hotkey, UI state)
- **JSON files** — история (`~/Library/Application Support/WhisperMate/`)
- **CoreML model cache** — `~/.cache/fluidaudio/Models/`

## Правила проекта

### Версионирование и релизы
- **НЕ бампить версию** без явного запроса (держать 0.0.x)
- **НЕ собирать DMG/tag** без явного запроса
- **Коммитить периодически** по ходу работы

### Release build требования
- Hardened runtime: YES
- **НЕ включать** entitlement `get-task-allow`
- Code signing: Developer ID Application

### Процесс релиза (когда явно запрошен)
1. Bump patch версию
2. Commit весь код
3. Notarize приложение
4. Build DMG
5. Push на GitHub только когда DMG работает и проверен
6. Убедиться что код в github и main соответствует последнему релизу

### UI/UX
- Использовать **HIG best practices**
- **НЕ создавать** кастомные компоненты без необходимости
- Стандартные macOS контролы предпочтительнее

## Swift Coding Principles

### Manager Classes (Singleton Services)

Все Manager-классы следуют этим паттернам:

1. **Documentation**: doc-комментарий описывающий назначение класса
   ```swift
   /// Manages screen capture and OCR text extraction for providing visual context to LLM
   class ScreenCaptureManager: ObservableObject {
   ```

2. **MARK Sections**: организация кода такими секциями:
   - `// MARK: - Published Properties`
   - `// MARK: - Public Callbacks` (если применимо)
   - `// MARK: - Private Properties`
   - `// MARK: - Types` (если есть вложенные типы)
   - `// MARK: - Initialization`
   - `// MARK: - Public API`
   - `// MARK: - Private Methods`

3. **Keys Enum**: приватный enum для UserDefaults ключей
   ```swift
   private enum Keys {
       static let includeScreenContext = "includeScreenContext"
   }
   ```

4. **Constants Enum**: приватный enum для magic numbers
   ```swift
   private enum Constants {
       static let maxRecordings = 100
       static let doubleTapInterval: TimeInterval = 0.3
   }
   ```

5. **Singleton Pattern**: static shared с private init
   ```swift
   static let shared = ScreenCaptureManager()
   private init() { ... }
   ```

6. **Logging**: DebugLog с context = именем класса
   ```swift
   DebugLog.info("Message", context: "ScreenCaptureManager")
   ```

7. **Naming Convention**: Service классы используют суффикс `*Manager`

### General Principles

- Использовать `@MainActor` для классов взаимодействующих с UI
- Использовать `internal import Combine` когда Combine используется только внутри
- Добавлять availability checks для новых API: `if #available(macOS 14.0, *) { ... }`
- Предпочитать прямые return вместо обёртывания в Result когда используется async/await
- Сохранять UserDefaults ключи неизменными даже при переименовании (для backward compatibility)

## Entitlements

```xml
<!-- Whispermate.entitlements -->
<key>com.apple.security.device.audio-input</key>    <!-- Микрофон -->
<key>com.apple.security.network.client</key>         <!-- API calls + model download -->
<!-- Release: НЕ включать get-task-allow -->
```

## Permissions Flow (Onboarding)

1. **Microphone** — `AVCaptureDevice.requestAccess(.audio)`
2. **Accessibility** — `AXIsProcessTrusted()` для paste automation
3. **Language** — выбор языка транскрипции
4. **Hotkey** — настройка глобального хоткея

## Secrets

API ключи загружаются в порядке: **Secrets.plist → Keychain**.

Для разработки создать `Whishpermate/Whispermate/Secrets.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GroqTranscriptionKey</key>
    <string>gsk_...</string>
    <key>GroqLLMKey</key>
    <string>gsk_...</string>
    <key>CustomTranscriptionEndpoint</key>
    <string>https://api.example.com/transcribe</string>
</dict>
</plist>
```

**Secrets.plist в .gitignore** — никогда не коммитить.

Это позволяет избежать Keychain промптов в debug-сборках.

Parakeet провайдеру **API ключ не нужен** — модель работает локально.

## Fork-specific notes

Этот форк (`Popeta/whispermate`) — независимая личная сборка, синхронизирована с `writingmate/aidictation` 2026-04-10.

**Удалено намеренно из upstream:**
- `WhisperMateShared/Services/SupabaseManager.swift` — Supabase client
- `WhisperMateShared/Services/AuthManager.swift` — auth logic
- `WhisperMateShared/Models/User.swift` — User model
- `WEB_AUTH_IMPLEMENTATION.md` — auth docs
- SPM dependency `supabase-swift`
- Все вызовы AuthManager/User в ContentView/SettingsView/WhispermateApp/OnboardingView

**Причина:** избежать зависимости от writingmate.ai сервера, оставить форк полностью локальным и независимым.

**Sparkle auto-update:** оставлен, но **может в будущем затереть наши изменения** при автообновлении. При необходимости отключить auto-check в `WhispermateApp.swift` или `UpdateManager.swift`.

**Backup до синхронизации с upstream:** ветка `backup/pre-upstream-sync-2026-04-10` и тег `backup-170677f` на GitHub fork.
