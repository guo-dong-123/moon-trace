fn regression_trace(should_fail : Bool) -> @trace.Trace raise Failure {
  ignore(@trace.start_trace())
  try {
    ignore(@trace.span("agent.run", None, () => {
      if should_fail {
        raise Failure("failed")
      }
      "answer"
    }))
  } catch {
    Failure(_) => ()
  }
  match @trace.end_trace() {
    None => raise Failure("no trace")
    Some(trace) => trace
  }
}

test "regression_report_passes_for_same_status" {
  let report = compare_traces(regression_trace(false), regression_trace(false))
  assert_true(report.passed())
  assert_true(report.issue_count() == 0)
}

test "regression_report_detects_status_change" {
  let report = compare_traces(regression_trace(false), regression_trace(true))
  assert_true(!report.passed())
  assert_true(report.issue_count() == 1)
}

fn repeated_trace(fail_first : Bool, fail_second : Bool, calls : Int) -> @trace.Trace raise Failure {
  ignore(@trace.start_trace())
  for i in 0..<calls {
    let should_fail = if i == 0 { fail_first } else { fail_second }
    try {
      ignore(@trace.span("tool.search", None, () => {
        if should_fail {
          raise Failure("search failed")
        }
        "result"
      }))
    } catch {
      Failure(_) => ()
    }
  }
  match @trace.end_trace() {
    None => raise Failure("no trace")
    Some(trace) => trace
  }
}

test "regression_report_detects_missing_repeated_call" {
  let report = compare_traces(
    repeated_trace(false, false, 2), repeated_trace(false, false, 1),
  )
  assert_true(!report.passed())
  assert_true(report.issue_count() == 1)
  match report.issues[0] {
    RegressionIssue::MissingSpan(name) => inspect(name, content="tool.search")
    _ => assert_true(false)
  }
}

test "regression_report_detects_added_repeated_call" {
  let report = compare_traces(
    repeated_trace(false, false, 1), repeated_trace(false, false, 2),
  )
  assert_true(!report.passed())
  assert_true(report.issue_count() == 1)
  match report.issues[0] {
    RegressionIssue::AddedSpan(name) => inspect(name, content="tool.search")
    _ => assert_true(false)
  }
}

test "regression_report_detects_one_failed_repeated_call" {
  let report = compare_traces(
    repeated_trace(false, false, 2), repeated_trace(false, true, 2),
  )
  assert_true(!report.passed())
  assert_true(report.issue_count() == 1)
  match report.issues[0] {
    RegressionIssue::StatusChanged(name, before, after) => {
      inspect(name, content="tool.search")
      inspect(before, content="ok")
      inspect(after, content="error")
    }
    _ => assert_true(false)
  }
}

test "regression_report_matches_repeated_calls_by_status" {
  let report = compare_traces(
    repeated_trace(false, true, 2), repeated_trace(true, false, 2),
  )
  assert_true(report.passed())
}
