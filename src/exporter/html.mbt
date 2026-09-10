// HTML exporter: generate self-contained interactive trace visualization

fn escape_html(s : String) -> String {
  s.replace(old="&", new="&amp;").replace(old="<", new="&lt;").replace(old=">", new="&gt;").replace(old="\"", new="&quot;")
}

fn status_class(status : @trace.SpanStatus) -> String {
  match status {
    @trace.Ok => "ok"
    @trace.Error => "error"
    @trace.Running => "running"
    @trace.Skipped => "skipped"
  }
}

fn status_text(status : @trace.SpanStatus) -> String {
  match status {
    @trace.Ok => "OK"
    @trace.Error => "ERROR"
    @trace.Running => "RUNNING"
    @trace.Skipped => "SKIPPED"
  }
}

fn css_styles() -> String {
  "*{box-sizing:border-box;margin:0;padding:0}" +
  "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#1a1a2e;color:#e0e0e0;padding:24px}" +
  "h1{font-size:20px;margin-bottom:16px;color:#00d4ff}" +
  ".stats{display:flex;gap:16px;margin-bottom:24px;flex-wrap:wrap}" +
  ".stat-card{background:#16213e;border-radius:8px;padding:12px 20px;min-width:120px}" +
  ".stat-value{font-size:24px;font-weight:bold;color:#00d4ff}" +
  ".stat-label{font-size:12px;color:#888;text-transform:uppercase}" +
  ".stat-card.error .stat-value{color:#ff6b6b}" +
  ".section{background:#16213e;border-radius:8px;padding:16px;margin-bottom:24px}" +
  ".section-title{font-size:14px;color:#888;text-transform:uppercase;margin-bottom:12px;letter-spacing:1px}" +
  ".span-node{margin-bottom:4px}" +
  ".span-header{display:flex;align-items:center;gap:8px;padding:6px 8px;border-radius:4px;cursor:pointer;user-select:none}" +
  ".span-header:hover{background:rgba(255,255,255,0.05)}" +
  ".span-toggle{width:16px;font-size:10px;color:#666}" +
  ".span-badge{font-size:10px;padding:2px 6px;border-radius:3px;font-weight:bold;text-transform:uppercase}" +
  ".span-badge.ok{background:#1a4a1a;color:#4ade80}" +
  ".span-badge.error{background:#4a1a1a;color:#f87171}" +
  ".span-badge.running{background:#4a4a1a;color:#facc15}" +
  ".span-badge.skipped{background:#333;color:#888}" +
  ".span-name{flex:1;font-family:'SF Mono',Monaco,monospace;font-size:13px}" +
  ".span-duration{font-size:12px;color:#888;font-family:monospace}" +
  ".span-body{padding-left:24px}" +
  ".span-node.collapsed .span-body{display:none}" +
  ".span-node.collapsed .span-toggle{transform:rotate(-90deg);display:inline-block}" +
  ".span-io{font-size:12px;color:#aaa;margin:4px 0;padding-left:8px}" +
  ".io-label{color:#666;font-weight:bold}" +
  ".span-io code{background:rgba(255,255,255,0.05);padding:1px 4px;border-radius:3px;font-size:11px}" +
  ".span-error{font-size:12px;color:#f87171;margin:4px 0;padding-left:8px}" +
  ".timeline-row{display:flex;align-items:center;margin-bottom:4px;height:24px}" +
  ".timeline-label{width:180px;font-size:11px;color:#aaa;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;padding-right:8px;font-family:monospace}" +
  ".timeline-track{flex:1;height:16px;background:rgba(255,255,255,0.05);border-radius:3px;position:relative}" +
  ".timeline-bar{position:absolute;height:100%;border-radius:3px;min-width:2px}" +
  ".timeline-bar.ok{background:#4ade80}" +
  ".timeline-bar.error{background:#f87171}" +
  ".timeline-bar.running{background:#facc15}" +
  ".timeline-bar.skipped{background:#666}" +
  ".empty{color:#666;font-style:italic;padding:16px;text-align:center}" +
  ".timeline-empty{color:#666;padding:16px;text-align:center}" +
  "table{width:100%;border-collapse:collapse;background:#16213e;border-radius:8px;overflow:hidden}" +
  "th{text-align:left;padding:12px 16px;background:#0f3460;color:#00d4ff;font-size:12px;text-transform:uppercase;letter-spacing:1px}" +
  "td{padding:10px 16px;border-bottom:1px solid rgba(255,255,255,0.05);font-size:13px}" +
  "tr:hover{background:rgba(255,255,255,0.03)}" +
  "code{background:rgba(255,255,255,0.05);padding:2px 6px;border-radius:3px;font-size:12px}" +
  ".badge{font-size:10px;padding:2px 8px;border-radius:3px;font-weight:bold;text-transform:uppercase}" +
  ".badge.ok{background:#1a4a1a;color:#4ade80}" +
  ".badge.error{background:#4a1a1a;color:#f87171}"
}

