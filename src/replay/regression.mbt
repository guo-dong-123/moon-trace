// Compare two recorded executions as a regression gate.

pub enum RegressionIssue {
  MissingSpan(String)
  AddedSpan(String)
  StatusChanged(String, String, String)
}

pub struct RegressionReport {
  issues : Array[RegressionIssue]
}

pub fn RegressionReport::passed(self : RegressionReport) -> Bool {
  self.issues.length() == 0
}

pub fn RegressionReport::issue_count(self : RegressionReport) -> Int {
  self.issues.length()
}

fn span_status(span : @trace.Span) -> String {
  match span.status {
    @trace.Running => "running"
    @trace.Ok => "ok"
    @trace.Error => "error"
    @trace.Skipped => "skipped"
  }
}

pub fn compare_traces(baseline : @trace.Trace, candidate : @trace.Trace) -> RegressionReport {
  let issues : Array[RegressionIssue] = []
  let matched : Map[String, Bool] = Map([])
  let unmatched : Array[@trace.Span] = []

  // Match exact name/status pairs first so repeated tool calls retain their counts.
  for span in baseline.spans.values() {
    let mut found = false
    for other in candidate.spans.values() {
      if !found && !matched.contains(other.id) && span.name == other.name &&
        span_status(span) == span_status(other) {
        matched[other.id] = true
        found = true
      }
    }
    if !found {
      unmatched.push(span)
    }
  }

  for span in unmatched {
    let mut found = false
    for other in candidate.spans.values() {
      if !found && !matched.contains(other.id) && span.name == other.name {
        issues.push(RegressionIssue::StatusChanged(
          span.name, span_status(span), span_status(other),
        ))
        matched[other.id] = true
        found = true
      }
    }
    if !found {
      issues.push(RegressionIssue::MissingSpan(span.name))
    }
  }

  for span in candidate.spans.values() {
    if !matched.contains(span.id) {
      issues.push(RegressionIssue::AddedSpan(span.name))
    }
  }
  { issues, }
}
