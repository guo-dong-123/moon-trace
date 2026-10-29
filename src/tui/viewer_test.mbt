test "terminal view includes every independent root" {
  let session = @trace.TraceSession::new()
  ignore(@trace.span_in(session.context(), "alpha-root", None, _ => "one"))
  ignore(@trace.span_in(session.context(), "beta-root", None, _ => "two"))
  let output = render_trace_detail(session.finish())
  assert_true(output.contains("alpha-root"))
  assert_true(output.contains("beta-root"))
  assert_true(output.contains("Cumulative span time:"))
}
