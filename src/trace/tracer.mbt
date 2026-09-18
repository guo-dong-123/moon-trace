// Global tracer state and span API

priv struct Tracer {
  mut current_trace : Option[Trace]
  mut span_stack : Array[String]
  mut span_clocks : Map[String, @bench.Timestamp]
  mut next_id : Int
}

fn Tracer::new() -> Tracer {
  {
    current_trace: None,
    span_stack: [],
    span_clocks: Map([]),
    next_id: 1,
  }
}

fn Tracer::gen_id(self : Tracer) -> String {
  let id = self.next_id
  self.next_id = self.next_id + 1
  "span_" + id.to_string()
}

fn Tracer::gen_trace_id(self : Tracer) -> String {
  let id = self.next_id
  self.next_id = self.next_id + 1
  "trace_" + id.to_string()
}

fn Tracer::current_span_id(self : Tracer) -> Option[String] {
  if self.span_stack.length() == 0 {
    None
  } else {
    Some(self.span_stack[self.span_stack.length() - 1])
  }
}

// Global singleton
let global_tracer : @ref.Ref[Tracer] = @ref.Ref(Tracer::new())

fn now_ms() -> Int {
  @env.now().to_int()
}

fn duration_end_ms(tracer : Tracer, span_id : String, start_time_ms : Int) -> Int {
  match tracer.span_clocks.get(span_id) {
    None => start_time_ms
    Some(clock) => {
      tracer.span_clocks.remove(span_id)
      let elapsed_ms = (@bench.monotonic_clock_end(clock) / 1000.0).to_int()
      start_time_ms + (if elapsed_ms < 0 { 0 } else { elapsed_ms })
    }
  }
}

/// Start a new trace. Must be called before any span.
pub fn start_trace() -> String {
  let tracer = global_tracer.val
  let trace_id = tracer.gen_trace_id()
  let trace = Trace::new(trace_id, now_ms())
  tracer.current_trace = Some(trace)
  tracer.span_stack = []
  tracer.span_clocks = Map([])
  trace_id
}

/// End the current trace and return it.
pub fn end_trace() -> Option[Trace] {
  let tracer = global_tracer.val
  match tracer.current_trace {
    None => None
    Some(trace) => {
      trace.finish(now_ms())
      let result = Some(trace)
      tracer.current_trace = None
      tracer.span_stack = []
      result
    }
  }
}

/// Get the current trace (for inspection/testing).
pub fn current_trace() -> Option[Trace] {
  global_tracer.val.current_trace
}

/// Execute a body within a named span, automatically recording input/output/duration/errors.
pub fn[T : Show] span(name : String, input : Option[String], body : () -> T raise Failure) -> T raise Failure {
  let tracer = global_tracer.val

  // Auto-start a trace if none exists
  match tracer.current_trace {
    None => ignore(start_trace())
    Some(_) => ()
  }

  let trace_id = match tracer.current_trace {
    Some(t) => t.id
    None => "unknown"
  }

  let parent_id = tracer.current_span_id()
  let span_id = tracer.gen_id()
  let start = now_ms()
  let span = Span::new(span_id, parent_id, trace_id, name, start, input)
  tracer.span_clocks[span_id] = @bench.monotonic_clock_start()

  // Register span in trace and push to stack
  match tracer.current_trace {
    Some(t) => t.add_span(span)
    None => ()
  }
  tracer.span_stack.push(span_id)

  // Execute body with error capture
  let result = try {
    let v = body()
    let end = duration_end_ms(tracer, span_id, start)
    span.finish(end, Some(v.to_string()))
    match tracer.current_trace {
      Some(t) => t.update_span(span)
      None => ()
    }
    v
  } catch {
    Failure(msg) => {
      let end = duration_end_ms(tracer, span_id, start)
      span.finish_with_error(end, msg)
      match tracer.current_trace {
        Some(t) => t.update_span(span)
        None => ()
      }
      ignore(tracer.span_stack.pop())
      raise Failure(msg)
    }
  }

  // Pop from stack
  ignore(tracer.span_stack.pop())

  result
}

