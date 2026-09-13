// Tests for trace core module

fn is_error_status(s : SpanStatus) -> Bool {
  match s {
    Error => true
    _ => false
  }
}

fn is_ok_status(s : SpanStatus) -> Bool {
  match s {
    Ok => true
    _ => false
  }
}

test "span_captures_input_output" {
  ignore(start_trace())
  let result = span("test_span", Some("input_data"), () => {
    "output_data"
  })
  inspect(result, content="output_data")
  match end_trace() {
    None => inspect("no trace", content="trace")
    Some(trace) => {
      assert_true(trace.spans.length() == 1)
      match trace.root_span_id {
        None => inspect("no root", content="root")
        Some(id) => {
          match trace.spans.get(id) {
            None => inspect("no span", content="span")
            Some(sp) => {
              inspect(sp.name, content="test_span")
              match sp.input {
                None => inspect("none", content="some")
                Some(v) => inspect(v, content="input_data")
              }
              match sp.output {
                None => inspect("none", content="some")
                Some(v) => inspect(v, content="output_data")
              }
            }
          }
        }
      }
    }
  }
}

test "nested_spans_form_tree" {
  ignore(start_trace())
  ignore(span("parent", None, () => {
    ignore(span("child_1", None, () => {
      "c1"
    }))
    ignore(span("child_2", None, () => {
      "c2"
    }))
    "parent_result"
  }))
  match end_trace() {
    None => inspect("no trace", content="trace")
    Some(trace) => {
      assert_true(trace.spans.length() == 3)
      let mut parent_found = false
      let mut child_count = 0
      for sp in trace.spans.values() {
        if sp.name == "parent" {
          parent_found = true
          assert_true(sp.parent_id.is_none())
        }
        if sp.name == "child_1" || sp.name == "child_2" {
          child_count = child_count + 1
          assert_true(sp.parent_id.is_some())
        }
      }
      assert_true(parent_found)
      assert_true(child_count == 2)
    }
  }
}

test "error_span_captures_error" {
  ignore(start_trace())
  try {
    span("failing_span", None, () => {
      raise Failure("something broke")
    })
  } catch {
    Failure(_) => ()
  }
  match end_trace() {
    None => inspect("no trace", content="trace")
    Some(trace) => {
      assert_true(trace.spans.length() == 1)
      match trace.root_span_id {
        None => inspect("no root", content="root")
        Some(id) => {
          match trace.spans.get(id) {
            None => inspect("no span", content="span")
            Some(sp) => {
              assert_true(is_error_status(sp.status))
              match sp.error_message {
                None => inspect("none", content="some")
                Some(v) => inspect(v, content="something broke")
              }
            }
          }
        }
      }
    }
  }
}

test "failed_span_does_not_corrupt_parent_stack" {
  ignore(start_trace())
  ignore(span("parent", None, () => {
    try {
      span("failing_child", None, () => {
        raise Failure("expected failure")
      })
    } catch {
      Failure(_) => ()
    }
    ignore(span("sibling", None, () => {
      "ok"
    }))
    "parent_result"
  }))
  match end_trace() {
    None => inspect("no trace", content="trace")
    Some(trace) => {
      match trace.root_span_id {
        None => inspect("no root", content="root")
        Some(root_id) => {
          let mut child_count = 0
          for child in trace.spans.values() {
            if child.parent_id == Some(root_id) {
              child_count = child_count + 1
            }
          }
          assert_true(child_count == 2)
        }
      }
    }
  }
}

test "add_event_and_metadata" {
  ignore(start_trace())
  ignore(span("span_with_events", None, () => {
    add_event("step_1", Some("started"))
    set_metadata("key", "value")
    add_event("step_2", None)
    "done"
  }))
  match end_trace() {
    None => inspect("no trace", content="trace")
    Some(trace) => {
      match trace.root_span_id {
        None => inspect("no root", content="root")
        Some(id) => {
          match trace.spans.get(id) {
            None => inspect("no span", content="span")
            Some(sp) => {
              assert_true(sp.events.length() == 2)
              inspect(sp.events[0].name, content="step_1")
              match sp.events[0].data {
                None => inspect("none", content="some")
                Some(v) => inspect(v, content="started")
              }
              inspect(sp.events[1].name, content="step_2")
              match sp.metadata.get("key") {
                None => inspect("none", content="some")
                Some(v) => inspect(v, content="value")
              }
            }
          }
        }
      }
    }
  }
}

test "trace_duration_recorded" {
  ignore(start_trace())
  ignore(span("timed_span", None, () => {
    "result"
  }))
  match end_trace() {
    None => inspect("no trace", content="trace")
    Some(trace) => {
      match trace.root_span_id {
        None => inspect("no root", content="root")
        Some(id) => {
          match trace.spans.get(id) {
            None => inspect("no span", content="span")
            Some(sp) => {
              assert_true(sp.duration_ms.is_some())
              assert_true(is_ok_status(sp.status))
            }
          }
        }
      }
    }
  }
}
