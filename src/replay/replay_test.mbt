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
