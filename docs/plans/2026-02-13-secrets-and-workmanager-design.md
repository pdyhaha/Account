# Secrets Removal + Workmanager Observability Design

> Date: 2026-02-13

## Goal

- Remove hardcoded LLM credentials from the repo.
- Make the Workmanager periodic task registration `await`-able and failure-observable without blocking app startup.

## Non-Goals

- No history rewrite (no `git filter-repo` etc.). Keys must be rotated/invalidated out-of-band.
- No UI/feature changes beyond config plumbing and safer startup behavior.

## Current State (Key Findings)

- `/Users/jayce_pu/workspace/Account/lib/core/config/app_config.dart` currently hardcodes `llmApiKey`, `llmBaseUrl`, `llmModel`.
- `/Users/jayce_pu/workspace/Account/lib/main.dart` schedules a periodic Workmanager task via `_scheduleDailyReport()`, but does not `await` registration (and the function is not `async`).

## Approach A (Recommended): `--dart-define` for LLM config

### Why

- Minimal code changes, no new dependencies.
- Works consistently across local dev and CI/build pipelines.

### Design

- Replace hardcoded values in `/Users/jayce_pu/workspace/Account/lib/core/config/app_config.dart` with compile-time environment reads:
  - `LLM_API_KEY` (default `''`)
  - `LLM_BASE_URL` (default keeps current base URL)
  - `LLM_MODEL` (default keeps current model id)
- Keep `LLMService.chat(...)` behavior: if key is empty, return a clear message or `null` depending on call site expectations.

### Developer Experience

Document how to run/build:

```bash
flutter run \
  --dart-define=LLM_API_KEY=... \
  --dart-define=LLM_BASE_URL=https://... \
  --dart-define=LLM_MODEL=...
```

## Approach B: `.env` + `flutter_dotenv`

Not chosen for this change (adds dependency + init path). Consider later if local dev ergonomics becomes a problem.

## Approach C: Native build config injection

Not chosen for now (higher maintenance across Android/iOS/Desktop).

## Workmanager Registration Observability

### Design

- Change `_scheduleDailyReport()` in `/Users/jayce_pu/workspace/Account/lib/main.dart`:
  - signature: `Future<void> _scheduleDailyReport() async`
  - `await Workmanager().registerPeriodicTask(...)`
  - wrap in `try/catch` and log failures (`debugPrint`) without preventing `runApp(...)`.
- Ensure the periodic task unique name and identifier remain unchanged.

## Success Criteria

- No secrets committed in source control for LLM config.
- App startup does not silently swallow Workmanager registration errors.
- After applying `--dart-define`, LLM features still function.

## Verification

On a machine with Flutter installed:

- `flutter analyze`
- `flutter test`

