// MoonTrace CLI entry point

fn print_help() -> Unit {
  println("MoonTrace - Agent execution trace observability tool")
  println("")
  println("Usage: moontrace <command> [options]")
  println("")
  println("Commands:")
  println("  list [options]          List saved traces")
  println("    --errors              Show only traces containing errors")
  println("    --name <text>         Filter by root span name")
  println("  errors                  List only traces containing errors")
  println("  compare <a> <b>         Compare two traces by span name")
  println("  show <trace_id>         Show detailed trace view in terminal")
  println("  export <trace_id> [out] Export trace to HTML file (default: <id>.html)")
  println("  export-all [dir]        Export all traces to HTML files in directory")
  println("  delete <trace_id>       Delete a trace")
  println("  help                    Show this help")
  println("")
  println("Environment:")
  println("  MOONTRACE_DIR           Override trace storage directory")
  println("  AGENT_QUERY             Override the Bailian demo question")
}

fn get_store() -> @storage.JsonFileStore {
  match @env.get_env_var("MOONTRACE_DIR") {
    None => @storage.JsonFileStore::default()
    Some(dir) => @storage.JsonFileStore::new(dir)
  }
}

fn cmd_list(filter : @storage.TraceFilter) -> Unit {
  let store = get_store()
  println(@tui.render_trace_list(@storage.query_summaries(store.list(), filter)))
}

fn cmd_list_args(args : Array[String]) -> Unit {
  let mut errors = false
  let mut name : Option[String] = None
  let mut i = 2
  while i < args.length() {
    match args[i] {
      "--errors" => errors = true
      "--name" => {
        if i + 1 < args.length() {
          name = Some(args[i + 1])
          i = i + 1
        } else {
          println("Error: '--name' requires a value")
          return
        }
      }
      value => {
        println("Error: unknown list option: " + value)
        return
      }
    }
    i = i + 1
  }
  let filter = match (errors, name) {
    (true, Some(value)) => @storage.TraceFilter::with_name_and_errors(value)
    (true, None) => @storage.TraceFilter::error_only()
    (false, Some(value)) => @storage.TraceFilter::with_name(value)
    (false, None) => @storage.TraceFilter::new()
  }
  cmd_list(filter)
}

fn cmd_show(trace_id : String) -> Unit {
  let store = get_store()
  match store.load(trace_id) {
    None => println("Error: trace not found: " + trace_id)
    Some(trace) => println(@tui.render_trace_detail(trace))
  }
}

fn trace_duration(trace : @trace.Trace) -> Int {
  let mut total = 0
  for span in trace.spans.values() {
    match span.duration_ms {
      None => ()
      Some(value) => total = total + value
    }
  }
  total
}

fn trace_error_count(trace : @trace.Trace) -> Int {
  let mut count = 0
  for span in trace.spans.values() {
    if status_label(span.status) == "error" {
      count = count + 1
    }
  }
  count
}

fn status_label(status : @trace.SpanStatus) -> String {
  match status {
    @trace.Ok => "ok"
    @trace.Error => "error"
    @trace.Running => "running"
    @trace.Skipped => "skipped"
  }
}

fn find_span_by_name(trace : @trace.Trace, name : String) -> Option[@trace.Span] {
  for span in trace.spans.values() {
    if span.name == name {
      return Some(span)
    }
  }
  None
}

