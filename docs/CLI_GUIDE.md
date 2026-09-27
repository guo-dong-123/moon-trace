# MoonTrace CLI 演示指南

这份指南用于在没有 API Key 的情况下复现 MoonTrace 的核心 MVP。示例会生成嵌套 Agent Trace、保存 JSON，并导出可直接用浏览器打开的 HTML。

## 1. 构建和测试

```bash
moon update
moon build
moon test
```

预期结果：测试全部通过，失败数为 `0`。

## 2. 生成示例 Trace

使用独立目录，避免影响默认用户数据：

```bash
export MOONTRACE_DIR="$(mktemp -d /tmp/moontrace-mvp-demo.XXXXXX)"
moon run examples/research_agent
```

该示例包含正常工具调用、计算步骤、知识库失败和降级回答。它不访问网络，也不需要模型密钥。示例的 Trace ID 从 `trace_1` 重新开始，因此不同示例不要共用存储目录，否则可能覆盖同名 Trace。

## 3. 查看执行记录

```bash
moon run src/cli list
moon run src/cli show trace_8
```

`show` 输出应包含嵌套的 Agent、搜索、计算和知识库 Span，并显示失败 Span 的错误信息。

筛选历史 Trace：

```bash
moon run src/cli errors
moon run src/cli list --errors
moon run src/cli list --name research_agent
```

## 3.1 运行失败诊断 Demo

```bash
FAILURE_DIR="$(mktemp -d /tmp/moontrace-failure.XXXXXX)"
MOONTRACE_DIR="$FAILURE_DIR" moon run examples/failure_diagnosis
MOONTRACE_DIR="$FAILURE_DIR" moon run src/cli errors
```

这个 Demo 会展示一次知识库超时、错误 Span、`fallback_started` 事件和最终恢复结果。

## 4. 导出 HTML

```bash
moon run src/cli export trace_8 "$MOONTRACE_DIR/trace_8.html"
```

然后用浏览器打开 `$MOONTRACE_DIR/trace_8.html`。页面包含 Span 数量、错误数量、总耗时、可折叠调用树和时间线。仓库自带的 `docs/evidence/` 是固定示例，不应在复现时直接覆盖。

## 5. 运行真实 Bailian Agent

真实模型示例需要用户自己提供环境变量：

```bash
BAILIAN_API_KEY='your-key' \
TEXT_MODEL='qwen3.7-plus' \
AGENT_QUERY='请指出 MoonTrace MVP 最适合现场展示的能力。' \
MOONTRACE_DIR=/tmp/moontrace-bailian \
moon run --target native examples/bailian_agent
```

程序会先让模型选择 `inspect_moontrace_mvp` 工具，再把本地验证结果交给模型生成回答。无论请求成功还是失败，程序都会尝试保存 Trace；真实请求使用的 API Key 不会写入 Trace 或 HTML。

## 常用命令

| 命令 | 作用 |
|---|---|
| `moon run src/cli list` | 列出已保存 Trace |
| `moon run src/cli errors` | 只列出包含错误 Span 的 Trace |
| `moon run src/cli list --errors` | 按错误状态筛选 |
| `moon run src/cli list --name <text>` | 按根 Span 名称筛选 |
| `moon run src/cli show <id>` | 查看终端树 |
| `moon run src/cli compare <a> <b>` | 对比两次执行的耗时、错误和 Span 变化 |
| `moon run src/cli replay <id>` | 展示已记录的 Span 输出和错误，不重新调用外部工具 |
| `moon run src/cli regress <base> <new> [--check-output]` | 检查 Span；可选检查根 Agent 的最终输出 |
| `moon run src/cli export <id> <file>` | 导出单个 HTML |
| `moon run src/cli export-all <dir>` | 批量导出 HTML 和索引 |
| `moon run src/cli delete <id>` | 删除指定 Trace |

`regress` 默认将同名 Span 按状态和出现次数匹配。附加 `--check-output` 时还比较同名、成功的根 Span 最终输出；报告只显示发生变化，不打印输出内容。检查通过时退出码为 0；发现差异时为 1；Trace 不存在或参数无效时为 2。

运行 `MOONTRACE_DIR="$(mktemp -d /tmp/moontrace-replay.XXXXXX)" moon run examples/replay_agent` 可录制一次工具调用，然后离线重跑同一 Agent。示例会核对重复工具调用顺序、失败后的降级结果以及回放期间真实工具调用次数不变。

真实 Bailian 示例默认不把用户问题、工具参数、最终回答和服务端错误正文写入 Trace，但普通 `@trace.span` 会记录调用者提供的输入与返回值。不要把密钥或私人资料传给普通 Span，导出前应检查 Trace 内容。
