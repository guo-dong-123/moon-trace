/// A real two-turn tool-calling Agent backed by Alibaba Cloud Model Studio.

struct ToolCall {
  id : String
  name : String
  arguments : String
}

struct ChatTurn {
  text : String
  tool_calls : Array[ToolCall]
  total_tokens : Int
}

impl Show for ChatTurn with fn to_string(self : ChatTurn) -> String {
  "ChatTurn(text_length=\{self.text.length()}, tool_calls=\{self.tool_calls.length()}, total_tokens=\{self.total_tokens})"
}

fn get_store() -> @storage.JsonFileStore {
  match @env.get_env_var("MOONTRACE_DIR") {
    None => @storage.JsonFileStore::default()
    Some(dir) => @storage.JsonFileStore::new(dir)
  }
}

fn project_evidence() -> String {
  let evidence =
    #|{"project":"MoonTrace","language":"MoonBit","capabilities":["nested spans","duration and error capture","JSON persistence","terminal trace viewer","self-contained HTML export"],"tests":"offline test suite","constraint":"MVP uses process-local tracer state"}
  evidence
}

fn required_field(value : Json, key : String) -> Json raise Failure {
  guard value is Object(object) else {
    raise Failure("API response is not an object while reading: " + key)
  }
  match object.get(key) {
    Some(field) => field
    None => raise Failure("API response missing field: " + key)
  }
}

fn required_array(value : Json, label : String) -> Array[Json] raise Failure {
  match value {
    Array(items) => items
    _ => raise Failure("API response field is not an array: " + label)
  }
}

fn required_string(value : Json, label : String) -> String raise Failure {
  match value {
    String(text) => text
    _ => raise Failure("API response field is not a string: " + label)
  }
}

fn parse_chat_turn(payload : String) -> ChatTurn raise Failure {
  let root = try {
    @json.parse(payload)
  } catch {
    _ => raise Failure("Bailian returned invalid JSON")
  }
  let choices = required_array(required_field(root, "choices"), "choices")
  guard choices.get(0) is Some(choice) else {
    raise Failure("Bailian returned no choices")
  }
  let message = required_field(choice, "message")
  guard message is Object(message_object) else {
    raise Failure("API response message is not an object")
  }
  let text = match message_object.get("content") {
    Some(String(content)) => content
    None => ""
    _ => ""
  }
  let calls : Array[ToolCall] = []
  match message_object.get("tool_calls") {
    Some(raw_calls) => {
      for raw_call in required_array(raw_calls, "tool_calls") {
        let function = required_field(raw_call, "function")
        calls.push({
          id: required_string(required_field(raw_call, "id"), "tool_call.id"),
          name: required_string(
            required_field(function, "name"),
            "tool_call.function.name",
          ),
          arguments: required_string(
            required_field(function, "arguments"),
            "tool_call.function.arguments",
          ),
        })
      }
    }
    None => ()
  }
  let total_tokens = match root {
    Object(root_object) => match root_object.get("usage") {
      Some(Object(usage)) => match usage.get("total_tokens") {
        Some(Number(tokens, ..)) => tokens.to_int()
        _ => 0
      }
      _ => 0
    }
    _ => 0
  }
  { text, tool_calls: calls, total_tokens }
}

fn text_message(role : String, content : String) -> Json {
  Json::object({
    "role": Json::string(role),
    "content": Json::string(content),
  })
}

fn first_request(model : String, user_query : String) -> String {
  Json::object({
    "model": Json::string(model),
    "enable_thinking": Json::boolean(false),
    "messages": Json::array([
      text_message(
        "system",
        "You are a software demo review agent. Inspect project facts with the provided tool before answering. Answer in Chinese.",
      ),
      text_message("user", user_query),
    ]),
    "tools": Json::array([
      Json::object({
        "type": Json::string("function"),
        "function": Json::object({
          "name": Json::string("inspect_moontrace_mvp"),
          "description": Json::string(
            "Read verified implementation facts about the local MoonTrace MVP.",
          ),
          "parameters": Json::object({
            "type": Json::string("object"),
            "properties": Json::object({}),
            "required": Json::array([]),
          }),
        }),
      }),
    ]),
    "tool_choice": Json::object({
      "type": Json::string("function"),
      "function": Json::object({
        "name": Json::string("inspect_moontrace_mvp"),
      }),
    }),
    "max_tokens": Json::number(300),
  }).stringify()
}

fn final_request(
  model : String,
  user_query : String,
  calls : Array[ToolCall],
) -> String {
  let wire_calls : Array[Json] = []
  let messages : Array[Json] = [
    text_message(
      "system",
      "You are a software demo review agent. Use the verified tool result and answer concisely in Chinese.",
    ),
    text_message("user", user_query),
  ]
  for call in calls {
    wire_calls.push(Json::object({
      "id": Json::string(call.id),
      "type": Json::string("function"),
      "function": Json::object({
        "name": Json::string(call.name),
        "arguments": Json::string(call.arguments),
      }),
    }))
  }
  messages.push(Json::object({
    "role": Json::string("assistant"),
    "content": Json::string(""),
    "tool_calls": Json::array(wire_calls),
  }))
  for call in calls {
    messages.push(Json::object({
      "role": Json::string("tool"),
      "tool_call_id": Json::string(call.id),
      "content": Json::string(project_evidence()),
    }))
  }
  Json::object({
    "model": Json::string(model),
    "enable_thinking": Json::boolean(false),
    "messages": Json::array(messages),
    "max_tokens": Json::number(500),
  }).stringify()
}

