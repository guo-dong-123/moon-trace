// Async context propagation support

/// A snapshot of the current tracing context, for passing across async boundaries.
pub struct SpanContext {
  trace_id : String
  span_id : Option[String]
}

/// Capture the current tracing context. Call before spawning an async task.
pub fn capture_context() -> Option[SpanContext] {
  let tracer = global_tracer.val
  match tracer.current_trace {
    None => None
    Some(trace) => Some({
      trace_id: trace.id,
      span_id: tracer.current_span_id(),
    })
  }
}

/// Restore a captured context, execute body, then restore original context.
pub fn[T] with_context(ctx : SpanContext, body : () -> T) -> T {
  let tracer = global_tracer.val
  // Save original state
  let original_trace = tracer.current_trace
  let original_stack = tracer.span_stack

  // Restore captured context (if trace still exists)
  match tracer.current_trace {
    Some(t) => {
      if t.id == ctx.trace_id {
        match ctx.span_id {
          Some(id) => {
            tracer.span_stack = []
            tracer.span_stack.push(id)
          }
          None => tracer.span_stack = []
        }
      }
    }
    None => ()
  }

  let result = body()

  // Restore original state
  tracer.current_trace = original_trace
  tracer.span_stack = original_stack

  result
}
