# Third-party licenses and references

MoonTrace source code is released under the [MIT License](LICENSE). It is primarily an original MoonBit implementation, with one original C helper for atomic native filesystem commits.

## Dependencies

| Dependency | Version | License | Upstream |
|---|---|---|---|
| moonbitlang/x | 0.5.4 | Apache-2.0 | https://github.com/moonbitlang/x |
| moonbitlang/async | 0.20.1 | Apache-2.0 | https://github.com/moonbitlang/async |

Dependencies are declared in `moon.mod` and fetched by Moon. Their source code and licenses remain under their upstream licenses. The `.mooncakes/` dependency checkout is excluded from MoonTrace's source distribution; MoonTrace's MIT license does not replace the licenses of these dependencies. Applications redistributing dependencies or linked components must retain the notices required by those upstream licenses.

## Conceptual references

- OpenTelemetry trace/span concepts: https://opentelemetry.io/docs/concepts/signals/traces/
- LangSmith's product approach to inspecting Agent execution steps: https://docs.langchain.com/langsmith/observability

These are conceptual references, not source-code ports. MoonTrace does not include copied source from OpenTelemetry or LangSmith, does not claim protocol compatibility with either product, and does not imply their endorsement.
