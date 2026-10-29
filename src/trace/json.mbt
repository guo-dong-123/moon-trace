// Keep JSON timestamps as numbers for compatibility with 0.1.x and JavaScript.
// Unix milliseconds fit exactly inside JSON's safe integer range. Extremely
// large Int64 values use strings so interchange never silently rounds them.
///|
fn ms_json(value : Int64) -> Json {
  if value < -9007199254740991L || value > 9007199254740991L {
    value.to_json()
  } else {
    value.to_double().to_json()
  }
}

///|
fn optional_ms_json(value : Int64?) -> Json {
  match value {
    Some(ms) => ms_json(ms)
    None => Json::null()
  }
}

///|
fn field_value(
  json : Json,
  key : String,
  path : @json.JsonPath,
) -> Json raise @json.JsonDecodeError {
  match json {
    Object(fields) => fields.get(key).unwrap_or(Json::null())
    _ => raise @json.JsonDecodeError((path, "Expected an object"))
  }
}

///|
fn[T : @json.FromJson] field(
  json : Json,
  key : String,
  path : @json.JsonPath,
) -> T raise @json.JsonDecodeError {
  @json.from_json(field_value(json, key, path), path=path.add_key(key))
}

///|
fn[T : ToJson] optional_json(value : T?) -> Json {
  match value {
    Some(value) => value.to_json()
    None => Json::null()
  }
}

///|
fn[T : @json.FromJson] optional_field(
  json : Json,
  key : String,
  path : @json.JsonPath,
) -> T? raise @json.JsonDecodeError {
  match field_value(json, key, path) {
    Null => None
    value => Some(@json.from_json(value, path=path.add_key(key)))
  }
}

///|
fn read_ms(
  value : Json,
  path : @json.JsonPath,
) -> Int64 raise @json.JsonDecodeError {
  match value {
    Number(n, ..) if n >= -9007199254740991.0 &&
      n <= 9007199254740991.0 &&
      n.to_int64().to_double() == n => n.to_int64()
    // Accept explicit Int64 strings as well as legacy numeric timestamps.
    String(_) => @json.from_json(value, path~)
    _ =>
      raise @json.JsonDecodeError(
        (
          path, "Expected integral milliseconds within the JSON safe integer range",
        ),
      )
  }
}

///|
fn ms_field(
  json : Json,
  key : String,
  path : @json.JsonPath,
) -> Int64 raise @json.JsonDecodeError {
  read_ms(field_value(json, key, path), path.add_key(key))
}

///|
fn optional_ms_field(
  json : Json,
  key : String,
  path : @json.JsonPath,
) -> Int64? raise @json.JsonDecodeError {
  match field_value(json, key, path) {
    Null => None
    value => Some(read_ms(value, path.add_key(key)))
  }
}

///|
pub impl ToJson for SpanEvent with fn to_json(self) {
  {
    "timestamp_ms": ms_json(self.timestamp_ms),
    "name": self.name.to_json(),
    "data": optional_json(self.data),
  }
}

///|
pub impl @json.FromJson for SpanEvent with fn from_json(json, path) {
  {
    timestamp_ms: ms_field(json, "timestamp_ms", path),
    name: field(json, "name", path),
    data: optional_field(json, "data", path),
  }
}

///|
pub impl ToJson for Span with fn to_json(self) {
  {
    "id": self.id.to_json(),
    "parent_id": optional_json(self.parent_id),
    "trace_id": self.trace_id.to_json(),
    "name": self.name.to_json(),
    "start_time_ms": ms_json(self.start_time_ms),
    "end_time_ms": optional_ms_json(self.end_time_ms),
    "duration_ms": optional_ms_json(self.duration_ms),
    "input": optional_json(self.input),
    "output": optional_json(self.output),
    "status": ToJson::to_json(self.status),
    "error_message": optional_json(self.error_message),
    "metadata": self.metadata.to_json(),
    "events": self.events.to_json(),
  }
}

///|
pub impl @json.FromJson for Span with fn from_json(json, path) {
  {
    id: field(json, "id", path),
    parent_id: optional_field(json, "parent_id", path),
    trace_id: field(json, "trace_id", path),
    name: field(json, "name", path),
    start_time_ms: ms_field(json, "start_time_ms", path),
    end_time_ms: optional_ms_field(json, "end_time_ms", path),
    duration_ms: optional_ms_field(json, "duration_ms", path),
    input: optional_field(json, "input", path),
    output: optional_field(json, "output", path),
    status: field(json, "status", path),
    error_message: optional_field(json, "error_message", path),
    metadata: field(json, "metadata", path),
    events: field(json, "events", path),
  }
}

///|
pub impl ToJson for Trace with fn to_json(self) {
  {
    "id": self.id.to_json(),
    "root_span_id": optional_json(self.root_span_id),
    "start_time_ms": ms_json(self.start_time_ms),
    "end_time_ms": optional_ms_json(self.end_time_ms),
    "spans": self.spans.to_json(),
  }
}

///|
pub impl @json.FromJson for Trace with fn from_json(json, path) {
  {
    id: field(json, "id", path),
    root_span_id: optional_field(json, "root_span_id", path),
    start_time_ms: ms_field(json, "start_time_ms", path),
    end_time_ms: optional_ms_field(json, "end_time_ms", path),
    spans: field(json, "spans", path),
  }
}
