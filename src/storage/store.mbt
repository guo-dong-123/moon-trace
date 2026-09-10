// Storage: in-memory implementation and shared types

/// Summary of a trace for listing
pub struct TraceSummary {
  trace_id : String
  root_span_name : Option[String]
  start_time_ms : Int
  end_time_ms : Option[Int]
  span_count : Int
  has_error : Bool
} derive(ToJson, FromJson, @debug.Debug)

/// Filter for querying traces
pub struct TraceFilter {
  name_contains : Option[String]
  has_error_only : Bool
  min_start_time : Option[Int]
  max_start_time : Option[Int]
} derive(ToJson, FromJson, @debug.Debug)

pub fn TraceFilter::new() -> TraceFilter {
  {
    name_contains: None,
    has_error_only: false,
    min_start_time: None,
    max_start_time: None,
  }
}

pub fn TraceFilter::error_only() -> TraceFilter {
  {
    name_contains: None,
    has_error_only: true,
    min_start_time: None,
    max_start_time: None,
  }
}

pub fn TraceFilter::with_name(name : String) -> TraceFilter {
  {
    name_contains: Some(name),
    has_error_only: false,
    min_start_time: None,
    max_start_time: None,
  }
}

fn @trace.Trace::to_summary(self : @trace.Trace) -> TraceSummary {
  let root_name = match self.root_span_id {
    None => None
    Some(id) => match self.spans.get(id) {
      None => None
      Some(s) => Some(s.name)
    }
  }
  let mut has_error = false
  let mut span_count = 0
  for span in self.spans.values() {
    span_count = span_count + 1
    match span.status {
      @trace.Error => has_error = true
      _ => ()
    }
  }
  {
    trace_id: self.id,
    root_span_name: root_name,
    start_time_ms: self.start_time_ms,
    end_time_ms: self.end_time_ms,
    span_count: span_count,
    has_error: has_error,
  }
}

/// In-memory storage
pub struct MemoryStore {
  traces : Map[String, @trace.Trace]
}

pub fn MemoryStore::new() -> MemoryStore {
  { traces: Map([]) }
}

pub fn MemoryStore::save(self : MemoryStore, trace : @trace.Trace) -> Unit {
  self.traces[trace.id] = trace
}

pub fn MemoryStore::load(self : MemoryStore, trace_id : String) -> Option[@trace.Trace] {
  self.traces.get(trace_id)
}

pub fn MemoryStore::list(self : MemoryStore) -> Array[TraceSummary] {
  let result : Array[TraceSummary] = []
  for trace in self.traces.values() {
    result.push(trace.to_summary())
  }
  result.sort_by((a, b) => b.start_time_ms - a.start_time_ms)
  result
}

pub fn MemoryStore::delete(self : MemoryStore, trace_id : String) -> Bool {
  match self.traces.get(trace_id) {
    None => false
    Some(_) => {
      self.traces.remove(trace_id)
      true
    }
  }
}

/// Query a list of trace summaries with a filter
pub fn query_summaries(summaries : Array[TraceSummary], filter : TraceFilter) -> Array[TraceSummary] {
  let result : Array[TraceSummary] = []
  for summary in summaries {
    let mut keep = true
    match filter.name_contains {
      None => ()
      Some(name) => {
        match summary.root_span_name {
          None => keep = false
          Some(span_name) => {
            if !span_name.contains(name) {
              keep = false
            }
          }
        }
      }
    }
    if filter.has_error_only && !summary.has_error {
      keep = false
    }
    match filter.min_start_time {
      None => ()
      Some(min_t) => if summary.start_time_ms < min_t { keep = false }
    }
    match filter.max_start_time {
      None => ()
      Some(max_t) => if summary.start_time_ms > max_t { keep = false }
    }
    if keep {
      result.push(summary)
    }
  }
  result
}
