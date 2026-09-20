// MoonTrace CLI entry point

fn print_help() -> Unit {
  println("MoonTrace - Agent execution trace observability tool")
  println("")
  println("Usage: moontrace <command> [options]")
  println("")
  println("Commands:")
  println("  list                    List all saved traces")
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

fn cmd_list() -> Unit {
  let store = get_store()
  println(@tui.render_trace_list(store.list()))
}

fn cmd_show(trace_id : String) -> Unit {
  let store = get_store()
  match store.load(trace_id) {
    None => println("Error: trace not found: " + trace_id)
    Some(trace) => println(@tui.render_trace_detail(trace))
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
    cmd_list()
    return
  }
  let cmd = args[1]
  match cmd {
    "list" | "ls" => cmd_list()
    "show" => {
      if args.length() < 3 {
        println("Error: 'show' requires a trace ID")
      } else {
        cmd_show(args[2])
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
