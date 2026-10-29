// Preserve the public method API explicitly under MoonBit 0.10.14.
pub extend TraceSummary with ToJson::{to_json}
pub extend TraceSummary with @json.FromJson::{from_json}
pub extend TraceSummary with @debug.Debug::{to_repr}

pub extend TraceFilter with ToJson::{to_json}
pub extend TraceFilter with @json.FromJson::{from_json}
pub extend TraceFilter with @debug.Debug::{to_repr}
