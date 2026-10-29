// Preserve the public method API explicitly under MoonBit 0.10.14.
pub extend SpanStatus with ToJson::{to_json}
pub extend SpanStatus with @json.FromJson::{from_json}
pub extend SpanStatus with @debug.Debug::{to_repr}

pub extend SpanEvent with ToJson::{to_json}
pub extend SpanEvent with @json.FromJson::{from_json}
pub extend SpanEvent with @debug.Debug::{to_repr}

pub extend Span with ToJson::{to_json}
pub extend Span with @json.FromJson::{from_json}
pub extend Span with @debug.Debug::{to_repr}

pub extend Trace with ToJson::{to_json}
pub extend Trace with @json.FromJson::{from_json}
pub extend Trace with @debug.Debug::{to_repr}
