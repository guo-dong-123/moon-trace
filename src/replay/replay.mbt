// Deterministic replay of recorded span outputs and failures.

pub enum ReplayResult {
  Output(String)
  Error(String)
  Missing
}

pub struct ReplaySession {
  entries : Map[String, ReplayResult]
  consumed : Map[String, Int]
}

pub fn ReplaySession::from_trace(trace : @trace.Trace) -> ReplaySession {
  let entries : Map[String, ReplayResult] = Map([])
  for span in trace.spans.values() {
    let result = match span.status {
      @trace.Error => match span.error_message {
        None => ReplayResult::Error("recorded span failed")
        Some(message) => ReplayResult::Error(message)
      }
      _ => match span.output {
        None => ReplayResult::Output("")
        Some(output) => ReplayResult::Output(output)
      }
    }
    entries[span.name] = result
  }
  { entries, consumed: Map([]) }
}

pub fn ReplaySession::replay(self : ReplaySession, span_name : String) -> ReplayResult {
  let count = self.consumed.get(span_name).unwrap_or(0)
  self.consumed[span_name] = count + 1
  match self.entries.get(span_name) {
    None => ReplayResult::Missing
    Some(result) => result
  }
}

pub fn ReplaySession::consumed_count(self : ReplaySession, span_name : String) -> Int {
  self.consumed.get(span_name).unwrap_or(0)
}

pub fn ReplaySession::remaining(self : ReplaySession) -> Int {
  let mut remaining = 0
  for name in self.entries.keys() {
    let used = self.consumed.get(name).unwrap_or(0)
    if used == 0 {
      remaining = remaining + 1
    }
  }
  remaining
}
