// Phase 2 test: storage layer

fn make_demo_trace(name : String, with_error : Bool) -> @trace.Trace raise Failure {
  ignore(@trace.start_trace())
  ignore(@trace.span(name, Some("{}"), () => {
    ignore(@trace.span("sub_task_1", None, () => {
      "result1"
    }))
    if with_error {
      try {
        @trace.span("failing_task", None, () => {
          raise Failure("something went wrong")
        })
      } catch {
        Failure(_) => ignore("handled")
      }
    } else {
      ignore(@trace.span("sub_task_2", None, () => {
        "result2"
      }))
    }
    "done"
  }))
  let trace = @trace.end_trace()
  match trace {
    None => raise Failure("no trace")
    Some(t) => t
  }
}

fn status_to_string(s : @trace.SpanStatus) -> String {
  match s {
    @trace.Running => "running"
    @trace.Ok => "ok"
    @trace.Error => "error"
    @trace.Skipped => "skipped"
  }
}

fn test_memory_store() -> Unit raise Failure {
  println("=== Test MemoryStore ===")
  let store = @storage.MemoryStore::new()

  let t1 = make_demo_trace("user_chat", false)
  let t2 = make_demo_trace("api_call", true)

  store.save(t1)
  store.save(t2)

  let list = store.list()
  println("List count: \{list.length()}")
  for s in list {
    let name = match s.root_span_name { None => "?"; Some(n) => n }
    println("  - \{s.trace_id}: \{name} spans=\{s.span_count} error=\{s.has_error}")
  }

  let loaded = store.load(list[0].trace_id)
  match loaded {
    None => println("FAIL: could not load trace")
    Some(t) => println("Loaded trace, spans: \{t.spans.length()}")
  }

  let filter = @storage.TraceFilter::error_only()
  let errors = @storage.query_summaries(store.list(), filter)
  println("Error-only query count: \{errors.length()}")

  let deleted = store.delete(list[0].trace_id)
  println("Deleted first trace: \{deleted}")
  println("After delete count: \{store.list().length()}")
  println("")
}

fn test_json_file_store() -> Unit raise Failure {
  println("=== Test JsonFileStore ===")
  let test_dir = "/tmp/moontrace_test_003"

  let store = @storage.JsonFileStore::new(test_dir)

  let t1 = make_demo_trace("browser_automation", false)
  let t2 = make_demo_trace("data_pipeline", true)
  let t3 = make_demo_trace("user_chat_v2", false)

  store.save(t1)
  store.save(t2)
  store.save(t3)

  println("Saved 3 traces")

  let list = store.list()
  println("List count: \{list.length()}")
  for s in list {
    let name = match s.root_span_name { None => "?"; Some(n) => n }
    println("  - \{s.trace_id}: \{name} spans=\{s.span_count} error=\{s.has_error}")
  }

  let loaded = store.load(list[0].trace_id)
  match loaded {
    None => println("FAIL: could not load trace")
    Some(t) => {
      println("Loaded trace \{t.id}, spans: \{t.spans.length()}")
      for span in t.spans.values() {
        println("    span: \{span.name} status=\{status_to_string(span.status)}")
      }
    }
  }

  let filter = @storage.TraceFilter::with_name("chat")
  let chats = @storage.query_summaries(store.list(), filter)
  println("Name contains 'chat' count: \{chats.length()}")

  let deleted = store.delete(list[0].trace_id)
  println("Deleted first trace: \{deleted}")
  println("After delete count: \{store.list().length()}")

  let trace_file = test_dir + "/" + list[1].trace_id + ".json"
  let index_file = test_dir + "/index.json"
  let te = @fs.path_exists(trace_file)
  let ie = @fs.path_exists(index_file)
  println("Trace file exists: \{te}")
  println("Index file exists: \{ie}")
  println("")
}

fn main raise Failure {
  println("=== MoonTrace Phase 2: Storage Test ===\n")
  test_memory_store()
  test_json_file_store()
  println("=== Phase 2 complete ===")
}
