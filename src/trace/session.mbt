///|
/// An isolated trace recording session. Pass its immutable context to concurrent
/// tasks; each span callback receives its own child context. No global stack is
/// read or changed by this API.
pub struct TraceSession {
  priv trace : Trace
  priv clock : @bench.Timestamp
  priv counter : @ref.Ref[Int]
}

///|
pub struct TraceContext {
  priv session : TraceSession
  parent_id : String?
}

///|
pub fn TraceSession::new() -> TraceSession {
  {
    trace: Trace::new(new_trace_id(), now_ms()),
    clock: @bench.monotonic_clock_start(),
    counter: @ref.Ref(0),
  }
}

///|
pub fn TraceSession::context(self : TraceSession) -> TraceContext {
  { session: self, parent_id: None, }
}

///|
/// Finish after all tasks using this session have joined. Finishing with active
/// spans fails explicitly rather than producing a misleading completed trace.
pub fn TraceSession::finish(self : TraceSession) -> Trace raise Failure {
  for span in self.trace.spans.values() {
    if span.status is Running {
      raise Failure("MoonTrace: cannot finish a session with active spans")
    }
  }
  if self.trace.end_time_ms is None {
    let elapsed = (@bench.monotonic_clock_end(self.clock) / 1000.0)
      .to_int64()
      .max(0)
    self.trace.finish(self.trace.start_time_ms + elapsed)
  }
  self.trace
}

///|
fn TraceContext::begin(
  self : TraceContext,
  name : String,
  input : String?,
) -> (Span, TraceContext) raise Failure {
  if self.session.trace.end_time_ms is Some(_) {
    raise Failure("MoonTrace: session already finished")
  }
  self.session.counter.val = self.session.counter.val + 1
  let id = "span_" + self.session.counter.val.to_string()
  let span = Span::new(
    id,
    self.parent_id,
    self.session.trace.id,
    name,
    now_ms(),
    input,
  )
  self.session.trace.add_span(span)
  (span, { session: self.session, parent_id: Some(id), })
}

///|
pub fn TraceContext::set_metadata(
  self : TraceContext,
  key : String,
  value : String,
) -> Unit {
  let current = match self.parent_id {
    Some(id) => self.session.trace.get_span(id)
    None => None
  }
  match current {
    Some(span) => span.set_metadata(key, value)
    None => ()
  }
}

///|
pub fn TraceContext::add_event(
  self : TraceContext,
  name : String,
  data : String?,
) -> Unit {
  let current = match self.parent_id {
    Some(id) => self.session.trace.get_span(id)
    None => None
  }
  match current {
    Some(span) => span.add_event({ timestamp_ms: now_ms(), name, data, })
    None => ()
  }
}

///|
fn annotate_span_error(span : Span, error : Error) -> Error {
  span.error_message = Some(error.to_string())
  error
}

///|
pub fn[T : Show] span_in(
  ctx : TraceContext,
  name : String,
  input : String?,
  body : (TraceContext) -> T raise,
) -> T raise {
  let (span, child) = ctx.begin(name, input)
  let clock = @bench.monotonic_clock_start()
  errdefer {
    let elapsed = (@bench.monotonic_clock_end(clock) / 1000.0).to_int64().max(0)
    span.finish_with_error(
      span.start_time_ms + elapsed,
      span.error_message.unwrap_or("execution cancelled or interrupted"),
    )
  }
  try {
    let value = body(child)
    let elapsed = (@bench.monotonic_clock_end(clock) / 1000.0).to_int64().max(0)
    span.finish(span.start_time_ms + elapsed, Some(value.to_string()))
    value
  } catch {
    error => raise annotate_span_error(span, error)
  }
}

///|
/// Captures all raised errors (including async cancellation) and rethrows them.
pub async fn[T : Show] span_async_in(
  ctx : TraceContext,
  name : String,
  input : String?,
  body : async (TraceContext) -> T,
) -> T {
  let (span, child) = ctx.begin(name, input)
  let clock = @bench.monotonic_clock_start()
  errdefer {
    let elapsed = (@bench.monotonic_clock_end(clock) / 1000.0).to_int64().max(0)
    span.finish_with_error(
      span.start_time_ms + elapsed,
      span.error_message.unwrap_or("execution cancelled or interrupted"),
    )
  }
  try {
    let value = body(child)
    let elapsed = (@bench.monotonic_clock_end(clock) / 1000.0).to_int64().max(0)
    span.finish(span.start_time_ms + elapsed, Some(value.to_string()))
    value
  } catch {
    error => raise annotate_span_error(span, error)
  }
}
