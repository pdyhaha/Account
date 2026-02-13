# pet_ledger

A new Flutter project.

## Configuration

This app expects runtime configuration via `--dart-define` (to avoid committing secrets).

```bash
flutter run --dart-define=LLM_API_KEY=...
```

Optional overrides:

```bash
flutter run \
  --dart-define=LLM_API_KEY=... \
  --dart-define=LLM_BASE_URL=https://ark.cn-beijing.volces.com/api/v3 \
  --dart-define=LLM_MODEL=...
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
