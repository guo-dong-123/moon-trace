// Compare two recorded executions as a regression gate.

pub enum RegressionIssue {
  MissingSpan(String)
  AddedSpan(String)
  StatusChanged(String, String, String)
  RootOutputChanged(String)
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
  compare_traces_with_options(baseline, candidate, false)
}

/// Optionally compare the final output of matching root spans as well as structure.
pub fn compare_traces_with_options(
  baseline : @trace.Trace,
  candidate : @trace.Trace,
  check_root_output : Bool,
) -> RegressionReport {
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
  if check_root_output {
    match (baseline.root_span_id, candidate.root_span_id) {
      (Some(first_id), Some(second_id)) => {
        match (baseline.spans.get(first_id), candidate.spans.get(second_id)) {
          (Some(first), Some(second)) => {
            if first.name == second.name && span_status(first) == "ok" &&
              span_status(second) == "ok" && first.output != second.output {
              issues.push(RegressionIssue::RootOutputChanged(first.name))
            }
          }
          _ => ()
        }
      }
      _ => ()
    }
  }
  { issues, }
}