/// Execute an async body within a named span.
///
/// This is the async counterpart of `span` for network-backed agent steps such
/// as LLM and tool API calls. The body should translate provider-specific
/// errors to `Failure` so they are recorded consistently.
pub async fn[T : Show] span_async(
  name : String,
  input : Option[String],
  body : async () -> T raise Failure,
) -> T raise Failure {
  let tracer = global_tracer.val

  match tracer.current_trace {
    None => ignore(start_trace())
    Some(_) => ()
  }

  let trace_id = match tracer.current_trace {
    Some(t) => t.id
    None => "unknown"
  }
  let parent_id = tracer.current_span_id()
  let span_id = tracer.gen_id()
  let start = now_ms()
  let span = Span::new(span_id, parent_id, trace_id, name, start, input)
  tracer.span_clocks[span_id] = @bench.monotonic_clock_start()

  match tracer.current_trace {
    Some(t) => t.add_span(span)
    None => ()
  }
  tracer.span_stack.push(span_id)

  let result = try {
    let value = body()
    let end = duration_end_ms(tracer, span_id, start)
    span.finish(end, Some(value.to_string()))
    match tracer.current_trace {
      Some(t) => t.update_span(span)
      None => ()
    }
    value
  } catch {
    Failure(msg) => {
      let end = duration_end_ms(tracer, span_id, start)
      span.finish_with_error(end, msg)
      match tracer.current_trace {
        Some(t) => t.update_span(span)
        None => ()
      }
      ignore(tracer.span_stack.pop())
      raise Failure(msg)
    }
  }

  ignore(tracer.span_stack.pop())
  result
}

/// Add an event to the current span.
pub fn add_event(name : String, data : Option[String]) -> Unit {
  let tracer = global_tracer.val
  let current_id = tracer.current_span_id()
  match current_id {
    None => ()
    Some(id) => {
      match tracer.current_trace {
        None => ()
        Some(t) => {
          match t.get_span(id) {
            None => ()
            Some(s) => {
              let event = { timestamp_ms: now_ms(), name, data }
              s.add_event(event)
              t.update_span(s)
            }
          }
        }
      }
    }
  }
}

/// Set metadata on the current span.
pub fn set_metadata(key : String, value : String) -> Unit {
  let tracer = global_tracer.val
  let current_id = tracer.current_span_id()
  match current_id {
    None => ()
    Some(id) => {
      match tracer.current_trace {
        None => ()
        Some(t) => {
          match t.get_span(id) {
            None => ()
            Some(s) => {
              s.set_metadata(key, value)
              t.update_span(s)
            }
          }
        }
      }
    }
  }
}

/// Print a human-readable trace tree to stdout (for testing/debugging).
pub fn print_trace(trace : Trace) -> Unit {
  println("=== Trace \{trace.id} ===")
  match trace.root_span_id {
    None => println("(empty trace)")
    Some(root_id) => print_span_tree(trace, root_id, 0)
  }
}

fn print_span_tree(trace : Trace, span_id : String, depth : Int) -> Unit {
  match trace.get_span(span_id) {
    None => ()
    Some(span) => {
      let indent = "  ".repeat(depth)
      let status_str = span.status.to_string()
      let duration_str = match span.duration_ms {
        None => "?"
        Some(d) => d.to_string() + "ms"
      }
      let input_str = match span.input {
        None => ""
        Some(i) => " input=" + i
      }
      let output_str = match span.output {
        None => ""
        Some(o) => " output=" + o
      }
      let error_str = match span.error_message {
        None => ""
        Some(e) => " error=" + e
      }
      println("\{indent}[\{status_str}] \{span.name} (\{duration_str})\{input_str}\{output_str}\{error_str}")
      let children = trace.get_children(span_id)
      for child in children {
        print_span_tree(trace, child.id, depth + 1)
      }
    }
  }
}
