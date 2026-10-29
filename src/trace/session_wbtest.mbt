test "session rejects use after finish and finishing active work" {
  let session = TraceSession::new()
  let ctx = session.context()
  ignore(span_in(ctx, "root", None, _ => {
    let rejected = try { ignore(session.finish()); false } catch { _ => true }
    assert_true(rejected)
    "ok"
  }))
  let trace = session.finish()
  assert_true(trace.duration_ms() is Some(_))
  assert_true(try { ignore(span_in(ctx, "late", None, _ => "bad")); false } catch { _ => true })
  assert_true(trace.spans.length() == 1)
}

async test "parallel siblings and independent sessions retain their own parents" {
  let first = TraceSession::new()
  let second = TraceSession::new()
  let original_global = start_trace()
  ignore(@async.all([
    () => span_async_in(first.context(), "first", None, root => {
      ignore(@async.all([
        () => span_async_in(root, "slow", None, ctx => {
          ctx.set_metadata("owner", "slow")
          @async.sleep(12)
          ignore(span_in(ctx, "slow-child", None, _ => "one"))
          "slow"
        }),
        () => span_async_in(root, "fast", None, ctx => {
          @async.sleep(2)
          ctx.add_event("fast-event", None)
          ignore(span_in(ctx, "fast-child", None, _ => "two"))
          "fast"
        }),
      ]))
      "first"
    }),
    () => span_async_in(second.context(), "second", None, ctx => {
      @async.sleep(5)
      ignore(span_in(ctx, "second-child", None, _ => "three"))
      "second"
    }),
  ]))
  let a = first.finish()
  let b = second.finish()
  assert_true(a.id != b.id)
  assert_true(a.spans.length() == 5 && b.spans.length() == 2)
  for trace in [a, b] {
    for span in trace.spans.values() {
      assert_eq(span.trace_id, trace.id)
      if span.name.has_suffix("-child") {
        let parent = trace.spans[span.parent_id.unwrap()]
        assert_eq(span.name, parent.name + "-child")
      }
    }
  }
  assert_eq(end_trace().unwrap().id, original_global)
}

async test "cancelled spans finalize and do not contaminate the next task" {
  let session = TraceSession::new()
  let result = @async.with_timeout_opt(5, () => span_async_in(session.context(), "cancelled", None, _ => {
    @async.sleep(200)
    "unreachable"
  }))
  assert_true(result is None)
  ignore(span_in(session.context(), "after-cancel", None, _ => "ok"))
  let trace = session.finish()
  for span in trace.spans.values() {
    assert_true(span.parent_id is None)
    if span.name == "cancelled" {
      assert_true(span.status is Error)
      assert_true(span.error_message is Some(_))
      assert_true(span.duration_ms is Some(_))
    } else { assert_true(span.status is Ok) }
  }
}

test "elapsed differs from cumulative nested span time" {
  let trace = Trace::new("duration_fixture", 1000)
  let root = Span::new("root", None, trace.id, "root", 1000, None)
  root.finish(1100, None)
  let child = Span::new("child", Some(root.id), trace.id, "child", 1020, None)
  child.finish(1060, None)
  trace.add_span(root)
  trace.add_span(child)
  assert_true(trace.duration_ms() is None)
  trace.finish(1100)
  assert_eq(trace.duration_ms().unwrap(), 100)
  assert_eq(trace.cumulative_span_duration_ms(), 140)
}

test "trace IDs do not restart with tracer counter" {
  let first = Tracer::new()
  let second = Tracer::new()
  assert_eq(first.gen_id(), second.gen_id())
  let ids : Map[String, Bool] = Map([])
  for _ in 0..<1000 {
    let id = new_trace_id()
    assert_true(!ids.contains(id))
    assert_eq(id.length(), 38)
    ids[id] = true
  }
}

test "timestamps preserve Unix milliseconds beyond 32 bits" {
  let session = TraceSession::new()
  ignore(span_in(session.context(), "epoch", None, ctx => {
    ctx.add_event("epoch-event", None)
    "ok"
  }))
  let trace = session.finish()
  assert_true(trace.start_time_ms > 1700000000000L)
  assert_true(trace.end_time_ms.unwrap() >= trace.start_time_ms)
  let span = trace.spans[trace.root_span_id.unwrap()]
  assert_true(span.events[0].timestamp_ms >= trace.start_time_ms)
  let restored : Trace = @json.from_json(ToJson::to_json(trace))
  assert_eq(restored.start_time_ms, trace.start_time_ms)
}

test "legacy numeric JSON remains readable with unwrapped optional fields" {
  let legacy = @json.parse("{\"id\":\"legacy\",\"root_span_id\":\"root\",\"start_time_ms\":-123,\"end_time_ms\":100,\"spans\":{\"root\":{\"id\":\"root\",\"trace_id\":\"legacy\",\"name\":\"agent\",\"start_time_ms\":-123,\"end_time_ms\":100,\"duration_ms\":223,\"status\":\"Ok\",\"input\":\"query\",\"output\":\"answer\",\"metadata\":{},\"events\":[{\"timestamp_ms\":0,\"name\":\"event\",\"data\":\"payload\"}]}}}")
  let trace : Trace = @json.from_json(legacy)
  assert_eq(trace.start_time_ms, -123L)
  assert_eq(trace.root_span_id, Some("root"))
  assert_eq(trace.spans["root"].parent_id, None)
  assert_eq(trace.spans["root"].events[0].data, Some("payload"))
  let saved = ToJson::to_json(trace)
  assert_true(saved is Object(fields) && fields.get("start_time_ms") is Some(Number(_, ..)))
  assert_true(saved is Object(fields) && fields.get("root_span_id") is Some(String("root")))
  let broken = @json.parse("{\"id\":\"fractional\",\"start_time_ms\":1.5,\"spans\":{}}")
  assert_true(try { let _trace : Trace = @json.from_json(broken); false } catch { _ => true })
}
