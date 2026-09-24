fn make_replay_trace() -> @trace.Trace raise Failure {
  ignore(@trace.start_trace())
  ignore(@trace.span("agent.run", None, () => {
    ignore(@trace.span("tool.search", Some("query"), () => "cached result"))
    try {
      @trace.span("tool.unavailable", None, () => {
        raise Failure("recorded timeout")
      })
    } catch {
      Failure(_) => ()
    }
    "answer"
  }))
  match @trace.end_trace() {
    None => raise Failure("no trace")
    Some(trace) => trace
  }
}

test "replay_returns_recorded_output" {
  let session = ReplaySession::from_trace(make_replay_trace())
  match session.replay("tool.search") {
    ReplayResult::Output(value) => inspect(value, content="cached result")
    _ => inspect("wrong result", content="cached result")
  }
  assert_true(session.consumed_count("tool.search") == 1)
  assert_true(session.remaining() == 2)
}

test "replay_preserves_recorded_error" {
  let session = ReplaySession::from_trace(make_replay_trace())
  match session.replay("tool.unavailable") {
    ReplayResult::Error(message) => inspect(message, content="recorded timeout")
    _ => inspect("wrong result", content="recorded timeout")
  }
}

test "replay_reports_missing_span" {
  let session = ReplaySession::from_trace(make_replay_trace())
  match session.replay("tool.unknown") {
    ReplayResult::Missing => assert_true(true)
    _ => assert_true(false)
  }
}

fn repeated_replay_trace() -> @trace.Trace raise Failure {
  ignore(@trace.start_trace())
  for i in 0..<12 {
    let input = "query-\{i}"
    ignore(@trace.span("tool.search", Some(input), () => "result-\{i}"))
  }
  match @trace.end_trace() {
    None => raise Failure("no trace")
    Some(trace) => trace
  }
}

test "replay_consumes_repeated_calls_in_recorded_order" {
  let session = ReplaySession::from_trace(repeated_replay_trace())
  assert_true(session.remaining() == 12)
  for i in 0..<12 {
    inspect(session.run("tool.search", Some("query-\{i}")), content="result-\{i}")
  }
  assert_true(session.consumed_count("tool.search") == 12)
  assert_true(session.remaining() == 0)
  match session.replay("tool.search") {
    ReplayResult::Missing => assert_true(true)
    _ => assert_true(false)
  }
  assert_true(session.consumed_count("tool.search") == 12)
}

test "replay_rejects_different_input_without_consuming_call" {
  let session = ReplaySession::from_trace(repeated_replay_trace())
  try session.run("tool.search", Some("wrong query")) catch {
    Failure(message) => inspect(message, content="recorded input differs for tool.search")
  } noraise {
    _ => assert_true(false)
  }
  assert_true(session.consumed_count("tool.search") == 0)
  inspect(session.run("tool.search", Some("query-0")), content="result-0")
}

test "replay_run_preserves_recorded_failure" {
  let session = ReplaySession::from_trace(make_replay_trace())
  try session.run("tool.unavailable", None) catch {
    Failure(message) => inspect(message, content="recorded timeout")
  } noraise {
    _ => assert_true(false)
  }
  assert_true(session.consumed_count("tool.unavailable") == 1)
}
