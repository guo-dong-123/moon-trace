// Immutable JSON snapshots; directory contents are the source of truth.
///|
pub struct JsonFileStore {
  base_dir : String
  priv mut error : String?
}

///|
pub struct RecoveryReport {
  trace_count : Int
  issues : Array[String]
  index_rebuilt : Bool
}

///|
pub fn JsonFileStore::new(base_dir : String) -> JsonFileStore {
  { base_dir, error: None, }
}

///|
pub fn JsonFileStore::default() -> JsonFileStore {
  JsonFileStore::new(
    @env.get_env_var("HOME").unwrap_or("/tmp") + "/.moontrace/traces",
  )
}

///|
/// Last diagnostic for a Bool/Option operation.
pub fn JsonFileStore::last_error(self : JsonFileStore) -> String? {
  self.error
}

///|
fn valid_trace_id(id : String) -> Bool {
  if id.length() == 0 || id.length() > 256 || id == "index" {
    return false
  }
  for c in id {
    if !(c >= 'a' && c <= 'z') &&
      !(c >= 'A' && c <= 'Z') &&
      !(c >= '0' && c <= '9') &&
      c != '_' &&
      c != '-' {
      return false
    }
  }
  true
}

///|
fn JsonFileStore::trace_path(self : JsonFileStore, id : String) -> String {
  self.base_dir + "/" + id + ".json"
}

///|
pub fn JsonFileStore::save(self : JsonFileStore, trace : @trace.Trace) -> Bool {
  self.error = None
  if !valid_trace_id(trace.id) {
    self.error = Some(
      "Invalid trace ID; only letters, digits, '-' and '_' are allowed",
    )
    return false
  }
  if !ensure_directories(self.base_dir) ||
    !(@fs.is_dir(self.base_dir) catch { _ => false }) {
    self.error = Some("Cannot create trace directory: " + self.base_dir)
    return false
  }
  let content = trace.to_json().stringify()
  match atomic_write(self.trace_path(trace.id), content, false) {
    0 => true
    1 => {
      let identical = try {
        let existing : @trace.Trace = @json.from_json(
          @json.parse(@fs.read_file_to_string(self.trace_path(trace.id))),
        )
        existing.to_json() == trace.to_json()
      } catch {
        _ => false
      }
      if !identical {
        self.error = Some(
          "Trace ID already exists with different data: " + trace.id,
        )
      }
      identical
    }
    _ => {
      self.error = Some(
        "Atomic trace write failed (native filesystem required): " + trace.id,
      )
      false
    }
  }
}

///|
pub fn JsonFileStore::load(
  self : JsonFileStore,
  trace_id : String,
) -> @trace.Trace? {
  self.error = None
  if !valid_trace_id(trace_id) {
    self.error = Some("Invalid trace ID: " + trace_id)
    return None
  }
  let path = self.trace_path(trace_id)
  try {
    let trace : @trace.Trace = @json.from_json(
      @json.parse(@fs.read_file_to_string(path)),
    )
    if trace.id != trace_id {
      self.error = Some("Trace ID does not match filename: " + trace_id)
      None
    } else {
      Some(trace)
    }
  } catch {
    error => {
      self.error = Some(
        "Cannot read or decode trace: " + path + ": " + error.to_string(),
      )
      None
    }
  }
}

///|
fn JsonFileStore::scan(
  self : JsonFileStore,
) -> (Array[TraceSummary], Array[String]) {
  let summaries : Array[TraceSummary] = []
  let issues : Array[String] = []
  if !@fs.path_exists(self.base_dir) {
    return (summaries, issues)
  }
  let files = @fs.read_dir(self.base_dir) catch {
    _ => {
      issues.push("Cannot read trace directory: " + self.base_dir)
      return (summaries, issues)
    }
  }
  for file in files {
    if file == "index.json" || !file.has_suffix(".json") {
      continue
    }
    let id = file[:file.length() - 5].to_owned()
    match self.load(id) {
      Some(trace) => summaries.push(trace.to_summary())
      None => issues.push(self.error.unwrap_or("Unreadable trace: " + file))
    }
  }
  summaries.sort_by((a, b) => {
    if a.start_time_ms == b.start_time_ms {
      a.trace_id.compare(b.trace_id)
    } else if a.start_time_ms > b.start_time_ms {
      -1
    } else {
      1
    }
  })
  (summaries, issues)
}

///|
pub fn JsonFileStore::list(self : JsonFileStore) -> Array[TraceSummary] {
  let (summaries, issues) = self.scan()
  self.error = if issues.is_empty() { None } else { Some(issues.join("; ")) }
  summaries
}

///|
/// Rebuild the legacy index cache from valid snapshots. Malformed files are
/// reported and left intact; a missing/corrupt/stale index cannot hide traces.
pub fn JsonFileStore::repair(self : JsonFileStore) -> RecoveryReport {
  let (summaries, issues) = self.scan()
  let rebuilt = ensure_directories(self.base_dir) &&
    atomic_write(
      self.base_dir + "/index.json",
      summaries.to_json().stringify(),
      true,
    ) ==
    0
  if !rebuilt {
    issues.push("Cannot rebuild index cache")
  }
  self.error = if issues.is_empty() { None } else { Some(issues.join("; ")) }
  { trace_count: summaries.length(), issues, index_rebuilt: rebuilt, }
}

///|
pub fn JsonFileStore::delete(self : JsonFileStore, trace_id : String) -> Bool {
  self.error = None
  if !valid_trace_id(trace_id) {
    self.error = Some("Invalid trace ID")
    return false
  }
  try {
    @fs.remove_file(self.trace_path(trace_id))
    true
  } catch {
    _ => {
      self.error = Some("Cannot delete trace: " + trace_id)
      false
    }
  }
}
