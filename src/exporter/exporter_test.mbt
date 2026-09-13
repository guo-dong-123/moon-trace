// Tests for self-contained HTML export.

test "export_html_escapes_trace_content" {
  ignore(@trace.start_trace())
  ignore(@trace.span("root <trace>", Some("input <value>"), () => {
    try {
      @trace.span("failing & child", None, () => {
        raise Failure("bad <input>")
      })
    } catch {
      Failure(_) => ()
    }
    "ok"
  }))
  match @trace.end_trace() {
    None => assert_true(false)
    Some(trace) => {
      let html = export_trace_html(trace)
      assert_true(html.contains("root &lt;trace&gt;"))
      assert_true(html.contains("input &lt;value&gt;"))
      assert_true(html.contains("failing &amp; child"))
      assert_true(html.contains("bad &lt;input&gt;"))
      assert_true(html.contains("<style>"))
    }
  }
}
