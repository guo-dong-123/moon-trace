// Demonstrates diagnosing a failed tool call and recording the recovery path.

fn get_store() -> @storage.JsonFileStore {
  match @env.get_env_var("MOONTRACE_DIR") {
    None => @storage.JsonFileStore::default()
    Some(dir) => @storage.JsonFileStore::new(dir)
  }
}

fn remote_knowledge_lookup(question : String) -> String raise Failure {
  @trace.span(
    "tool.knowledge_base",
    Some("{\"question\": \"" + question + "\"}"),
    () => {
      @trace.add_event("request_started", Some("GET /knowledge/search"))
      @trace.set_metadata("timeout_ms", "2500")
      raise Failure("knowledge base timeout after 2500ms")
    },
  )
}

fn run_diagnosis() -> String raise Failure {
  ignore(@trace.start_trace())
  let answer = @trace.span(
    "agent.answer",
    Some("{\"question\": \"How do I debug a failed MoonBit tool?\"}"),
    () => {
      @trace.set_metadata("scenario", "tool-timeout-recovery")
      let result = try {
        remote_knowledge_lookup("MoonBit tool tracing")
      } catch {
        Failure(message) => {
          @trace.add_event("fallback_started", Some("Using cached documentation"))
          @trace.set_metadata("recovery", "cache")
          "Fallback answer after: " + message
        }
      }
      @trace.span("agent.synthesize", None, () => {
        "Diagnosis complete. " + result
      })
    },
  )
  match @trace.end_trace() {
    None => raise Failure("trace was not closed")
    Some(trace) => {
      let saved = get_store().save(trace)
      if !saved {
        raise Failure("failed to save diagnosis trace")
      }
      println("Saved diagnosis trace: " + trace.id)
      println("The failed tool span and recovery event are preserved.")
    }
  }
  answer
}

fn main raise Failure {
  println("=== MoonTrace Failure Diagnosis Demo ===")
  let answer = run_diagnosis()
  println("\nAgent result:\n" + answer)
  println("\nInspect all traces: moon run src/cli list")
  println("Inspect failures:    moon run src/cli errors")
}
