// HTML exporter: generate self-contained interactive trace visualization

///|
fn escape_html(s : String) -> String {
  s
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&#39;")
}

///|
fn status_class(status : @trace.SpanStatus) -> String {
  match status {
    @trace.Ok => "ok"
    @trace.Error => "error"
    @trace.Running => "running"
    @trace.Skipped => "skipped"
  }
}

///|
fn status_text(status : @trace.SpanStatus) -> String {
  match status {
    @trace.Ok => "OK"
    @trace.Error => "ERROR"
    @trace.Running => "RUNNING"
    @trace.Skipped => "SKIPPED"
  }
}

///|
fn css_styles() -> String {
  "*{box-sizing:border-box;margin:0;padding:0}" +
  "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#1a1a2e;color:#e0e0e0;padding:24px}" +
  "h1{font-size:20px;margin-bottom:16px;color:#00d4ff;overflow-wrap:anywhere}" +
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
  ".span-name{flex:1;min-width:0;overflow-wrap:anywhere;font-family:'SF Mono',Monaco,monospace;font-size:13px}" +
  ".span-duration{font-size:12px;color:#888;font-family:monospace}" +
  ".span-body{padding-left:24px}" +
  ".span-node.collapsed>.span-body{display:none}" +
  ".filtering .span-node:not(.filtered)>.span-body{display:block}" +
  ".span-node.context-only>.span-header{opacity:.55}" +
  ".timeline-row.filtered,[hidden]{display:none!important}" +
  ".span-self{overflow-wrap:anywhere}" +
  ".span-header:focus-visible{outline:2px solid #00d4ff}" +
  ".span-node.collapsed>.span-header>.span-toggle{transform:rotate(-90deg);display:inline-block}" +
  ".span-io{font-size:12px;color:#aaa;margin:4px 0;padding-left:8px}" +
  ".io-label{color:#666;font-weight:bold}" +
  ".span-io code{background:rgba(255,255,255,0.05);padding:1px 4px;border-radius:3px;font-size:11px}" +
  ".span-error{font-size:12px;color:#f87171;margin:4px 0;padding-left:8px}" +
  ".span-metadata,.span-events{margin:6px 0 6px 8px;padding:6px 8px;border-left:2px solid rgba(0,212,255,.35);background:rgba(255,255,255,.025)}" +
  ".detail-title{font-size:10px;color:#00d4ff;text-transform:uppercase;letter-spacing:1px;margin-bottom:4px}" +
  ".detail-row{font-size:11px;color:#aaa;margin:3px 0;font-family:monospace;white-space:pre-wrap;overflow-wrap:anywhere}" +
  ".detail-key{color:#ddd;font-weight:bold}" +
  ".event-time{color:#888;margin-right:6px}" +
  ".trace-controls{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-bottom:12px}" +
  ".trace-controls input,.trace-controls select{background:#0f172a;color:#e0e0e0;border:1px solid #334155;border-radius:4px;padding:7px 9px;font:inherit}" +
  ".trace-controls input{flex:1;min-width:220px}" +
  ".filter-count{font-size:12px;color:#888}" +
  ".span-node.filtered{display:none}" +
  ".timeline-row{display:flex;align-items:center;margin-bottom:4px;height:24px}" +
  ".timeline-label{width:clamp(80px,25vw,180px);font-size:11px;color:#aaa;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;padding-right:8px;font-family:monospace}" +
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

///|
/// Build span tree HTML recursively
fn render_span_node(
  trace : @trace.Trace,
  span_id : String,
  visited : Map[String, Bool],
) -> String {
  if visited.contains(span_id) {
    return ""
  }
  visited[span_id] = true
  let span = match trace.spans.get(span_id) {
    None => return ""
    Some(s) => s
  }
  let cls = status_class(span.status)
  let duration = match span.duration_ms {
    None => "?"
    Some(d) => "\{d}"
  }
  let input_display = match span.input {
    None => ""
    Some(inp) =>
      "<div class='span-io'><span class='io-label'>input:</span> <code>" +
      escape_html(inp) +
      "</code></div>"
  }
  let output_display = match span.output {
    None => ""
    Some(out) =>
      "<div class='span-io'><span class='io-label'>output:</span> <code>" +
      escape_html(out) +
      "</code></div>"
  }
  let error_display = match span.error_message {
    None => ""
    Some(msg) => "<div class='span-error'>Error: " + escape_html(msg) + "</div>"
  }

  let mut metadata_display = ""
  let metadata_keys = span.metadata.keys().to_array()
  metadata_keys.sort()
  if metadata_keys.length() > 0 {
    metadata_display = "<div class='span-metadata'><div class='detail-title'>Metadata</div>"
    for key in metadata_keys {
      metadata_display = metadata_display +
        "<div class='detail-row'><span class='detail-key'>" +
        escape_html(key) +
        "</span>: " +
        escape_html(span.metadata.get(key).unwrap_or("")) +
        "</div>"
    }
    metadata_display = metadata_display + "</div>"
  }

  let mut events_display = ""
  if span.events.length() > 0 {
    events_display = "<div class='span-events'><div class='detail-title'>Events</div>"
    for event in span.events {
      let event_data = match event.data {
        None => ""
        Some(data) => ": " + escape_html(data)
      }
      let elapsed = event.timestamp_ms - span.start_time_ms
      events_display = events_display +
        "<div class='detail-row'><span class='event-time'>+" +
        "\{elapsed}" +
        "ms</span><span class='detail-key'>" +
        escape_html(event.name) +
        "</span>" +
        event_data +
        "</div>"
    }
    events_display = events_display + "</div>"
  }

  let children : Array[String] = []
  for s in trace.spans.values() {
    match s.parent_id {
      None => ()
      Some(pid) => if pid == span_id { children.push(s.id) }
    }
  }

  let mut children_html = ""
  children.sort_by((a, b) => {
    let sa = trace.spans[a]
    let sb = trace.spans[b]
    if sa.start_time_ms == sb.start_time_ms {
      a.compare(b)
    } else if sa.start_time_ms < sb.start_time_ms {
      -1
    } else {
      1
    }
  })
  if children.length() > 0 {
    children_html = "<div class='span-children' style='margin-left:24px;'>"
    for cid in children {
      children_html = children_html + render_span_node(trace, cid, visited)
    }
    children_html = children_html + "</div>"
  }

  "<div class='span-node " +
  cls +
  "' data-span-id='" +
  escape_html(span.id) +
  "' data-status='" +
  cls +
  "'>" +
  "<div class='span-header' role='button' tabindex='0' aria-expanded='true' onclick='toggleSpan(this)' onkeydown=\"if(event.key==='Enter'||event.key===' '){event.preventDefault();toggleSpan(this)}\">" +
  "<span class='span-toggle'>" +
  (if children.length() > 0 { "▼" } else { " " }) +
  "</span>" +
  "<span class='span-badge " +
  cls +
  "'>" +
  status_text(span.status) +
  "</span>" +
  "<span class='span-name'>" +
  escape_html(span.name) +
  "</span>" +
  "<span class='span-duration'>" +
  duration +
  "ms</span>" +
  "</div>" +
  "<div class='span-body'>" +
  "<div class='span-self'>" +
  input_display +
  output_display +
  error_display +
  metadata_display +
  events_display +
  "</div>" +
  children_html +
  "</div>" +
  "</div>"
}

///|
/// Build timeline HTML
fn render_timeline(trace : @trace.Trace) -> String {
  let mut max_time = trace.start_time_ms
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
  sorted_spans.sort_by((a, b) => a.start_time_ms.compare(b.start_time_ms))

  let mut html = "<div class='timeline'>"
  for span in sorted_spans {
    let offset = (span.start_time_ms - trace_start) * 100 / total_width
    let width : Int64 = match span.duration_ms {
      None => 1
      Some(d) => if d <= 0 { 1 } else { d * 100 / total_width }
    }
    let cls = status_class(span.status)
    let duration = match span.duration_ms {
      None => "?"
      Some(d) => "\{d}ms"
    }
    html = html +
      "<div class='timeline-row' data-span-id='" +
      escape_html(span.id) +
      "'>" +
      "<div class='timeline-label' title='" +
      escape_html(span.name) +
      "'>" +
      escape_html(span.name) +
      "</div>" +
      "<div class='timeline-track'>" +
      "<div class='timeline-bar " +
      cls +
      "' style='left:" +
      "\{offset}" +
      "%;width:" +
      "\{width}" +
      "%;' title='" +
      escape_html(span.name) +
      " (" +
      duration +
      ")'></div>" +
      "</div>" +
      "</div>"
  }
  html = html + "</div>"
  html
}

///|
/// Export a trace to self-contained HTML
pub fn export_trace_html(trace : @trace.Trace) -> String {
  let mut total_spans = 0
  let mut error_count = 0
  for span in trace.spans.values() {
    total_spans = total_spans + 1
    match span.status {
      @trace.Error => error_count = error_count + 1
      _ => ()
    }
  }

  let visited : Map[String, Bool] = Map([])
  let mut tree_html = ""
  let span_ids = trace.spans.keys().to_array()
  span_ids.sort()
  // All roots are shown, including parallel root spans and orphaned records.
  for id in span_ids {
    let span = trace.spans[id]
    if span.parent_id is None ||
      (span.parent_id is Some(parent) && !trace.spans.contains(parent)) {
      tree_html = tree_html + render_span_node(trace, id, visited)
    }
  }
  for id in span_ids {
    tree_html = tree_html + render_span_node(trace, id, visited)
  }
  if tree_html == "" {
    tree_html = "<div class='empty'>No spans recorded</div>"
  }
  let elapsed = match trace.duration_ms() {
    Some(ms) => "\{ms}ms"
    None => "running"
  }

  let timeline_html = render_timeline(trace)

  "<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1.0'>" +
  "<title>MoonTrace - " +
  escape_html(trace.id) +
  "</title>" +
  "<style>" +
  css_styles() +
  "</style></head><body>" +
  "<h1>MoonTrace: " +
  escape_html(trace.id) +
  "</h1>" +
  "<div class='trace-controls'><input id='trace-search' type='search' aria-label='Search spans' placeholder='Search spans, metadata, events...' oninput='filterTrace()' /><select id='trace-status' aria-label='Span status' onchange='filterTrace()'><option value='all'>All statuses</option><option value='ok'>OK</option><option value='error'>ERROR</option><option value='running'>RUNNING</option><option value='skipped'>SKIPPED</option></select><span id='filter-count' class='filter-count' role='status'></span></div>" +
  "<div class='stats'>" +
  "<div class='stat-card'><div class='stat-value'>" +
  "\{total_spans}" +
  "</div><div class='stat-label'>Spans</div></div>" +
  "<div class='stat-card error'><div class='stat-value'>" +
  "\{error_count}" +
  "</div><div class='stat-label'>Errors</div></div>" +
  "<div class='stat-card'><div class='stat-value'>" +
  elapsed +
  "</div><div class='stat-label'>Elapsed duration</div></div>" +
  "<div class='stat-card'><div class='stat-value'>" +
  "\{trace.cumulative_span_duration_ms()}" +
  "ms</div><div class='stat-label'>Cumulative span time</div></div>" +
  "</div>" +
  "<div class='section'><div class='section-title'>Span Tree</div><div id='no-matches' class='empty' hidden>No matching spans. Clear the search or change the status.</div>" +
  tree_html +
  "</div>" +
  "<div class='section'><div class='section-title'>Timeline</div>" +
  timeline_html +
  "</div>" +
  filter_script() +
  "</body></html>"
}

///|
fn filter_script() -> String {
  "<script>" +
  "function toggleSpan(header){const node=header.parentElement;node.classList.toggle('collapsed');header.setAttribute('aria-expanded',String(!node.classList.contains('collapsed')||document.body.classList.contains('filtering')))}" +
  "function filterTrace(){const q=document.getElementById('trace-search').value.trim().toLowerCase();const status=document.getElementById('trace-status').value;const active=!!q||status!=='all';document.body.classList.toggle('filtering',active);const nodes=[...document.querySelectorAll('.span-node')];const hits=new Set();const keep=new Set();nodes.forEach(n=>{const own=n.querySelector(':scope>.span-header').textContent+' '+n.querySelector(':scope>.span-body>.span-self').textContent;const hit=(!q||own.toLowerCase().includes(q))&&(status==='all'||n.dataset.status===status);if(hit){hits.add(n.dataset.spanId);for(let p=n;p;p=p.parentElement.closest('.span-node'))keep.add(p.dataset.spanId)}});nodes.forEach(n=>{n.classList.toggle('filtered',!keep.has(n.dataset.spanId));n.classList.toggle('context-only',keep.has(n.dataset.spanId)&&!hits.has(n.dataset.spanId));n.querySelector(':scope>.span-header').setAttribute('aria-expanded',String(active||!n.classList.contains('collapsed')))});document.querySelectorAll('.timeline-row').forEach(n=>n.classList.toggle('filtered',!hits.has(n.dataset.spanId)));document.getElementById('filter-count').textContent=hits.size+' / '+nodes.length+' matching spans';document.getElementById('no-matches').hidden=hits.size!==0;}filterTrace();</script>"
}

///|
/// Export trace list to HTML index page
pub fn export_index_html(summaries : Array[@storage.TraceSummary]) -> String {
  let mut rows = ""
  let mut i = 0
  for s in summaries {
    i = i + 1
    let name = match s.root_span_name {
      None => "?"
      Some(n) => escape_html(n)
    }
    let status_cls = if s.has_error { "error" } else { "ok" }
    let status_txt = if s.has_error { "ERROR" } else { "OK" }
    rows = rows +
      "<tr>" +
      "<td>" +
      "\{i}" +
      "</td>" +
      "<td><code>" +
      escape_html(s.trace_id) +
      "</code></td>" +
      "<td>" +
      name +
      "</td>" +
      "<td>" +
      "\{s.span_count}" +
      "</td>" +
      "<td><span class='badge " +
      status_cls +
      "'>" +
      status_txt +
      "</span></td>" +
      "</tr>"
  }

  "<!DOCTYPE html><html lang='en'><head><meta charset='UTF-8'><title>MoonTrace - Trace Index</title>" +
  "<style>" +
  css_styles() +
  "</style></head><body>" +
  "<h1>MoonTrace - All Traces</h1>" +
  "<table><thead><tr><th>#</th><th>Trace ID</th><th>Root Span</th><th>Spans</th><th>Status</th></tr></thead>" +
  "<tbody>" +
  rows +
  "</tbody></table>" +
  "</body></html>"
}
