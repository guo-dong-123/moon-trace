// Demo: Simulate an Agent conversation with nested spans

fn call_web_search(query : String) -> String raise Failure {
  @trace.span("tool.web_search", Some("{\"query\": \"" + query + "\"}"), () => {
    @trace.add_event("http_request", Some("GET /search?q=" + query))
    let result = "[{\"title\": \"MoonBit Guide\", \"snippet\": \"A fast language for reliable agents.\"}]"
    @trace.add_event("http_response", Some("200 OK"))
    result
  })
}

fn call_calculator(a : Int, b : Int) -> Int raise Failure {
  @trace.span("tool.calculator", Some("{\"a\": \{a}, \"b\": \{b}}"), () => {
    @trace.add_event("compute", Some("adding \{a} + \{b}"))
    a + b
  })
}

fn call_failing_tool() -> String raise Failure {
  @trace.span("tool.knowledge_base", Some("{\"query\": \"unknown topic\"}"), () => {
    @trace.add_event("search", Some("querying vector store..."))
    raise Failure("Knowledge base timeout after 5000ms")
  })
}

fn agent_think(user_input : String) -> String raise Failure {
  @trace.span("agent_think", Some("{\"input\": \"" + user_input + "\"}"), () => {
    @trace.add_event("reasoning", Some("Analyzing user intent..."))
    @trace.set_metadata("model", "gpt-4o")
    @trace.set_metadata("tokens", "156")
    "I need to search the documentation and do a calculation"
  })
}

fn handle_user_message(user_input : String) -> String raise Failure {
  @trace.span("handle_user_message", Some("{\"user\": \"" + user_input + "\"}"), () => {
    let _plan = agent_think(user_input)

    // Tool call 1: retrieve context for the agent
    let search_result = call_web_search("MoonBit agent observability")

    // Tool call 2: calculator
    let calc_result = call_calculator(42, 58)

    // Tool call 3: will fail (demonstrates error capture, handled gracefully)
    let kb_result = try {
      call_failing_tool()
    } catch {
      Failure(_) => "knowledge base unavailable (handled gracefully)"
    }

    let answer = "Research: \{search_result}, Calc: \{calc_result}, KB: \{kb_result}"
    answer
  })
}

fn main raise Failure {
  println("=== MoonTrace Phase 1 Demo ===\n")

  let trace_id = @trace.start_trace()
  println("Started trace: \{trace_id}\n")

  let answer = handle_user_message("How can I observe a MoonBit agent and what is 42+58?")
  println("Agent answer: \{answer}\n")

  let trace = @trace.end_trace()

  match trace {
    None => println("No trace found!")
    Some(t) => @trace.print_trace(t)
  }

  println("\n=== Phase 1 complete ===")
}
