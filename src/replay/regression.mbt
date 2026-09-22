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

fn find_span(trace : @trace.Trace, name : String) -> Option[@trace.Span] {
  for span in trace.spans.values() {
    if span.name == name {
      return Some(span)
    }
  }
  None
}

pub fn compare_traces(baseline : @trace.Trace, candidate : @trace.Trace) -> RegressionReport {
  let issues : Array[RegressionIssue] = []
  let baseline_names : Map[String, Bool] = Map([])
  for span in baseline.spans.values() {
    baseline_names[span.name] = true
    match find_span(candidate, span.name) {
      None => issues.push(RegressionIssue::MissingSpan(span.name))
      Some(other) => {
        let before = span_status(span)
        let after = span_status(other)
        if before != after {
          issues.push(RegressionIssue::StatusChanged(span.name, before, after))
        }
      }
    }
  }
  for span in candidate.spans.values() {
    if !baseline_names.contains(span.name) {
      issues.push(RegressionIssue::AddedSpan(span.name))
    }
  }
  { issues, }
}
