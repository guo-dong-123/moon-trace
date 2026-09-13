# MoonTrace

> Agent execution trace observability and debugging toolkit for MoonBit.

MoonTrace is a **MoonBit-native** observability tool for AI agent workflows, inspired by LangSmith. It provides lightweight tracing, storage, terminal visualization, and HTML export — all written in pure MoonBit with zero runtime dependencies beyond `moonbitlang/x`.

## Why MoonTrace?

When building AI agents, understanding *what happened* during an execution is as important as the final output. MoonTrace gives you:

- **Zero-config instrumentation** — wrap any function with `@trace.span` and get automatic timing, input/output capture, and error tracking
- **Nested span trees** — visualize agent reasoning chains, tool calls, and sub-agent invocations
- **Persistent storage** — traces saved as JSON files, queryable by name, status, and time range
- **Terminal UI** — inspect traces directly in your terminal with ANSI-colored tree views
- **HTML export** — generate self-contained interactive trace visualizations with timelines
- **CLI** — `moontrace list`, `moontrace show`, `moontrace export`

## Quick Start

### 1. Add MoonTrace to your project

Clone this repository and update the MoonBit registry before building:

```bash
git clone https://github.com/guo-dong-123/moon-trace.git
cd moon-trace
moon update
```

```moonbit
// moon.pkg
import {
  "yuanqi/moon-trace/src/trace" @trace,
  "yuanqi/moon-trace/src/storage" @storage,
}
```

### 2. Instrument your agent

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

### 3. View traces

```bash
# List all traces
moontrace list

# Show detailed trace in terminal
moontrace show <trace_id>

# Export to interactive HTML
moontrace export <trace_id> trace.html

# Export all traces + index page
moontrace export-all ./exports/
```

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
└── cli/            # Command-line interface
    └── main.mbt    # moontrace list/show/export/export-all/delete

examples/
├── demo_agent/       # Minimal instrumentation demo
├── storage_test/     # Storage layer test
├── tui_test/         # TUI viewer test
└── research_agent/   # Full example: multi-step research agent
```

## Core API

### Tracing

| Function | Description |
|----------|-------------|
| `@trace.start_trace()` | Start a new trace, returns trace ID |
| `@trace.end_trace()` | End current trace, returns `Option[Trace]` |
| `@trace.span(name, input, body)` | Execute body as a span, captures input/output/duration/errors |
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

# Run CLI from this checkout
moon run src/cli list
moon run src/cli show <trace_id>
moon run src/cli export <trace_id> output.html

# Run executable demonstrations
moon run examples/storage_test
moon run examples/tui_test

# Run package tests (15 tests)
moon test
```

## Requirements

- MoonBit toolchain (`moon` >= 0.1.20260904, `moonc` >= 0.10.12)
- `moonbitlang/x@0.5.4` (for filesystem access)

## License

MIT
