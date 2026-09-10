// TUI viewer: render traces with ANSI colors and tree layout

// ANSI color helpers
fn color_red(s : String) -> String { "\u{001b}[31m" + s + "\u{001b}[0m" }
fn color_green(s : String) -> String { "\u{001b}[32m" + s + "\u{001b}[0m" }
fn color_yellow(s : String) -> String { "\u{001b}[33m" + s + "\u{001b}[0m" }
fn color_cyan(s : String) -> String { "\u{001b}[36m" + s + "\u{001b}[0m" }
fn color_gray(s : String) -> String { "\u{001b}[90m" + s + "\u{001b}[0m" }
fn color_bold(s : String) -> String { "\u{001b}[1m" + s + "\u{001b}[0m" }

fn status_color(status : @trace.SpanStatus, text : String) -> String {
  match status {
    @trace.Ok => color_green(text)
    @trace.Error => color_red(text)
    @trace.Running => color_yellow(text)
    @trace.Skipped => color_gray(text)
  }
}

fn status_label(status : @trace.SpanStatus) -> String {
  match status {
    @trace.Ok => "ok"
    @trace.Error => "error"
    @trace.Running => "running"
    @trace.Skipped => "skipped"
  }
}

/// Render a single span line with tree prefix
fn render_span(span : @trace.Span, prefix : String, is_last : Bool) -> String {
  let connector = if is_last { "└── " } else { "├── " }
  let status = status_color(span.status, status_label(span.status))
  let duration = match span.duration_ms {
    None => "?ms"
    Some(d) => "\{d}ms"
  }
  let mut line = prefix + connector + "[" + status + "] " + color_cyan(span.name) + " (" + duration + ")"
  match span.error_message {
    None => ()
    Some(msg) => line = line + " " + color_red("error=" + msg)
  }
  match span.input {
    None => ()
    Some(inp) => {
      let short = if inp.length() > 40 { inp[:40].to_owned() + "..." } else { inp }
      line = line + "\n" + prefix + (if is_last { "    " } else { "│   " }) + color_gray("input: " + short)
    }
  }
  match span.output {
    None => ()
    Some(out) => {
      let short = if out.length() > 40 { out[:40].to_owned() + "..." } else { out }
      line = line + "\n" + prefix + (if is_last { "    " } else { "│   " }) + color_gray("output: " + short)
    }
  }
  line
}

/// Recursively render span tree
fn render_tree(trace : @trace.Trace, span_id : String, prefix : String, is_last : Bool) -> String {
  let span = match trace.spans.get(span_id) {
    None => return ""
    Some(s) => s
  }
  let mut result = render_span(span, prefix, is_last)
  let children : Array[String] = []
  for span in trace.spans.values() {
    match span.parent_id {
      None => ()
      Some(pid) => if pid == span_id { children.push(span.id) }
    }
  }
  let child_prefix = prefix + (if is_last { "    " } else { "│   " })
  let mut i = 0
  for child_id in children {
    i = i + 1
    let child_last = i == children.length()
    result = result + "\n" + render_tree(trace, child_id, child_prefix, child_last)
  }
  result
}

/// Render full trace detail view
pub fn render_trace_detail(trace : @trace.Trace) -> String {
  let lines : Array[String] = []
  lines.push(color_bold("=== Trace " + trace.id + " ==="))
  lines.push("")

  // Stats
  let mut total_spans = 0
  let mut error_count = 0
  let mut total_duration = 0
  for span in trace.spans.values() {
    total_spans = total_spans + 1
    match span.status {
      @trace.Error => error_count = error_count + 1
      _ => ()
    }
    match span.duration_ms {
      None => ()
      Some(d) => total_duration = total_duration + d
    }
  }
  lines.push("Spans: \{total_spans}  Errors: \{error_count}  Total duration: \{total_duration}ms")
  lines.push("")

  // Span tree
  match trace.root_span_id {
    None => lines.push(color_gray("(no root span)"))
    Some(root_id) => {
      lines.push(render_tree(trace, root_id, "", true))
    }
  }
  lines.join("\n")
}

/// Render trace list table
pub fn render_trace_list(summaries : Array[@storage.TraceSummary]) -> String {
  let lines : Array[String] = []
  lines.push(color_bold("=== MoonTrace: Saved Traces ==="))
  lines.push("")
  if summaries.length() == 0 {
    lines.push(color_gray("No traces found. Run an agent with MoonTrace instrumentation first."))
    return lines.join("\n")
  }
  // Header
  lines.push(color_gray("  #  ID          Name                  Spans  Status"))
  lines.push(color_gray("  ─  ──────────  ────────────────────  ─────  ──────"))
  let mut i = 0
  for s in summaries {
    i = i + 1
    let name = match s.root_span_name {
      None => "?"
      Some(n) => if n.length() > 20 { n[:20].to_owned() } else { n }
    }
    let status = if s.has_error { color_red("error") } else { color_green("ok") }
    let idx = "\{i}"
    lines.push("  " + idx + "  " + s.trace_id + "  " + name + "  \{s.span_count}      " + status)
  }
  lines.push("")
  lines.push(color_gray("Use 'moontrace show <id>' to view trace details"))
  lines.join("\n")
}

/// Main TUI entry: parse args and render
pub fn run_tui(store : @storage.JsonFileStore) -> String {
  let args = @env.args()
  // args[0] is program name
  if args.length() < 2 {
    // Default: list
    return render_trace_list(store.list())
  }
  let cmd = args[1]
  if cmd == "list" || cmd == "ls" {
    return render_trace_list(store.list())
  }
  if cmd == "show" {
    if args.length() < 3 {
      return color_red("Error: 'show' requires a trace ID")
    }
    let trace_id = args[2]
    match store.load(trace_id) {
      None => return color_red("Error: trace not found: " + trace_id)
      Some(trace) => return render_trace_detail(trace)
    }
  }
  if cmd == "help" || cmd == "--help" || cmd == "-h" {
    let lines : Array[String] = []
    lines.push(color_bold("MoonTrace TUI Viewer"))
    lines.push("")
    lines.push("Usage: moontrace [command]")
    lines.push("")
    lines.push("Commands:")
    lines.push("  list              List all saved traces (default)")
    lines.push("  show <trace_id>   Show detailed trace view")
    lines.push("  help              Show this help")
    return lines.join("\n")
  }
  color_red("Unknown command: " + cmd + ". Use 'moontrace help' for usage.")
}
