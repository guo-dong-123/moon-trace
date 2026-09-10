// Span status enum
pub enum SpanStatus {
  Running
  Ok
  Error
  Skipped
} derive(ToJson, FromJson, @debug.Debug)

fn SpanStatus::to_string(self : SpanStatus) -> String {
  match self {
    Running => "running"
    Ok => "ok"
    Error => "error"
    Skipped => "skipped"
  }
}

// A discrete event inside a span
pub struct SpanEvent {
  timestamp_ms : Int
  name : String
  data : Option[String]
} derive(ToJson, FromJson, @debug.Debug)

// Core span data structure
pub struct Span {
  id : String
  parent_id : Option[String]
  trace_id : String
  name : String
  start_time_ms : Int
  mut end_time_ms : Option[Int]
  mut duration_ms : Option[Int]
  input : Option[String]
  mut output : Option[String]
  mut status : SpanStatus
  mut error_message : Option[String]
  metadata : Map[String, String]
  events : Array[SpanEvent]
} derive(ToJson, FromJson, @debug.Debug)

fn Span::new(
  id : String,
  parent_id : Option[String],
  trace_id : String,
  name : String,
  start_time_ms : Int,
  input : Option[String],
) -> Span {
  {
    id,
    parent_id,
    trace_id,
    name,
    start_time_ms,
    end_time_ms: None,
    duration_ms: None,
    input,
    output: None,
    status: Running,
    error_message: None,
    metadata: Map([]),
    events: [],
  }
}

fn Span::finish(self : Span, end_time_ms : Int, output : Option[String]) -> Unit {
  self.end_time_ms = Some(end_time_ms)
  self.duration_ms = Some(end_time_ms - self.start_time_ms)
  self.output = output
  self.status = Ok
}

fn Span::finish_with_error(self : Span, end_time_ms : Int, error_message : String) -> Unit {
  self.end_time_ms = Some(end_time_ms)
  self.duration_ms = Some(end_time_ms - self.start_time_ms)
  self.status = Error
  self.error_message = Some(error_message)
}

fn Span::add_event(self : Span, event : SpanEvent) -> Unit {
  self.events.push(event)
}

fn Span::set_metadata(self : Span, key : String, value : String) -> Unit {
  self.metadata[key] = value
}

// Trace: container for all spans in one execution
pub struct Trace {
  id : String
  mut root_span_id : Option[String]
  start_time_ms : Int
  mut end_time_ms : Option[Int]
  spans : Map[String, Span]
} derive(ToJson, FromJson, @debug.Debug)

fn Trace::new(id : String, start_time_ms : Int) -> Trace {
  {
    id,
    root_span_id: None,
    start_time_ms,
    end_time_ms: None,
    spans: Map([]),
  }
}

fn Trace::add_span(self : Trace, span : Span) -> Unit {
  if self.root_span_id == None {
    self.root_span_id = Some(span.id)
  }
  self.spans[span.id] = span
}

fn Trace::update_span(self : Trace, span : Span) -> Unit {
  self.spans[span.id] = span
}

fn Trace::get_span(self : Trace, id : String) -> Option[Span] {
  self.spans.get(id)
}

fn Trace::get_children(self : Trace, parent_id : String) -> Array[Span] {
  let result : Array[Span] = []
  for span in self.spans.values() {
    if span.parent_id == Some(parent_id) {
      result.push(span)
    }
  }
  result
}

fn Trace::finish(self : Trace, end_time_ms : Int) -> Unit {
  self.end_time_ms = Some(end_time_ms)
}
