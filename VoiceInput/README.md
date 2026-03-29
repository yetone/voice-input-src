# Voice Input

A macOS menu-bar voice input tool that transcribes speech to text and injects it into the focused input field.

## Features

- **Fn Key Hotkey**: Hold Fn key to record, release to transcribe and inject
- **Multi-language Support**: Simplified Chinese (default), Traditional Chinese, English, Japanese, Korean
- **LLM Refinement**: Optional LLM-powered correction of transcription errors
- **Elegant Overlay**: Beautiful capsule-shaped floating window with real-time audio waveform
- **Smart Input Method Handling**: Automatically switches input source for CJK compatibility

## Requirements

- macOS 13.0 or later
- Xcode with Swift toolchain
- Speech Recognition permission
- Microphone access

## Building

```bash
cd VoiceInput
make build
```

## Running

```bash
make run
```

## Installing

```bash
make install
```

## Configuration

Click the microphone icon in the menu bar to access:
- Language selection
- LLM Refinement toggle
- Settings (API Base URL, API Key, Model)

## LLM Integration

The app can use any OpenAI-compatible API to refine transcriptions. Configure in Settings:
- API Base URL (optional, defaults to OpenAI)
- API Key (required for LLM refinement)
- Model name (defaults to gpt-4o-mini)

The LLM uses a conservative system prompt that only fixes obvious errors without rewriting content.

## License

MIT
