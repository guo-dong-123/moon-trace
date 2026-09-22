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