fn cmd_compare(first_id : String, second_id : String) -> Unit {
  let store = get_store()
  let first = store.load(first_id)
  let second = store.load(second_id)
  match (first, second) {
    (Some(a), Some(b)) => {
      println("=== MoonTrace Trace Comparison ===")
      println("A: " + a.id + "  B: " + b.id)
      println("Total duration: " + "\{trace_duration(a)}ms -> \{trace_duration(b)}ms")
      println("Span count: " + "\{a.spans.length()} -> \{b.spans.length()}")
      println("Error count: " + "\{trace_error_count(a)} -> \{trace_error_count(b)}")
      println("")
      println("Span changes:")
      let seen : Map[String, Bool] = Map([])
      for span in a.spans.values() {
        seen[span.name] = true
        match find_span_by_name(b, span.name) {
          None => println("- " + span.name + ": removed")
          Some(other) => {
            let first_duration = span.duration_ms.unwrap_or(0)
            let second_duration = other.duration_ms.unwrap_or(0)
            let delta = second_duration - first_duration
            let status_change = if status_label(span.status) == status_label(other.status) {
              status_label(span.status)
            } else {
              status_label(span.status) + " -> " + status_label(other.status)
            }
            println("- " + span.name + ": " + "\{first_duration}ms -> \{second_duration}ms (delta \{delta}ms, " + status_change + ")")
          }
        }
      }
      for span in b.spans.values() {
        if !seen.contains(span.name) {
          println("- " + span.name + ": added")
        }
      }
    }
    (None, _) => println("Error: trace not found: " + first_id)
    (_, None) => println("Error: trace not found: " + second_id)
  }
}

fn cmd_export(trace_id : String, out_path : Option[String]) -> Unit {
  let store = get_store()
  match store.load(trace_id) {
    None => println("Error: trace not found: " + trace_id)
    Some(trace) => {
      let html = @exporter.export_trace_html(trace)
      let path = match out_path {
        None => trace_id + ".html"
        Some(p) => p
      }
      try {
        @fs.write_string_to_file(path, html)
        println("Exported trace " + trace_id + " to " + path)
      } catch {
        _ => println("Error: failed to write file " + path)
      }
    }
  }
}

fn cmd_export_all(dir : Option[String]) -> Unit {
  let store = get_store()
  let summaries = store.list()
  let out_dir = match dir {
    None => "moontrace_export"
    Some(d) => d
  }
  // Create output directory
  if !@fs.path_exists(out_dir) {
    try {
      @fs.create_dir(out_dir)
      } catch {
          _ => println("Warning: failed to export a trace")
    }
  }
  let mut count = 0
  for s in summaries {
    match store.load(s.trace_id) {
      None => ()
      Some(trace) => {
        let html = @exporter.export_trace_html(trace)
        let path = out_dir + "/" + s.trace_id + ".html"
        try {
          @fs.write_string_to_file(path, html)
          count = count + 1
        } catch {
          _ => ()
        }
      }
    }
  }
  // Also export index
  let index_html = @exporter.export_index_html(summaries)
  try {
    @fs.write_string_to_file(out_dir + "/index.html", index_html)
  } catch {
    _ => println("Warning: failed to export index")
  }
  println("Exported " + "\{count}" + " traces to " + out_dir + "/")
}

fn cmd_delete(trace_id : String) -> Unit {
  let store = get_store()
  if store.delete(trace_id) {
    println("Deleted trace: " + trace_id)
  } else {
    println("Error: trace not found: " + trace_id)
  }
}

fn main {
  let args = @env.args()
  // args[0] = program path, args[1] = command
  if args.length() < 2 {
    cmd_list(@storage.TraceFilter::new())
    return
  }
  let cmd = args[1]
  match cmd {
    "list" | "ls" => cmd_list_args(args)
    "errors" => cmd_list(@storage.TraceFilter::error_only())
    "show" => {
      if args.length() < 3 {
        println("Error: 'show' requires a trace ID")
      } else {
        cmd_show(args[2])
      }
    }
    "compare" => {
      if args.length() < 4 {
        println("Error: 'compare' requires two trace IDs")
      } else {
        cmd_compare(args[2], args[3])
      }
    }
    "export" => {
      if args.length() < 3 {
        println("Error: 'export' requires a trace ID")
      } else {
        let out = if args.length() >= 4 { Some(args[3]) } else { None }
        cmd_export(args[2], out)
      }
    }
    "export-all" => {
      let dir = if args.length() >= 3 { Some(args[2]) } else { None }
      cmd_export_all(dir)
    }
    "delete" | "rm" => {
      if args.length() < 3 {
        println("Error: 'delete' requires a trace ID")
      } else {
        cmd_delete(args[2])
      }
    }
    "help" | "--help" | "-h" => print_help()
    _ => {
      println("Unknown command: " + cmd)
      println("Use 'moontrace help' for usage")
    }
  }
}
