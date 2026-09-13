// Example Research Agent with MoonTrace instrumentation
// Demonstrates how to integrate MoonTrace into a real agent workflow

struct SearchResult {
  title : String
  snippet : String
} derive(Show)

fn search_web(query : String) -> Array[SearchResult] {
  // Simulated web search
  ignore(query)
  [
    { title: "MoonBit Language Guide", snippet: "MoonBit is a fast, expressive language..." },
    { title: "Agent Observability", snippet: "Tracing agent execution helps debug..." },
  ]
}

fn calculate(expression : String) -> String raise Failure {
  // Simulated calculator
  if expression.contains("divide by zero") {
    raise Failure("Division by zero")
  }
  "42"
}

fn query_knowledge_base(question : String) -> String raise Failure {
  // Simulated knowledge base that sometimes fails
  if question.contains("unavailable") {
    raise Failure("Knowledge base timeout after 5000ms")
  }
  "The answer can be found in the documentation."
}

fn get_store() -> @storage.JsonFileStore {
  match @env.get_env_var("MOONTRACE_DIR") {
    None => @storage.JsonFileStore::default()
    Some(dir) => @storage.JsonFileStore::new(dir)
  }
}

fn run_research_agent(user_query : String) -> String raise Failure {
  // Top-level trace: entire agent execution
  ignore(@trace.start_trace())

  let result = @trace.span("research_agent.run", Some("{\"query\": \"" + user_query + "\"}"), () => {
    @trace.set_metadata("user_id", "demo_user_001")
    @trace.set_metadata("model", "demo-model-v1")

    // Step 1: Plan the research
    ignore(@trace.span("agent.plan", Some("{\"query\": \"" + user_query + "\"}"), () => {
      @trace.add_event("thinking_start", Some("Breaking down query into sub-tasks"))
      let steps = ["search", "calculate", "synthesize"]
      @trace.add_event("thinking_complete", Some("Plan: search -> calculate -> synthesize"))
      steps
    }))

    // Step 2: Web search
    let search_results = @trace.span("tool.web_search", Some("{\"query\": \"" + user_query + "\"}"), () => {
      let results = search_web(user_query)
      @trace.set_metadata("result_count", "\{results.length()}")
      results
    })

    // Step 3: Calculation (may fail)
    let calc_result = try {
      @trace.span("tool.calculator", Some("{\"expr\": \"2+2*10\"}"), () => {
        calculate("2+2*10")
      })
    } catch {
      Failure(_) => {
        @trace.add_event("calculator_fallback", Some("Using approximate result"))
        "~22 (approximate)"
      }
    }

    // Step 4: Knowledge base (demonstrates error span)
    let kb_result = try {
      @trace.span("tool.knowledge_base", Some("{\"question\": \"" + user_query + "\"}"), () => {
        query_knowledge_base(user_query)
      })
    } catch {
      Failure(_) => {
        // Error is captured by the span, we provide a fallback
        @trace.add_event("kb_fallback", Some("Falling back to web results only"))
        "No knowledge base result, using web search."
      }
    }

    // Step 5: Synthesize answer
    let answer = @trace.span("agent.synthesize", None, () => {
      @trace.add_event("synthesis_start", Some("Combining " + "\{search_results.length()}" + " search results"))
      let mut answer_text = "Based on my research:\n\n"
      for r in search_results {
        answer_text = answer_text + "- " + r.title + ": " + r.snippet + "\n"
      }
      answer_text = answer_text + "\nCalculation result: " + calc_result + "\n"
      answer_text = answer_text + "Knowledge base: " + kb_result + "\n"
      answer_text
    })

    answer
  })

  // End trace and save to storage
  match @trace.end_trace() {
    None => ()
    Some(trace) => {
      let store = get_store()
      ignore(store.save(trace))
      println("Trace saved: " + trace.id + " (" + "\{trace.spans.length()}" + " spans)")
    }
  }

  result
}

fn main raise Failure {
  println("=== MoonTrace Example: Research Agent ===\n")

  // Run 1: Normal query (succeeds)
  println("--- Run 1: Normal query ---")
  let answer1 = run_research_agent("What is MoonBit?")
  println(answer1)
  println("")

  // Run 2: Query that triggers knowledge base failure
  println("--- Run 2: Knowledge base unavailable ---")
  let answer2 = run_research_agent("unavailable topic about agents")
  println(answer2)
  println("")

  // Run 3: Another normal query
  println("--- Run 3: Calculation-heavy query ---")
  let answer3 = run_research_agent("How to build an agent?")
  println(answer3)

  println("\n=== Done ===")
  match @env.get_env_var("MOONTRACE_DIR") {
    None => println("Traces saved to ~/.moontrace/traces/")
    Some(dir) => println("Traces saved to " + dir)
  }
  println("View with: moontrace list")
  println("Export with: moontrace export <trace_id>")
}
