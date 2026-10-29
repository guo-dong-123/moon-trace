// Two independent Agent requests, each with concurrent sibling tool calls.
///|
async fn record_agent(name : String, delay : Int) -> @trace.Trace {
  let session = @trace.TraceSession::new()
  ignore(
    @trace.span_async_in(session.context(), name, None, root => {
      root.set_metadata("request", name)
      let results = @async.all([
        () => {
          @trace.span_async_in(root, "tool.lookup", Some(name), ctx => {
            @async.sleep(delay)
            ctx.add_event("lookup_complete", Some(name))
            "lookup:" + name
          })
        },
        () => {
          @trace.span_async_in(root, "tool.calculate", None, ctx => {
            @async.sleep(2)
            ctx.set_metadata("owner", name)
            "42"
          })
        },
      ])
      results.join(" | ")
    }),
  )
  session.finish()
}

///|
async fn main {
  let store = match @env.get_env_var("MOONTRACE_DIR") {
    Some(dir) => @storage.JsonFileStore::new(dir)
    None => @storage.JsonFileStore::default()
  }
  let traces = @async.all([
    () => record_agent("agent.alpha", 15),
    () => record_agent("agent.beta", 5),
  ])
  for trace in traces {
    if !store.save(trace) {
      raise Failure(store.last_error().unwrap_or("save failed"))
    }
    println(
      "Saved \{trace.id}: \{trace.spans.length()} spans, elapsed \{trace.duration_ms().unwrap_or(0)}ms",
    )
  }
  println(
    "PASS: independent requests and sibling tools recorded with explicit contexts",
  )
}
