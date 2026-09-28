# Chat Niu

A lightweight Flutter chat client with a ChatGPT-style interface, streaming OpenAI-compatible responses, and hands-free speech dictation.

## Features

- OpenAI-compatible streaming chat completions
- Configurable API URL, API key, and model
- Live voice transcription, dictation punctuation, and automatic listening-session restart after pauses
- Markdown responses, multi-turn context, and a responsive chat composer
- API credentials stored locally with `shared_preferences`

## Getting started

1. Install Flutter 3.35 or newer and run `flutter pub get`.
2. Generate the native platform wrappers from the project root:

   ```sh
   flutter create --platforms=android,ios --org com.chatniu --project-name chat_niu .
   bash tool/bootstrap_platforms.sh
   ```

3. Run `flutter run` on an Android or iOS device.
4. Open **Settings** in the app and enter an OpenAI-compatible base URL, API key, and model.

For OpenAI, the default base URL is `https://api.openai.com/v1` and the default model is `gpt-4o-mini`. The app sends requests to `/chat/completions` with server-sent event streaming enabled.

## Voice input

Tap the microphone to start dictation. Recognized words appear in the composer as you speak. Brief pauses or platform-imposed speech-session timeouts are handled by restarting recognition while voice input remains enabled. Tap the microphone again to stop; review or edit the transcript, then send it.

Speech recognition depends on the operating system's speech service and may send audio to that service provider. The app requests microphone and speech recognition permissions. Availability and supported languages depend on the device settings.

## CI

GitHub Actions generates the Android/iOS platform wrappers on the hosted runner, installs Flutter there, runs formatting, static analysis and unit tests, then builds a debug Android APK. No local Flutter/Android build toolchain is needed to work on the Dart sources.

## Security note

The API key is stored on the device using `shared_preferences` for this minimal starter. It is not encrypted; avoid using this approach for high-risk production secrets or shared devices. Do not commit API keys to this repository.
