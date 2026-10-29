# Changelog

## 0.1.3 — 2026-10-29

- Require moonc >= 0.10.14 and pin the official 0.10.14+7d59c7ec9 toolchain for reproducible CI installs.
- Add a compiler version gate and tests covering version ordering and prerelease rejection.
- Qualify package symbols in blackbox tests and explicitly expose trait methods for the new compiler. Remove deprecated collection formatting from the research Agent example.
- Run check, instrumented tests and native build with compiler warnings treated as errors; print coverage summaries in GitHub Actions.
- Update the submission materials, runnable quick start, dependency notices and requirement checklist to match the current release.

## 0.1.2 — 2026-10-29

- Generate trace IDs from 128-bit OS randomness, independently of process counters.
- Add isolated `TraceSession` / `TraceContext` and `span_in` / `span_async_in` APIs for overlapping requests and parallel tools; finalize failed and cancelled spans.
- Save immutable snapshots with exclusive atomic commits, recursive directory creation and explicit diagnostics. Identical retries succeed; conflicting IDs cannot overwrite existing data.
- Scan snapshots as the source of truth. Add `repair` to rebuild the index cache and report corrupt records, and `ids` for scripts.
- Use `Int64` millisecond timestamps/durations while retaining numeric JSON compatibility. Separate elapsed trace time from cumulative span time.
- Correct HTML metadata iteration and escape every special character, including repeated quotes. Match search and status within the same span, retain ancestor context, link filtering to the timeline and restore collapse state when filters clear.
- Add concurrent Agent demonstration, multi-process persistence checks and reproducible Chromium acceptance checks. Update CI and examples to use generated IDs.

### Migration

Use explicit sessions for concurrency; the legacy global tracer remains single-flow. Timestamp/duration fields and time filter bounds now have type `Int64`. Existing numeric JSON traces still load; previously truncated negative timestamps remain unchanged. Saved snapshots are immutable, so create a new trace ID for a changed execution. File storage requires native/LLVM.

## 0.1.1

- Display metadata/events and add HTML search/status controls.
- Preserve span details when completing a recording.

## 0.1.0

- Initial tracing, JSON persistence, terminal/HTML views, offline replay and regression checks.
