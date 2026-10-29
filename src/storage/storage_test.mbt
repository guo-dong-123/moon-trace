// Tests for storage module

///|
fn make_test_trace(
  name : String,
  with_error : Bool,
) -> @trace.Trace raise Failure {
  ignore(@trace.start_trace())
  ignore(
    @trace.span(name, None, () => {
      ignore(@trace.span("sub_task", None, () => "sub"))
      if with_error {
        @trace.span("failing", None, () => raise Failure("test error")) catch {
          Failure(_) => ignore("recovered")
        }
      }
      "done"
    }),
  )
  match @trace.end_trace() {
    None => abort("no trace generated")
    Some(t) => t
  }
}

///|
test "memory_store_save_and_load" {
  let store = @storage.MemoryStore::new()
  let trace = make_test_trace("test_op", false)
  let tid = trace.id
  store.save(trace)
  let loaded = store.load(tid)
  assert_true(loaded is Some(_))
  match loaded {
    None => inspect("none", content="some")
    Some(t) => {
      inspect(t.id, content=tid)
      assert_true(t.spans.length() == 2)
    }
  }
}

///|
test "memory_store_list" {
  let store = @storage.MemoryStore::new()
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

///|
test "memory_store_delete" {
  let store = @storage.MemoryStore::new()
  let trace = make_test_trace("op_a", false)
  let tid = trace.id
  store.save(trace)
  assert_true(store.list().length() == 1)
  let deleted = store.delete(tid)
  assert_true(deleted)
  assert_true(store.list().length() == 0)
  assert_true(!store.delete("nonexistent"))
}

///|
test "query_filter_error_only" {
  let store = @storage.MemoryStore::new()
  store.save(make_test_trace("ok_op", false))
  let err_trace = make_test_trace("err_op", true)
  let err_id = err_trace.id
  store.save(err_trace)
  store.save(make_test_trace("ok_op2", false))
  let filter = @storage.TraceFilter::error_only()
  let results = @storage.query_summaries(store.list(), filter)
  assert_true(results.length() == 1)
  inspect(results[0].trace_id, content=err_id)
}

///|
test "query_filter_by_name" {
  let store = @storage.MemoryStore::new()
  store.save(make_test_trace("search_agent", false))
  store.save(make_test_trace("calc_agent", false))
  store.save(make_test_trace("search_v2", false))
  let filter = @storage.TraceFilter::with_name("search")
  let results = @storage.query_summaries(store.list(), filter)
  assert_true(results.length() == 2)
}

///|
test "trace_summary_has_correct_fields" {
  let store = @storage.MemoryStore::new()
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

///|
test "json_file_store_roundtrip" {
  let test_dir = "/tmp/moontrace_unit_test_002"
  // Clean up
  @fs.remove_dir(test_dir) catch {
    _ => ()
  }

  let store = @storage.JsonFileStore::new(test_dir)
  let trace = make_test_trace("file_op", false)
  let tid = trace.id
  assert_true(store.save(trace))

  let loaded = store.load(tid)
  assert_true(loaded is Some(_))
  match loaded {
    None => inspect("none", content="some")
    Some(t) => {
      inspect(t.id, content=tid)
      assert_true(t.spans.length() == 2)
    }
  }

  // Clean up
  @fs.remove_dir(test_dir) catch {
    _ => ()
  }
}

///|
test "json_file_store_reports_save_failure" {
  let blocked_path = "/tmp/moontrace_save_failure"
  @fs.remove_file(blocked_path) catch {
    _ => ()
  }
  @fs.write_string_to_file(blocked_path, "not a directory")
  let store = @storage.JsonFileStore::new(blocked_path)
  let trace = make_test_trace("blocked_save", false)
  assert_true(!store.save(trace))
  @fs.remove_file(blocked_path) catch {
    _ => ()
  }
}

///|
test "file store recovers stale or corrupt index and reports corrupt snapshots" {
  let trace = make_test_trace("recovery", false)
  let dir = "/tmp/moontrace-test-" + trace.id + "/nested/traces"
  let store = @storage.JsonFileStore::new(dir)
  assert_true(store.save(trace))
  @fs.write_string_to_file(dir + "/index.json", "{broken cache")
  assert_eq(store.list().length(), 1)
  @fs.write_string_to_file(dir + "/broken.json", "{broken trace")
  @fs.write_string_to_file(dir + "/ignored.json.tmp-abcd", "partial write")
  let report = store.repair()
  assert_true(report.index_rebuilt)
  assert_eq(report.trace_count, 1)
  assert_eq(report.issues.length(), 1)
  assert_true(@fs.path_exists(dir + "/broken.json"))
  assert_eq(store.list().length(), 1)
  assert_true(store.last_error() is Some(_))
  assert_true(store.load(trace.id) is Some(_))
  assert_true(store.last_error() is None)
  assert_true(store.delete(trace.id))
  assert_eq(store.list().length(), 0)
  @fs.remove_file(dir + "/broken.json")
  @fs.remove_file(dir + "/index.json")
  @fs.remove_file(dir + "/ignored.json.tmp-abcd")
  @fs.remove_dir(dir)
  @fs.remove_dir(dir[:dir.length() - 7].to_owned())
  @fs.remove_dir(dir[:dir.length() - 14].to_owned())
}

///|
test "file store refuses conflicting overwrite and unsafe IDs" {
  let trace = make_test_trace("immutable", false)
  let dir = "/tmp/moontrace-test-" + trace.id
  let store = @storage.JsonFileStore::new(dir)
  assert_true(store.save(trace))
  assert_true(store.save(trace)) // identical retry is idempotent
  let original = @fs.read_file_to_string(dir + "/" + trace.id + ".json")
  let conflicting : @trace.Trace = @json.from_json(
    @json.parse(original.replace(old="done", new="conflicting replacement")),
  )
  assert_true(!store.save(conflicting))
  assert_true(store.last_error().unwrap().contains("already exists"))
  assert_eq(@fs.read_file_to_string(dir + "/" + trace.id + ".json"), original)
  assert_true(store.load("../outside") is None)
  assert_true(!store.delete("../outside"))
  assert_true(store.load("index") is None)
  @fs.remove_file(dir + "/" + trace.id + ".json")
  @fs.remove_dir(dir)
}

///|
test "unchanged legacy snapshot can be saved idempotently" {
  let original = make_test_trace("legacy_snapshot", false)
  let dir = "/tmp/moontrace-legacy-" + original.id
  let store = @storage.JsonFileStore::new(dir)
  assert_true(store.save(original))
  let path = dir + "/" + original.id + ".json"
  // Older derived encoders omitted absent optional fields.
  let legacy = @fs.read_file_to_string(path)
    .replace_all(old="\"parent_id\":null,", new="")
    .replace_all(old="\"error_message\":null,", new="")
  @fs.write_string_to_file(path, legacy)
  assert_true(store.save(store.load(original.id).unwrap()))
  assert_eq(@fs.read_file_to_string(path), legacy)
  @fs.remove_file(path)
  @fs.remove_dir(dir)
}
