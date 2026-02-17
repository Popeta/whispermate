# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Обзор проекта

**WhisperMate** — macOS приложение для голосовой транскрипции с глобальным hotkey, автопастой и AI-форматированием текста.

- **Платформы:** macOS 13+ (основное), iOS 15+ (в разработке)
- **Стек:** Swift 5.9, SwiftUI, AVFoundation, CoreML
- **Версия:** 0.0.20 (держать в 0.0.x без явного запроса)

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
├── Whishpermate/                    # Xcode project root
│   ├── Whispermate.xcodeproj
│   ├── Whispermate/                 # macOS app (основное)
│   │   ├── WhispermateApp.swift     # Entry point
│   │   ├── Views/                   # SwiftUI views
│   │   │   ├── ContentView.swift    # Главное окно (952 LOC)
│   │   │   ├── SettingsView.swift   # Настройки (539 LOC)
│   │   │   └── OnboardingView.swift # Пермиссии wizard
│   │   ├── Services/                # Business logic (22 сервиса)
│   │   │   ├── AudioRecorder.swift  # AVAudioRecorder + AVAudioEngine
│   │   │   ├── OpenAIClient.swift   # Unified API client
│   │   │   ├── HotkeyManager.swift  # Global hotkey (event tap)
│   │   │   └── ...
│   │   └── Models/
│   ├── WhisperMateShared/           # Shared framework (macOS + iOS)
│   ├── WhisperMateKeyboard/         # iOS keyboard extension
│   └── WhisperMateIOS/              # iOS app
└── sign-and-notarize.sh
```

## Архитектура

### Audio Pipeline
```
Hotkey press → AudioRecorder.startRecording()
    → AVAudioRecorder (m4a file) + AVAudioEngine (visualization)
    → VoiceActivityDetector (Silero VAD CoreML)
    → OpenAIClient.transcribe() (Groq/OpenAI/Custom)
    → TextFormattingManager (LLM tone/style)
    → PasteHelper.copyAndPaste()
    → HistoryManager.save()
```

### Ключевые Singletons
- `HotkeyManager.shared` — глобальный хоткей
- `OverlayWindowManager.shared` — floating UI при записи
- `OnboardingManager.shared` — permission flow
- `ToneStyleManager.shared` — per-app форматирование
- `DictionaryManager.shared` — custom глоссарии

### API Providers
**Transcription:** Groq (whisper-large-v3-turbo), OpenAI (whisper-1), Custom endpoint
**LLM:** Groq, OpenAI (gpt-4o), Anthropic (claude-3-5-sonnet), Custom

### Whisper Temperature
Transcription API использует `temperature: 0.2` (в `OpenAIClient.swift`).
- `0` вызывает repetition loop (залипание на одном токене, например "Скор. Скор. Скор.")
- `0.2` — минимальная вариативность, предотвращает loop без потери точности

### Хранилище
- **Keychain** — API ключи (`KeychainHelper.swift`)
- **UserDefaults** — настройки (provider, hotkey, UI state)
- **JSON files** — история (`~/Library/Application Support/WhisperMate/`)

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
5. Push на GitHub только когда DMG работает

### UI/UX
- Использовать **HIG best practices**
- **НЕ создавать** кастомные компоненты без необходимости
- Стандартные macOS контролы предпочтительнее

## Entitlements

```xml
<!-- Whispermate.entitlements -->
<key>com.apple.security.device.audio-input</key>    <!-- Микрофон -->
<key>com.apple.security.network.client</key>         <!-- API calls -->
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
