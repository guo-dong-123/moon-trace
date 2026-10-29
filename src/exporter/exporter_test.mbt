// Tests for self-contained HTML export.

///|
test "export_html_escapes_trace_content" {
  ignore(@trace.start_trace())
  ignore(
    @trace.span("root <trace> ' onclick='alert(1)", Some("input <value>"), () => {
      @trace.set_metadata("model", "qwen <test> <svg onload='alert(1)'> & &")
      @trace.add_event("request_started", Some("payload & details"))
      @trace.span("failing & child", None, () => raise Failure("bad <input>")) catch {
        Failure(_) => ()
      }
      "ok"
    }),
  )
  match @trace.end_trace() {
    None => assert_true(false)
    Some(trace) => {
      let html = @exporter.export_trace_html(trace)
      assert_true(html.contains("root &lt;trace&gt;"))
      assert_true(html.contains("&#39; onclick=&#39;alert(1)"))
      assert_true(
        !html.contains("title='root &lt;trace&gt; ' onclick='alert(1)"),
      )
      assert_true(html.contains("input &lt;value&gt;"))
      assert_true(html.contains("failing &amp; child"))
      assert_true(html.contains("bad &lt;input&gt;"))
      assert_true(html.contains("qwen &lt;test&gt;"))
      assert_true(
        html.contains("&lt;svg onload=&#39;alert(1)&#39;&gt; &amp; &amp;"),
      )
      assert_true(!html.contains("<svg"))
      assert_true(html.contains("request_started"))
      assert_true(html.contains("payload &amp; details"))
      assert_true(html.contains("trace-search"))
      assert_true(html.contains("filterTrace"))
      assert_true(html.contains("<style>"))
    }
  }
}

///|
test "export includes independent roots in one session" {
  let session = @trace.TraceSession::new()
  ignore(@trace.span_in(session.context(), "first-root", None, _ => "one"))
  ignore(@trace.span_in(session.context(), "second-root", None, _ => "two"))
  let html = @exporter.export_trace_html(session.finish())
  assert_true(html.contains("first-root"))
  assert_true(html.contains("second-root"))
  assert_true(html.contains("Elapsed duration"))
  assert_true(html.contains("Cumulative span time"))
}
