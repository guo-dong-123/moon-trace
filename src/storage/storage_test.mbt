// Tests for storage module

fn make_test_trace(name : String, with_error : Bool) -> @trace.Trace raise Failure {
  ignore(@trace.start_trace())
  ignore(@trace.span(name, None, () => {
    ignore(@trace.span("sub_task", None, () => {
      "sub"
    }))
    if with_error {
      try {
        @trace.span("failing", None, () => {
          raise Failure("test error")
        })
      } catch {
        Failure(_) => ignore("recovered")
      }
    }
    "done"
  }))
  match @trace.end_trace() {
    None => abort("no trace generated")
    Some(t) => t
  }
}

test "memory_store_save_and_load" {
  let store = MemoryStore::new()
  let trace = make_test_trace("test_op", false)
  let tid = trace.id
  store.save(trace)
  let loaded = store.load(tid)
  assert_true(loaded.is_some())
  match loaded {
    None => inspect("none", content="some")
    Some(t) => {
      inspect(t.id, content=tid)
      assert_true(t.spans.length() == 2)
    }
  }
}

test "memory_store_list" {
  let store = MemoryStore::new()
  store.save(make_test_trace("op_a", false))
  store.save(make_test_trace("op_b", true))
  let list = store.list()
  assert_true(list.length() == 2)
  let mut error_count = 0
  for s in list {
    if s.has_error {
      error_count = error_count + 1
    }
  }
  assert_true(error_count == 1)
}

test "memory_store_delete" {
  let store = MemoryStore::new()
  let trace = make_test_trace("op_a", false)
  let tid = trace.id
  store.save(trace)
  assert_true(store.list().length() == 1)
  let deleted = store.delete(tid)
  assert_true(deleted)
  assert_true(store.list().length() == 0)
  assert_true(!store.delete("nonexistent"))
}

test "query_filter_error_only" {
  let store = MemoryStore::new()
  store.save(make_test_trace("ok_op", false))
  let err_trace = make_test_trace("err_op", true)
  let err_id = err_trace.id
  store.save(err_trace)
  store.save(make_test_trace("ok_op2", false))
  let filter = TraceFilter::error_only()
  let results = query_summaries(store.list(), filter)
  assert_true(results.length() == 1)
  inspect(results[0].trace_id, content=err_id)
}

test "query_filter_by_name" {
  let store = MemoryStore::new()
  store.save(make_test_trace("search_agent", false))
  store.save(make_test_trace("calc_agent", false))
  store.save(make_test_trace("search_v2", false))
  let filter = TraceFilter::with_name("search")
  let results = query_summaries(store.list(), filter)
  assert_true(results.length() == 2)
}

test "trace_summary_has_correct_fields" {
  let store = MemoryStore::new()
  let trace = make_test_trace("my_op", false)
  let tid = trace.id
  store.save(trace)
  let list = store.list()
  assert_true(list.length() == 1)
  let summary = list[0]
  inspect(summary.trace_id, content=tid)
  match summary.root_span_name {
    None => inspect("none", content="some")
    Some(v) => inspect(v, content="my_op")
  }
  assert_true(summary.span_count == 2)
  assert_true(!summary.has_error)
}

test "json_file_store_roundtrip" {
  let test_dir = "/tmp/moontrace_unit_test_002"
  // Clean up
  try { @fs.remove_dir(test_dir) } catch { _ => () }

  let store = JsonFileStore::new(test_dir)
  let trace = make_test_trace("file_op", false)
  let tid = trace.id
  assert_true(store.save(trace))

  let loaded = store.load(tid)
  assert_true(loaded.is_some())
  match loaded {
    None => inspect("none", content="some")
    Some(t) => {
      inspect(t.id, content=tid)
      assert_true(t.spans.length() == 2)
    }
  }

  // Clean up
  try { @fs.remove_dir(test_dir) } catch { _ => () }
}

test "json_file_store_reports_save_failure" {
  let blocked_path = "/tmp/moontrace_save_failure"
  try { @fs.remove_file(blocked_path) } catch { _ => () }
  @fs.write_string_to_file(blocked_path, "not a directory")
  let store = JsonFileStore::new(blocked_path)
  let trace = make_test_trace("blocked_save", false)
  assert_true(!store.save(trace))
  try { @fs.remove_file(blocked_path) } catch { _ => () }
}