/// Build span tree HTML recursively
fn render_span_node(trace : @trace.Trace, span_id : String) -> String {
  let span = match trace.spans.get(span_id) {
    None => return ""
    Some(s) => s
  }
  let cls = status_class(span.status)
  let duration = match span.duration_ms { None => "?"; Some(d) => "\{d}" }
  let input_display = match span.input {
    None => ""
    Some(inp) => "<div class='span-io'><span class='io-label'>input:</span> <code>" + escape_html(inp) + "</code></div>"
  }
  let output_display = match span.output {
    None => ""
    Some(out) => "<div class='span-io'><span class='io-label'>output:</span> <code>" + escape_html(out) + "</code></div>"
  }
  let error_display = match span.error_message {
    None => ""
    Some(msg) => "<div class='span-error'>Error: " + escape_html(msg) + "</div>"
  }

  let children : Array[String] = []
  for s in trace.spans.values() {
    match s.parent_id {
      None => ()
      Some(pid) => if pid == span_id { children.push(s.id) }
    }
  }

  let mut children_html = ""
  if children.length() > 0 {
    children_html = "<div class='span-children' style='margin-left:24px;'>"
    for cid in children {
      children_html = children_html + render_span_node(trace, cid)
    }
    children_html = children_html + "</div>"
  }

  "<div class='span-node " + cls + "'>" +
    "<div class='span-header' onclick=\"this.parentElement.classList.toggle('collapsed')\">" +
      "<span class='span-toggle'>" + (if children.length() > 0 { "▼" } else { " " }) + "</span>" +
      "<span class='span-badge " + cls + "'>" + status_text(span.status) + "</span>" +
      "<span class='span-name'>" + escape_html(span.name) + "</span>" +
      "<span class='span-duration'>" + duration + "ms</span>" +
    "</div>" +
    "<div class='span-body'>" +
      input_display + output_display + error_display + children_html +
    "</div>" +
  "</div>"
}

/// Build timeline HTML
fn render_timeline(trace : @trace.Trace) -> String {
  let mut max_time = 0
  let trace_start = trace.start_time_ms
  for span in trace.spans.values() {
    match span.end_time_ms {
      None => ()
      Some(e) => if e > max_time { max_time = e }
    }
  }
  let total_width = max_time - trace_start
  if total_width <= 0 {
    return "<div class='timeline-empty'>No timeline data</div>"
  }

  let sorted_spans : Array[@trace.Span] = []
  for span in trace.spans.values() {
    sorted_spans.push(span)
  }
  sorted_spans.sort_by((a, b) => a.start_time_ms - b.start_time_ms)

  let mut html = "<div class='timeline'>"
  for span in sorted_spans {
    let offset = (span.start_time_ms - trace_start) * 100 / total_width
    let width = match span.duration_ms {
      None => 1
      Some(d) => if d <= 0 { 1 } else { d * 100 / total_width }
    }
    let cls = status_class(span.status)
    let duration = match span.duration_ms { None => "?"; Some(d) => "\{d}ms" }
    html = html +
      "<div class='timeline-row'>" +
        "<div class='timeline-label' title='" + escape_html(span.name) + "'>" + escape_html(span.name) + "</div>" +
        "<div class='timeline-track'>" +
          "<div class='timeline-bar " + cls + "' style='left:" + "\{offset}" + "%;width:" + "\{width}" + "%;' title='" + escape_html(span.name) + " (" + duration + ")'></div>" +
        "</div>" +
      "</div>"
  }
  html = html + "</div>"
  html
}

/// Export a trace to self-contained HTML
pub fn export_trace_html(trace : @trace.Trace) -> String {
  let mut total_spans = 0
  let mut error_count = 0
  let mut total_duration = 0
  for span in trace.spans.values() {
    total_spans = total_spans + 1
    match span.status {
      @trace.Error => error_count = error_count + 1
      _ => ()
    }
    match span.duration_ms {
      None => ()
      Some(d) => total_duration = total_duration + d
    }
  }

  let tree_html = match trace.root_span_id {
    None => "<div class='empty'>No root span</div>"
    Some(root_id) => render_span_node(trace, root_id)
  }

  let timeline_html = render_timeline(trace)

  "<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1.0'>" +
  "<title>MoonTrace - " + escape_html(trace.id) + "</title>" +
  "<style>" + css_styles() + "</style></head><body>" +
  "<h1>MoonTrace: " + escape_html(trace.id) + "</h1>" +
  "<div class='stats'>" +
    "<div class='stat-card'><div class='stat-value'>" + "\{total_spans}" + "</div><div class='stat-label'>Spans</div></div>" +
    "<div class='stat-card error'><div class='stat-value'>" + "\{error_count}" + "</div><div class='stat-label'>Errors</div></div>" +
    "<div class='stat-card'><div class='stat-value'>" + "\{total_duration}" + "ms</div><div class='stat-label'>Total Duration</div></div>" +
  "</div>" +
  "<div class='section'><div class='section-title'>Span Tree</div>" + tree_html + "</div>" +
  "<div class='section'><div class='section-title'>Timeline</div>" + timeline_html + "</div>" +
  "</body></html>"
}

/// Export trace list to HTML index page
pub fn export_index_html(summaries : Array[@storage.TraceSummary]) -> String {
  let mut rows = ""
  let mut i = 0
  for s in summaries {
    i = i + 1
    let name = match s.root_span_name { None => "?"; Some(n) => escape_html(n) }
    let status_cls = if s.has_error { "error" } else { "ok" }
    let status_txt = if s.has_error { "ERROR" } else { "OK" }
    rows = rows +
      "<tr>" +
        "<td>" + "\{i}" + "</td>" +
        "<td><code>" + escape_html(s.trace_id) + "</code></td>" +
        "<td>" + name + "</td>" +
        "<td>" + "\{s.span_count}" + "</td>" +
        "<td><span class='badge " + status_cls + "'>" + status_txt + "</span></td>" +
      "</tr>"
  }

  "<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'><title>MoonTrace - Trace Index</title>" +
  "<style>" + css_styles() + "</style></head><body>" +
  "<h1>MoonTrace - All Traces</h1>" +
  "<table><thead><tr><th>#</th><th>Trace ID</th><th>Root Span</th><th>Spans</th><th>Status</th></tr></thead>" +
  "<tbody>" + rows + "</tbody></table>" +
  "</body></html>"
}
