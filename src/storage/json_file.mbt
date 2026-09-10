// JSON file-based storage implementation

pub struct JsonFileStore {
  base_dir : String
}

pub fn JsonFileStore::new(base_dir : String) -> JsonFileStore {
  { base_dir: base_dir }
}

/// Default store at ~/.moontrace/traces
pub fn JsonFileStore::default() -> JsonFileStore {
  let home = match @env.get_env_var("HOME") {
    None => "/tmp"
    Some(h) => h
  }
  let dir = home + "/.moontrace/traces"
  { base_dir: dir }
}

fn JsonFileStore::trace_path(self : JsonFileStore, trace_id : String) -> String {
  self.base_dir + "/" + trace_id + ".json"
}

fn JsonFileStore::index_path(self : JsonFileStore) -> String {
  self.base_dir + "/index.json"
}

fn JsonFileStore::ensure_dir(self : JsonFileStore) -> Unit {
  if !@fs.path_exists(self.base_dir) {
    // Create parent directory first if needed
    let home = match @env.get_env_var("HOME") {
      None => "/tmp"
      Some(h) => h
    }
    let parent = home + "/.moontrace"
    if !@fs.path_exists(parent) {
      try { @fs.create_dir(parent) } catch { _ => () }
    }
    try {
      @fs.create_dir(self.base_dir)
    } catch {
      _ => ()
    }
  }
}

fn JsonFileStore::read_index(self : JsonFileStore) -> Array[TraceSummary] {
  let path = self.index_path()
  if !@fs.path_exists(path) {
    return []
  }
  try {
    let content = @fs.read_file_to_string(path)
    let json = @json.parse(content)
    let result : Array[TraceSummary] = @json.from_json(json)
    result
  } catch {
    _ => []
  }
}

fn JsonFileStore::write_index(self : JsonFileStore, summaries : Array[TraceSummary]) -> Unit {
  self.ensure_dir()
  let json = @json.to_json(summaries)
  let content = json.stringify()
  try {
    @fs.write_string_to_file(self.index_path(), content)
  } catch {
    _ => ()
  }
}

pub fn JsonFileStore::save(self : JsonFileStore, trace : @trace.Trace) -> Unit {
  self.ensure_dir()
  // Write trace file
  let json = @json.to_json(trace)
  let content = json.stringify()
  try {
    @fs.write_string_to_file(self.trace_path(trace.id), content)
  } catch {
    _ => ()
  }
  // Update index
  let summaries = self.read_index()
  let filtered : Array[TraceSummary] = []
  for s in summaries {
    if s.trace_id != trace.id {
      filtered.push(s)
    }
  }
  filtered.push(trace.to_summary())
  self.write_index(filtered)
}

pub fn JsonFileStore::load(self : JsonFileStore, trace_id : String) -> Option[@trace.Trace] {
  let path = self.trace_path(trace_id)
  if !@fs.path_exists(path) {
    return None
  }
  try {
    let content = @fs.read_file_to_string(path)
    let json = @json.parse(content)
    let trace : @trace.Trace = @json.from_json(json)
    Some(trace)
  } catch {
    _ => None
  }
}

pub fn JsonFileStore::list(self : JsonFileStore) -> Array[TraceSummary] {
  let summaries = self.read_index()
  summaries.sort_by((a, b) => b.start_time_ms - a.start_time_ms)
  summaries
}

pub fn JsonFileStore::delete(self : JsonFileStore, trace_id : String) -> Bool {
  let path = self.trace_path(trace_id)
  if !@fs.path_exists(path) {
    return false
  }
  try {
    @fs.remove_file(path)
  } catch {
    _ => ()
  }
  // Update index
  let summaries = self.read_index()
  let filtered : Array[TraceSummary] = []
  for s in summaries {
    if s.trace_id != trace_id {
      filtered.push(s)
    }
  }
  self.write_index(filtered)
  true
}
