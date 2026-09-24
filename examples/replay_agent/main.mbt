// A recorded tool session can drive the same agent without another tool call.

fn get_store() -> @storage.JsonFileStore {
  match @env.get_env_var("MOONTRACE_DIR") {
    None => @storage.JsonFileStore::default()
    Some(dir) => @storage.JsonFileStore::new(dir)
  }
}

fn lookup_live(query : String, calls : Array[Int]) -> String raise Failure {
  calls[0] = calls[0] + 1
  if query == "beta" {
    raise Failure("lookup unavailable for beta")
  }
  "found:" + query
}

fn lookup(
  query : String,
  session : Option[@replay.ReplaySession],
  calls : Array[Int],
) -> String raise Failure {
  @trace.span("tool.lookup", Some(query), () => {
    match session {
      None => lookup_live(query, calls)
      Some(recording) => recording.run("tool.lookup", Some(query))
    }
  })
}

fn run_agent(
  session : Option[@replay.ReplaySession],
  calls : Array[Int],
) -> (String, @trace.Trace) raise Failure {
  ignore(@trace.start_trace())
  let answer = @trace.span("agent.run", None, () => {
    let first = lookup("alpha", session, calls)
    let second = try {
      lookup("beta", session, calls)
    } catch {
      Failure(_) => "cached fallback"
    }
    let third = lookup("gamma", session, calls)
    first + " | " + second + " | " + third
  })
  match @trace.end_trace() {
    None => raise Failure("agent trace was not closed")
    Some(trace) => (answer, trace)
  }
}

fn main raise Failure {
  let calls = [0]
  let store = get_store()
  let (original, baseline) = run_agent(None, calls)
  if !store.save(baseline) {
    raise Failure("failed to save baseline trace")
  }
  let live_calls = calls[0]
  let recorded = match store.load(baseline.id) {
    None => raise Failure("failed to load baseline trace")
    Some(trace) => trace
  }
  let session = @replay.ReplaySession::from_trace(recorded)
  let (replayed, candidate) = run_agent(Some(session), calls)
  if !store.save(candidate) {
    raise Failure("failed to save replay trace")
  }
  if original != replayed || calls[0] != live_calls ||
    session.consumed_count("tool.lookup") != 3 {
    raise Failure("replay changed the answer or called the live tool")
  }
  if !@replay.compare_traces(baseline, candidate).passed() {
    raise Failure("replayed span statuses differ from baseline")
  }
  println("Original: " + original)
  println("Replayed: " + replayed)
  println("Live tool calls: \{live_calls} before replay, \{calls[0]} after replay")
  println("Baseline trace: " + baseline.id)
  println("Replay trace: " + candidate.id)
  println("PASS: recorded outputs and failure reproduced without live tool calls")
}
