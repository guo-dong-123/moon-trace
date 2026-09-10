// Phase 3 test: TUI viewer

fn make_sample_trace(name : String, with_error : Bool) -> @trace.Trace raise Failure {
  ignore(@trace.start_trace())
  ignore(@trace.span(name, Some("{\"user\": \"hello\"}"), () => {
    ignore(@trace.span("agent_think", Some("{\"prompt\": \"What is 2+2?\"}"), () => {
      "thinking about math"
    }))
    ignore(@trace.span("call_calculator", Some("{\"expr\": \"2+2\"}"), () => {
      "4"
    }))
    if with_error {
      try {
        @trace.span("call_knowledge_base", Some("{\"query\": \"weather\"}"), () => {
          raise Failure("Knowledge base timeout after 5000ms")
        })
      } catch {
        Failure(_) => ignore("fallback used")
      }
    } else {
      ignore(@trace.span("call_weather_api", Some("{\"city\": \"Shanghai\"}"), () => {
        "{\"temp\": 25, \"condition\": \"sunny\"}"
      }))
    }
    "The answer is 4"
  }))
  match @trace.end_trace() {
    None => raise Failure("no trace")
    Some(t) => t
  }
}

fn main raise Failure {
  println("=== MoonTrace Phase 3: TUI Viewer Test ===\n")

  // Use a test directory
  let test_dir = "/tmp/moontrace_tui_test"
  let store = @storage.JsonFileStore::new(test_dir)

  // Generate sample traces
  println("Generating sample traces...")
  let t1 = make_sample_trace("handle_user_message", false)
  let t2 = make_sample_trace("api_pipeline", true)
  let t3 = make_sample_trace("data_analysis", false)
  store.save(t1)
  store.save(t2)
  store.save(t3)
  println("Saved 3 traces to \{test_dir}\n")

  // Test list view
  println("--- List View ---")
  println(@tui.render_trace_list(store.list()))
  println("")

  // Test detail view
  println("--- Detail View (first trace) ---")
  let list = store.list()
  match store.load(list[0].trace_id) {
    None => println("Failed to load trace")
    Some(trace) => println(@tui.render_trace_detail(trace))
  }
  println("")

  // Test detail view with error
  println("--- Detail View (error trace) ---")
  match store.load(list[1].trace_id) {
    None => println("Failed to load trace")
    Some(trace) => println(@tui.render_trace_detail(trace))
  }

  println("\n=== Phase 3 complete ===")
}
