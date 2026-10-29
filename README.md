# MoonTrace

> Agent execution trace observability and debugging toolkit for MoonBit.

MoonTrace is a **MoonBit-native** observability tool for AI agent workflows, inspired by LangSmith. It provides lightweight tracing, storage, terminal visualization, and HTML export. The core works locally; an optional example connects a real Alibaba Cloud Model Studio Agent.

For a short, API-key-free review flow, see [Reviewer Demo](docs/REVIEWER_DEMO.md).
Mooncakes publication and independent installation evidence are recorded in [Release Verification](docs/MOONCAKES_RELEASE.md).

[![MoonTrace CI](https://github.com/guo-dong-123/moon-trace/actions/workflows/ci.yml/badge.svg)](https://github.com/guo-dong-123/moon-trace/actions/workflows/ci.yml)

Requires **moonc >= 0.10.14**. The reproducible toolchain is pinned in [.moonbit-version](.moonbit-version), and CI rejects older compilers. See the [acceptance checklist](docs/ACCEPTANCE.md) for the nine delivery requirements.

## Why MoonTrace?

When building AI agents, understanding *what happened* during an execution is as important as the final output. MoonTrace gives you:

- **Explicit instrumentation** — wrap a function with `@trace.span` to capture timing, input/output, and errors without changing its signature
- **Nested span trees** — visualize agent reasoning chains, tool calls, and sub-agent invocations
- **Persistent storage** — traces saved as JSON files, queryable by name, status, and time range
- **Terminal UI** — inspect traces directly in your terminal with ANSI-colored tree views
- **HTML export** — generate self-contained interactive trace visualizations with timelines
- **Agent replay** — feed recorded tool outputs and failures back into an Agent without calling the tool again
- **CLI** — inspect, compare, replay, and export saved traces

## Quick Start

### Install from Mooncakes

Add MoonTrace to an existing MoonBit project:

```bash
moon add guo-dong-123/moon-trace@0.1.3
```

The published module is [guo-dong-123/moon-trace](https://mooncakes.io/docs/guo-dong-123/moon-trace). Import the packages shown below in your own `moon.pkg`, then run your application with `--target native`. The complete workflow is verified on the native backend.

### 1. Build this checkout

Clone this repository, update dependencies, and verify the native build:

```bash
git clone https://github.com/guo-dong-123/moon-trace.git
cd moon-trace
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash -s -- "$(cat .moonbit-version)"
export PATH="$HOME/.moon/bin:$PATH"
python3 scripts/check_toolchain.py
moon update
moon check --target native --deny-warn
moon build --target native --deny-warn
moon test --target native --deny-warn
```

The same package imports work in this checkout and in projects that install the Mooncakes module:

```moonbit
// moon.pkg
import {
  "guo-dong-123/moon-trace/src/trace" @trace,
  "guo-dong-123/moon-trace/src/storage" @storage,
  "guo-dong-123/moon-trace/src/replay" @replay,
}
```

### 2. Instrument your agent

This snippet illustrates the API; `search_web` represents your own tool implementation.

```moonbit
fn run_agent(query : String) -> String {
  ignore(@trace.start_trace())

  let result = @trace.span("agent.run", Some(query), () => {
    // Nested spans automatically form a tree
    let plan = @trace.span("agent.plan", Some(query), () => {
      "search -> calculate -> answer"
    })

    let search_result = @trace.span("tool.web_search", Some(query), () => {
      search_web(query)
    })

    @trace.span("agent.synthesize", None, () => {
      "Final answer based on " + search_result
    })
  })

  // Save trace
  match @trace.end_trace() {
    None => ()
    Some(trace) => {
      let store = @storage.JsonFileStore::default()
      ignore(store.save(trace))
    }
  }

  result
}
```

### 3. Run and inspect an offline agent

Trace IDs use 128 bits of OS randomness and remain independent across process restarts. An isolated directory still keeps demos separate from your own data. After recording, `ids` prints the current IDs for scripts:

```bash
export MOONTRACE_DIR="$(mktemp -d /tmp/moontrace-demo.XXXXXX)"
moon run examples/research_agent
TRACE_ID=$(moon run src/cli ids --errors | head -n 1)

# List and inspect saved traces
moon run src/cli list
moon run src/cli show "$TRACE_ID"

# List only failed traces or filter by root span name
moon run src/cli errors
moon run src/cli list --errors
moon run src/cli list --name research_agent

# Compare two saved traces by span name
moon run src/cli compare <baseline_id> <candidate_id>

# Display recorded outputs without calling external tools
moon run src/cli replay "$TRACE_ID"

# Record and rerun an Agent using captured tool responses in a separate directory
MOONTRACE_DIR="$(mktemp -d /tmp/moontrace-replay.XXXXXX)" moon run examples/replay_agent

# Check a new execution against a known-good baseline
moon run src/cli regress <baseline_id> <candidate_id>
moon run src/cli regress <baseline_id> <candidate_id> --check-output

# Export to interactive HTML
moon run src/cli export "$TRACE_ID" "$MOONTRACE_DIR/trace.html"

# Export all traces + index page
moon run src/cli export-all "$MOONTRACE_DIR/exports/"
```

`replay` in the CLI displays recorded span values. `examples/replay_agent` exercises `ReplaySession.run` inside a second Agent execution and checks that no live tool calls occur during that execution. By default, regression checks compare span names, counts, and statuses; `--check-output` also compares the matching root Agent's final output. The check reports a change without printing the output text.

## Architecture

```
src/
├── trace/          # Core data model + instrumentation SDK
│   ├── span.mbt    # Span, SpanEvent, SpanStatus, Trace data structures
│   ├── tracer.mbt  # Global Tracer, start_trace, span, add_event, set_metadata
│   ├── session.mbt # Isolated sessions and explicit concurrent contexts
│   └── context.mbt # Legacy single-flow scope snapshots
├── storage/        # Persistence layer
│   ├── store.mbt   # MemoryStore, TraceSummary, TraceFilter, query
│   └── json_file.mbt # Immutable JSON snapshots + rebuildable index cache
├── tui/            # Terminal UI viewer
│   └── viewer.mbt  # ANSI-colored tree rendering, list/detail views
├── exporter/       # Export tools
│   └── html.mbt    # Self-contained HTML export with timeline
├── replay/         # Recorded tool outputs and regression checks
└── cli/            # Command-line interface
    └── main.mbt    # trace browsing, replay, regression, and export

examples/
├── demo_agent/       # Minimal instrumentation demo
├── storage_test/     # Storage layer test
├── tui_test/         # TUI viewer test
├── research_agent/   # Offline multi-step research agent
├── failure_diagnosis/ # Failed tool plus recovery path demo
├── replay_agent/    # Offline Agent replay with repeated tool calls
├── concurrent_agent/ # Independent requests and parallel sibling tools
└── bailian_agent/    # Real Qwen tool-calling agent with async traces
```

## Core API

### Tracing

| Function | Description |
|----------|-------------|
| `@trace.start_trace()` | Start a new trace, returns trace ID |
| `@trace.end_trace()` | End current trace, returns `Option[Trace]` |
| `@trace.span(name, input, body)` | Execute body as a span, captures input/output/duration/errors |
| `@trace.span_async(name, input, body)` | Trace an async LLM or network-backed operation |
| `@trace.add_event(name, data)` | Add a custom event to the current span |
| `@trace.set_metadata(key, value)` | Attach metadata to the current span |
| `@trace.print_trace()` | Print current trace tree to stdout |
| `TraceSession::new()` / `session.context()` | Create an isolated recording session and root context |
| `span_in(ctx, name, input, body)` / `span_async_in(...)` | Record with explicit child context, including concurrent tasks |
| `session.finish()` | Complete a session after tasks join; rejects active spans |
| `trace.duration_ms()` | Elapsed duration, without double counting nested work |
| `trace.cumulative_span_duration_ms()` | Sum of all recorded span durations |

### Storage

| Function | Description |
|----------|-------------|
| `MemoryStore::new()` | In-memory storage |
| `JsonFileStore::default()` | File storage at `~/.moontrace/traces/` |
| `JsonFileStore::new(dir)` | File storage at custom directory |
| `store.save(trace)` | Atomically save a snapshot; refuse conflicting overwrite |
| `store.load(id)` | Load a trace by ID |
| `store.list()` | Scan valid snapshots; does not depend on index.json |
| `store.delete(id)` | Delete a trace |
| `store.repair()` | Rebuild index cache and report unreadable records |
| `store.last_error()` | Diagnostic for the last storage operation |
| `query_summaries(summaries, filter)` | Filter traces by name/status/time |

### Replay

Wrap a tool call with `@trace.span` as usual, then supply its recorded output during a later run:

```moonbit
let session = @replay.ReplaySession::from_trace(saved_trace)
let result = @trace.span("tool.lookup", Some(query), () => {
  session.run("tool.lookup", Some(query))
})
```

`run` consumes one matching call at a time. It checks the recorded input, returns the captured output, or raises the captured error. It never invokes the tool itself. See `examples/replay_agent` for a complete offline Agent run.

### Concurrent Agents

The global `start_trace` / `span` / `span_async` API is retained for a **single execution flow**. It is not task-local storage. For overlapping requests or sibling tasks, create one session per request and pass the callback context to children:

```moonbit
let session = @trace.TraceSession::new()
let answer = @trace.span_async_in(session.context(), "agent.run", None, root => {
  let results = @async.all([
    () => @trace.span_async_in(root, "tool.lookup", None, ctx => {
      ctx.set_metadata("source", "local")
      "lookup result"
    }),
    () => @trace.span_async_in(root, "tool.calculate", None, _ => "42"),
  ])
  results.join(" | ")
})
let recorded = session.finish()
```

Call `finish()` after joining all tasks. Raised errors and cancellation finalize the affected spans and propagate to the caller. Explicit contexts never read or change the legacy global stack. The complete executable example is `moon run examples/concurrent_agent --target native`.

### Storage and 0.1.2 migration

- Trace IDs are `trace_<32 hex digits>`; existing IDs such as `trace_8` remain readable. Use `ids` or the IDs printed by an example instead of hardcoding counters.
- Timestamp and duration fields now use `Int64` in MoonBit. Normal epoch milliseconds remain JSON numbers, and existing numeric JSON records load without conversion. A legacy negative/truncated timestamp cannot be reconstructed automatically.
- Saves commit a complete temporary file atomically. An identical retry succeeds; different data with the same ID is rejected. Finish a recording before saving it; updating an existing snapshot requires a new trace ID.
- `list()` scans snapshot files. A missing, stale or malformed `index.json` cannot hide records. `moon run src/cli repair` rebuilds the cache and reports corrupt trace files without deleting them. Temporary files from interrupted writes are ignored.
- File storage requires native/LLVM and a filesystem supporting atomic same-directory commits. This release is locally verified on macOS native; Linux native is covered by the CI configuration. Windows support is implemented but has not been verified locally. There is no power-loss durability guarantee for directory entries.

## Example Output

### Terminal View

```
=== Trace trace_8 ===

Spans: 6  Errors: 1  Elapsed: 15ms  Cumulative span time: 23ms

└── [ok] research_agent.run (15ms)
    input: {"query": "unavailable topic..."}
    ├── [ok] agent.plan (3ms)
    ├── [ok] tool.web_search (1ms)
    ├── [ok] tool.calculator (1ms)
    └── [error] tool.knowledge_base (1ms) error=Knowledge base timeout after 5000ms
        └── [ok] agent.synthesize (2ms)
```

### HTML Export

Each exported HTML file includes:
- Summary stats (span count, errors, elapsed duration and cumulative span time)
- Search metadata/events and combine with a status filter; matched spans synchronize with the timeline
- Matching ancestors stay visible as context; clearing filters restores prior collapse state
- Interactive collapsible span tree
- Horizontal timeline showing span start times and durations
- Color-coded status badges (green=ok, red=error, yellow=running)

## Development

```bash
# Update dependencies and build
moon update
moon build

# Run example agent
moon run examples/research_agent

# Run the real Bailian tool-calling Agent
BAILIAN_API_KEY='your-key' TEXT_MODEL='qwen3.7-plus' \
  MOONTRACE_DIR=/tmp/moontrace-bailian \
  moon run --target native examples/bailian_agent

# Run CLI from this checkout
moon run src/cli list
moon run src/cli show <trace_id>
moon run src/cli export <trace_id> output.html

# Run executable demonstrations
moon run examples/storage_test
moon run examples/tui_test

# Run package tests
moon test
```

## Real Bailian Agent

`examples/bailian_agent` runs a real two-turn Agent workflow:

1. Qwen selects the `inspect_moontrace_mvp` tool.
2. MoonBit executes the local tool and records its evidence.
3. Qwen synthesizes a Chinese MVP review from the tool result.
4. MoonTrace persists the root Agent span, both LLM spans, and the tool span.

Configuration is read only from environment variables:

| Variable | Required | Default |
|----------|----------|---------|
| `BAILIAN_API_KEY` | Yes | None |
| `TEXT_MODEL` | No | `qwen3.7-plus` |
| `BAILIAN_BASE_URL` | No | `https://dashscope.aliyuncs.com/compatible-mode/v1` |
| `MOONTRACE_DIR` | No | `~/.moontrace/traces/` |

The API key is sent to `curl` through stdin configuration and is never placed in `curl` arguments or stored in source, traces, or HTML exports. This example also records placeholders instead of the user query, tool arguments, and final answer, and does not persist provider error bodies. Generic `@trace.span` calls still record the strings supplied by the caller and the returned value; avoid passing secrets to spans or exporting traces containing private data. Copy `.env.example` for the variable names, but do not commit a populated `.env` file.

## MVP Verification

The following commands verify the local workflow without an API key or external service. Use a fresh trace directory for each run:

```bash
# Build and run all tests
moon build --target native
moon test --target native

# Run the Agent demo: nested tools, events, and handled tool failure
moon run examples/demo_agent

# Run the full Research Agent and persist traces in an isolated directory
export MOONTRACE_DIR="$(mktemp -d /tmp/moontrace-mvp.XXXXXX)"
moon run examples/research_agent
TRACE_ID=$(moon run src/cli ids --errors | head -n 1)
moon run src/cli list
moon run src/cli show "$TRACE_ID"
moon run src/cli export "$TRACE_ID" "$MOONTRACE_DIR/trace.html"

# Run the failure diagnosis demo
FAILURE_DIR="$(mktemp -d /tmp/moontrace-failure.XXXXXX)"
MOONTRACE_DIR="$FAILURE_DIR" moon run examples/failure_diagnosis
MOONTRACE_DIR="$FAILURE_DIR" moon run src/cli errors
```

Expected acceptance evidence:

- `moon test --target native` reports 45 passed tests on the verified checkout.
- The Agent demo prints a nested trace containing `agent_think`, `tool.web_search`, `tool.calculator`, and `tool.knowledge_base`.
- The Research Agent saves three traces, including one error trace caused by a simulated knowledge-base timeout.
- The CLI lists and displays saved traces, and exports a self-contained HTML file.
- `docs/evidence/` contains reproducible JSON and HTML output for both successful and failed-tool runs.

## Requirements

- `moonc >= 0.10.14`; verified with `moonc 0.10.14+7d59c7ec9` and `moon 0.1.20260920`. The exact installer version is recorded in `.moonbit-version`.
- `moonbitlang/x@0.5.4` (filesystem access)
- `moonbitlang/async@0.20.1` and system `curl` (real Bailian Agent example only)

The tracing and examples are primarily implemented in MoonBit. Atomic filesystem commits use one small native C helper. Python scripts are development/CI checks; they are not required by applications importing the SDK.

Development integration checks (Python is only needed for these scripts):

```bash
moon build --target native
python3 scripts/verify_native.py
# Optional Chromium checks using the agent-browser CLI:
python3 scripts/verify_html.py
```

See [0.1.2 validation](docs/VALIDATION_0.1.2.md) for tested scenarios and limits.

The compiler requirement, warning-free migration and current submission checks are recorded in [0.1.3 validation](docs/VALIDATION_0.1.3.md).

## License

MIT

Dependency licenses and conceptual references are documented in [third-party notices](THIRD_PARTY.md).
