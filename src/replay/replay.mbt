// Deterministic replay of recorded span outputs and failures.

pub enum ReplayResult {
  Output(String)
  Error(String)
  Missing
}

struct ReplayEntry {
  input : Option[String]
  result : ReplayResult
}

pub struct ReplaySession {
  entries : Map[String, Array[ReplayEntry]]
  consumed : Map[String, Int]
}

fn span_sequence(id : String) -> Option[Int] {
  let parts = id.split("_").to_array()
  if parts.length() == 2 && parts[0] == "span" {
    try { Some(@string.parse_int(parts[1])) } catch { _ => None }
  } else {
    None
  }
}

fn ordered_spans(trace : @trace.Trace) -> Array[@trace.Span] {
  let spans : Array[@trace.Span] = []
  for span in trace.spans.values() {
    spans.push(span)
  }
  spans.sort_by((a, b) => {
    match (span_sequence(a.id), span_sequence(b.id)) {
      (Some(first), Some(second)) => first.compare(second)
      _ => {
        let time_order = a.start_time_ms.compare(b.start_time_ms)
        if time_order != 0 { time_order } else { a.id.compare(b.id) }
      }
    }
  })
  spans
}

pub fn ReplaySession::from_trace(trace : @trace.Trace) -> ReplaySession {
  let entries : Map[String, Array[ReplayEntry]] = Map([])
  for span in ordered_spans(trace) {
    let result = match span.status {
      @trace.Error => match span.error_message {
        None => Some(ReplayResult::Error("recorded span failed"))
        Some(message) => Some(ReplayResult::Error(message))
      }
      @trace.Ok => span.output.map(output => ReplayResult::Output(output))
      _ => None
    }
    match result {
      None => ()
      Some(value) => {
        let recorded = entries.get(span.name).unwrap_or([])
        recorded.push({ input: span.input, result: value })
        entries[span.name] = recorded
      }
    }
  }
  { entries, consumed: Map([]) }
}

pub fn ReplaySession::replay(self : ReplaySession, span_name : String) -> ReplayResult {
  let count = self.consumed.get(span_name).unwrap_or(0)
  match self.entries.get(span_name) {
    None => ReplayResult::Missing
    Some(recorded) => {
      if count >= recorded.length() {
        ReplayResult::Missing
      } else {
        self.consumed[span_name] = count + 1
        recorded[count].result
      }
    }
  }
}

/// Return the next recorded output for a tool call, preserving recorded failures.
/// A different input is an error and leaves the recording unconsumed.
pub fn ReplaySession::run(
  self : ReplaySession,
  span_name : String,
  input : Option[String],
) -> String raise Failure {
  let count = self.consumed.get(span_name).unwrap_or(0)
  match self.entries.get(span_name) {
    None => raise Failure("no recorded call for " + span_name)
    Some(recorded) => {
      if count >= recorded.length() {
        raise Failure("recorded calls exhausted for " + span_name)
      }
      if recorded[count].input != input {
        raise Failure("recorded input differs for " + span_name)
      }
      match self.replay(span_name) {
        ReplayResult::Output(output) => output
        ReplayResult::Error(message) => raise Failure(message)
        ReplayResult::Missing => raise Failure("recorded calls exhausted for " + span_name)
      }
    }
  }
}

pub fn ReplaySession::consumed_count(self : ReplaySession, span_name : String) -> Int {
  self.consumed.get(span_name).unwrap_or(0)
}

pub fn ReplaySession::remaining(self : ReplaySession) -> Int {
  let mut remaining = 0
  for name in self.entries.keys() {
    let used = self.consumed.get(name).unwrap_or(0)
    let total = self.entries[name].length()
    remaining = remaining + total - used
  }
  remaining
}
