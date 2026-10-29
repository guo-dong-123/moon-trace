// Numeric timestamp fields stay compatible with existing JSON consumers.
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
    String(_) => @json.from_json(value, path~)
    _ => raise @json.JsonDecodeError((path, "Expected integral milliseconds"))
  }
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
pub impl ToJson for TraceSummary with fn to_json(self) {
  {
    "trace_id": self.trace_id.to_json(),
    "root_span_name": optional_json(self.root_span_name),
    "start_time_ms": ms_json(self.start_time_ms),
    "end_time_ms": optional_ms_json(self.end_time_ms),
    "span_count": self.span_count.to_json(),
    "has_error": self.has_error.to_json(),
  }
}

///|
pub impl @json.FromJson for TraceSummary with fn from_json(json, path) {
  {
    trace_id: field(json, "trace_id", path),
    root_span_name: optional_field(json, "root_span_name", path),
    start_time_ms: read_ms(
      field_value(json, "start_time_ms", path),
      path.add_key("start_time_ms"),
    ),
    end_time_ms: optional_ms_field(json, "end_time_ms", path),
    span_count: field(json, "span_count", path),
    has_error: field(json, "has_error", path),
  }
}

///|
pub impl ToJson for TraceFilter with fn to_json(self) {
  {
    "name_contains": optional_json(self.name_contains),
    "has_error_only": self.has_error_only.to_json(),
    "min_start_time": optional_ms_json(self.min_start_time),
    "max_start_time": optional_ms_json(self.max_start_time),
  }
}

///|
pub impl @json.FromJson for TraceFilter with fn from_json(json, path) {
  {
    name_contains: optional_field(json, "name_contains", path),
    has_error_only: field(json, "has_error_only", path),
    min_start_time: optional_ms_field(json, "min_start_time", path),
    max_start_time: optional_ms_field(json, "max_start_time", path),
  }
}
