# Secrets Removal + Workmanager Observability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove hardcoded LLM secrets from source code (use `--dart-define`), and make Workmanager task registration `await`-able and failure-observable without blocking app startup.

**Architecture:** Replace `AppConfig` constants with `String.fromEnvironment(...)` reads, and convert `_scheduleDailyReport()` to `async` with `await` + `try/catch` logging in `main()`.

**Tech Stack:** Flutter, Dart, Riverpod, Workmanager.

---

### Task 1: Remove Hardcoded LLM Secrets From `AppConfig`

**Files:**
- Modify: `/Users/jayce_pu/workspace/Account/lib/core/config/app_config.dart`

**Step 1: Make a failing check (grep) to confirm the secret is still present**

Run:
```bash
cd /Users/jayce_pu/workspace/Account
rg -n \"llmApiKey\\s*=\\s*'\" lib/core/config/app_config.dart
```
Expected: shows the current hardcoded assignment line.

**Step 2: Implement minimal config change**

Edit `/Users/jayce_pu/workspace/Account/lib/core/config/app_config.dart` to:
- Use `const String.fromEnvironment('LLM_API_KEY', defaultValue: '')`
- Use `const String.fromEnvironment('LLM_BASE_URL', defaultValue: '<current default>')`
- Use `const String.fromEnvironment('LLM_MODEL', defaultValue: '<current default>')`

Example shape:
```dart
static const String llmApiKey =
    String.fromEnvironment('LLM_API_KEY', defaultValue: '');
```

**Step 3: Re-run grep to confirm secrets are gone from source**

Run:
```bash
cd /Users/jayce_pu/workspace/Account
rg -n \"d863d891|ep-2026|ark\\.cn-beijing\\.volces\\.com\" lib || true
```
Expected: no matches for removed hardcoded values.

**Step 4: Commit**

Run:
```bash
cd /Users/jayce_pu/workspace/Account
git add /Users/jayce_pu/workspace/Account/lib/core/config/app_config.dart
git commit -m \"chore: load LLM config via dart-define\"
```

### Task 2: Document `--dart-define` Usage

**Files:**
- Modify: `/Users/jayce_pu/workspace/Account/README.md`

**Step 1: Add a short “Configuration” section**

Add commands (keep minimal):
```bash
flutter run --dart-define=LLM_API_KEY=...
```
Also document optional `LLM_BASE_URL` and `LLM_MODEL`.

**Step 2: Commit**

Run:
```bash
cd /Users/jayce_pu/workspace/Account
git add /Users/jayce_pu/workspace/Account/README.md
git commit -m \"docs: document dart-define configuration\"
```

### Task 3: Make Workmanager Daily Report Scheduling Awaitable + Observable

**Files:**
- Modify: `/Users/jayce_pu/workspace/Account/lib/main.dart`

**Step 1: Change `_scheduleDailyReport` to return `Future<void>` and await registration**

Update:
- `void _scheduleDailyReport()` -> `Future<void> _scheduleDailyReport() async`
- Add `await` before `registerPeriodicTask(...)`.

**Step 2: Call it from `main()` with `await` and `try/catch`**

Update `main()`:
- `try { await _scheduleDailyReport(); } catch (e, st) { debugPrint(...); }`
- Ensure `runApp(...)` still always runs.

**Step 3: Commit**

Run:
```bash
cd /Users/jayce_pu/workspace/Account
git add /Users/jayce_pu/workspace/Account/lib/main.dart
git commit -m \"chore: await workmanager task registration\"
```

### Task 4: Verification (Requires Flutter Installed)

**Files:**
- None

**Step 1: Analyze**

Run:
```bash
cd /Users/jayce_pu/workspace/Account
flutter analyze
```
Expected: no analyzer errors (warnings/lints as configured).

**Step 2: Test**

Run:
```bash
cd /Users/jayce_pu/workspace/Account
flutter test
```
Expected: tests pass.

---

## Execution Choice

Plan complete and saved to `/Users/jayce_pu/workspace/Account/docs/plans/2026-02-13-secrets-and-workmanager.md`. Two execution options:

1. Subagent-Driven (this session) - fresh subagent per task, review between tasks
2. Parallel Session (separate) - open a new session with executing-plans and run task-by-task