async fn post_chat(
  api_key : String,
  endpoint : String,
  body : String,
) -> ChatTurn raise Failure {
  let config = "header = \"Authorization: Bearer " + api_key + "\"\n"
  let payload = try {
    @async.with_task_group() <| group => {
      let (child_stdin, writer) = @process.write_to_process()
      group.spawn_bg() <| () => {
        defer writer.close()
        writer.write(config)
      }
      let request = group.spawn() <| () => {
        @process.collect_output(
          "/usr/bin/curl",
          [
            "--silent",
            "--show-error",
            "--fail-with-body",
            "--max-time",
            "60",
            "--request",
            "POST",
            "--header",
            "Content-Type: application/json",
            "--data-binary",
            body,
            "--config",
            "-",
            endpoint,
          ],
          stdin=child_stdin,
        )
      }
      let (status, stdout, stderr) = request.wait()
      let response_text = stdout.text()
      if status != 0 {
        let detail = if response_text != "" { response_text } else { stderr.text() }
        raise Failure("Bailian request failed: " + detail)
      }
      response_text
    }
  } catch {
    Failure(message) => raise Failure(message)
    err => raise Failure("Failed to run curl: " + err.to_string())
  }
  parse_chat_turn(payload)
}

fn finish_trace() -> String? {
  match @trace.end_trace() {
    None => None
    Some(trace) => {
      ignore(get_store().save(trace))
      println("Trace saved: \{trace.id} (\{trace.spans.length()} spans)")
      Some(trace.id)
    }
  }
}

async fn run_agent_body(
  api_key : String,
  endpoint : String,
  model : String,
  user_query : String,
) -> String raise Failure {
  @trace.set_metadata("provider", "alibaba-bailian")
  @trace.set_metadata("model", model)
  let first = @trace.span_async(
    "llm.select_tool",
    Some("model=" + model),
    () => post_chat(api_key, endpoint, first_request(model, user_query)),
  )
  @trace.add_event(
    "tool_selection_received",
    Some("total_tokens=\{first.total_tokens}"),
  )
  guard first.tool_calls.length() > 0 else {
    raise Failure("model did not request the required project tool")
  }
  for call in first.tool_calls {
    guard call.name == "inspect_moontrace_mvp" else {
      raise Failure("model requested unsupported tool: " + call.name)
    }
    ignore(@trace.span(
      "tool.inspect_moontrace_mvp",
      Some(call.arguments),
      () => project_evidence(),
    ))
  }
  let final_turn = @trace.span_async(
    "llm.synthesize_review",
    Some("tool_results=\{first.tool_calls.length()}"),
    () => post_chat(
      api_key,
      endpoint,
      final_request(model, user_query, first.tool_calls),
    ),
  )
  @trace.add_event(
    "review_completed",
    Some("total_tokens=\{final_turn.total_tokens}"),
  )
  final_turn.text
}

async fn run_review_agent(
  api_key : String,
  endpoint : String,
  model : String,
  user_query : String,
) -> String raise Failure {
  ignore(@trace.start_trace())
  let result = try {
    @trace.span_async(
      "agent.moontrace_mvp_review",
      Some(user_query),
      () => run_agent_body(api_key, endpoint, model, user_query),
    )
  } catch {
    Failure(message) => {
      match finish_trace() {
        None => ()
        Some(trace_id) => println("Failure trace saved: " + trace_id)
      }
      raise Failure(message)
    }
  }
  ignore(finish_trace())
  result
}

async fn main {
  let api_key = @env.get_env_var("BAILIAN_API_KEY").unwrap_or("")
  guard api_key != "" else {
    println("error: set BAILIAN_API_KEY before running this example")
    return
  }
  let model = @env.get_env_var("TEXT_MODEL").unwrap_or("qwen3.7-plus")
  let base_url = @env.get_env_var("BAILIAN_BASE_URL").unwrap_or(
    "https://dashscope.aliyuncs.com/compatible-mode/v1",
  )
  let endpoint = if base_url.has_suffix("/") {
    base_url + "chat/completions"
  } else {
    base_url + "/chat/completions"
  }
  let query = @env.get_env_var("AGENT_QUERY").unwrap_or(
    "请评估 MoonTrace MVP 是否适合黑客松现场演示，并给出三项最值得展示的能力和一项当前限制。",
  )

  println("=== MoonTrace Real Agent Demo (Bailian) ===")
  println("Model: " + model)
  try {
    let answer = run_review_agent(api_key, endpoint, model, query)
    println("\nAgent answer:\n" + answer)
  } catch {
    Failure(message) => println("Agent failed after saving its trace: " + message)
  }
}

test "parse_chat_turn_extracts_tool_call_and_usage" {
  let payload =
    #|{"choices":[{"message":{"content":"","tool_calls":[{"id":"call_1","type":"function","function":{"name":"inspect_moontrace_mvp","arguments":"{}"}}]}}],"usage":{"total_tokens":42}}
  let turn = parse_chat_turn(payload)
  assert_eq(turn.tool_calls.length(), 1)
  assert_eq(turn.tool_calls[0].name, "inspect_moontrace_mvp")
  assert_eq(turn.total_tokens, 42)
}
