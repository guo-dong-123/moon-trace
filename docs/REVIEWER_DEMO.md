# MoonTrace 离线评审演示

从干净克隆开始，无需 API Key、模型服务或数据库。首次下载依赖的耗时取决于网络；完成依赖准备后，以下流程可在几分钟内复现。

```bash
git clone https://github.com/guo-dong-123/moon-trace.git
cd moon-trace
moon update
moon test --target native

export MOONTRACE_DIR="$(mktemp -d /tmp/moontrace-review.XXXXXX)"
moon run examples/research_agent
moon run src/cli show trace_8
moon run src/cli export trace_8 "$MOONTRACE_DIR/trace_8.html"
moon run src/cli regress trace_1 trace_15 --check-output

MOONTRACE_DIR="$(mktemp -d /tmp/moontrace-replay.XXXXXX)" moon run examples/replay_agent
```

验收时应看到：

1. 33 项 native 测试通过；研究示例保存 `trace_1`、`trace_8`、`trace_15` 三条记录。
2. `trace_8` 的 `tool.knowledge_base` 为错误状态，Agent 仍给出降级回答；导出的 HTML 可直接在浏览器打开。
3. 严格回归检查通过；回放示例显示原始回答与回放回答一致，且 `Live tool calls` 在回放前后保持不变。

各示例必须使用独立目录，因为示例中的 Trace ID 会重新从 `trace_1` 开始。CLI 的 `replay` 命令只展示记录内容；真正的 Agent 离线重跑由 `examples/replay_agent` 演示。完整命令见 [CLI 指南](CLI_GUIDE.md)，固定输出样例见 [evidence](evidence/README.md)。

可选的真实模型示例需要自行配置 `BAILIAN_API_KEY`，不属于本离线验收流程。
