# MoonTrace

> Agent execution trace observability and debugging toolkit for MoonBit.

MoonTrace is a **MoonBit-native** observability tool for AI agent workflows, inspired by LangSmith. It provides lightweight tracing, storage, terminal visualization, and HTML export. The core works locally; an optional example connects a real Alibaba Cloud Model Studio Agent.

For a short, API-key-free review flow, see [Reviewer Demo](docs/REVIEWER_DEMO.md).

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

### 1. Build this checkout

Clone this repository, update dependencies, and verify the native build:

```bash
git clone https://github.com/guo-dong-123/moon-trace.git
cd moon-trace
moon update
moon check --target native
moon build --target native
moon test --target native
```

The library is currently used from this checkout; a Mooncakes release and a documented third-party installation flow are not available yet. The package imports below are the ones used by the examples in this repository.

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

Use a fresh directory for each demonstration. Example trace IDs restart at `trace_1`, so reusing a directory across different examples can overwrite earlier traces.

```bash
export MOONTRACE_DIR="$(mktemp -d /tmp/moontrace-demo.XXXXXX)"
moon run examples/research_agent

# List and inspect saved traces
moon run src/cli list
moon run src/cli show trace_8

# List only failed traces or filter by root span name
moon run src/cli errors
moon run src/cli list --errors
moon run src/cli list --name research_agent

# Compare two saved traces by span name
moon run src/cli compare trace_1 trace_8

# Display recorded outputs without calling external tools
moon run src/cli replay trace_8

# Record and rerun an Agent using captured tool responses in a separate directory
MOONTRACE_DIR="$(mktemp -d /tmp/moontrace-replay.XXXXXX)" moon run examples/replay_agent

# Check a new execution against a known-good baseline
moon run src/cli regress trace_1 trace_15
moon run src/cli regress trace_1 trace_15 --check-output

# Export to interactive HTML
moon run src/cli export trace_8 "$MOONTRACE_DIR/trace_8.html"

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
│   └── context.mbt # Async context propagation (capture_context / with_context)
├── storage/        # Persistence layer
│   ├── store.mbt   # MemoryStore, TraceSummary, TraceFilter, query
│   └── json_file.mbt # JsonFileStore (JSON files + index.json)
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

### Storage

| Function | Description |
|----------|-------------|
| `MemoryStore::new()` | In-memory storage |
| `JsonFileStore::default()` | File storage at `~/.moontrace/traces/` |
| `JsonFileStore::new(dir)` | File storage at custom directory |
| `store.save(trace)` | Save a trace |
| `store.load(id)` | Load a trace by ID |
| `store.list()` | List all trace summaries |
| `store.delete(id)` | Delete a trace |
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

### Async Context

```moonbit
let ctx = @trace.capture_context()
// Inside async callback:
@trace.with_context(ctx, () => {
  @trace.span("async_task", None, () => { ... })
})
```

## Example Output

### Terminal View

```
=== Trace trace_8 ===

Spans: 6  Errors: 1  Total duration: 23ms

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
- Summary stats (span count, error count, total duration)
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
moon run src/cli list
moon run src/cli show trace_8
moon run src/cli export trace_8 "$MOONTRACE_DIR/trace_8.html"

# Run the failure diagnosis demo
FAILURE_DIR="$(mktemp -d /tmp/moontrace-failure.XXXXXX)"
MOONTRACE_DIR="$FAILURE_DIR" moon run examples/failure_diagnosis
MOONTRACE_DIR="$FAILURE_DIR" moon run src/cli errors
```

Expected acceptance evidence:

- `moon test --target native` reports 33 passed tests on the verified checkout.
- The Agent demo prints a nested trace containing `agent_think`, `tool.web_search`, `tool.calculator`, and `tool.knowledge_base`.
- The Research Agent saves three traces, including one error trace caused by a simulated knowledge-base timeout.
- The CLI lists and displays saved traces, and exports a self-contained HTML file.
- `docs/evidence/` contains reproducible JSON and HTML output for both successful and failed-tool runs.

## Requirements

- MoonBit toolchain (locally verified with `moon` 0.1.20260827 and `moonc` 0.10.11; no minimum version is established)
- `moonbitlang/x@0.5.4` (filesystem access)
- `moonbitlang/async@0.20.1` and system `curl` (real Bailian Agent example only)

## License

MIT
