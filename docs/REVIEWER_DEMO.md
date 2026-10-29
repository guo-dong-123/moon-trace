# MoonTrace 离线评审演示

Mooncakes 包入口：[guo-dong-123/moon-trace](https://mooncakes.io/docs/guo-dong-123/moon-trace)。在独立 MoonBit 项目中执行 `moon add guo-dong-123/moon-trace@0.1.2` 后，即可导入 `guo-dong-123/moon-trace/src/trace` 等 SDK 包；完整工作流使用 `--target native`。

从干净克隆开始，无需 API Key、模型服务或数据库。首次下载依赖的耗时取决于网络；完成依赖准备后，以下流程可在几分钟内复现。

```bash
git clone https://github.com/guo-dong-123/moon-trace.git
cd moon-trace
moon update
moon test --target native

export MOONTRACE_DIR="$(mktemp -d /tmp/moontrace-review.XXXXXX)"
moon run examples/research_agent
TRACE_ID=$(moon run src/cli ids --errors | head -n 1)
moon run src/cli show "$TRACE_ID"
moon run src/cli export "$TRACE_ID" "$MOONTRACE_DIR/trace.html"
moon build --target native
python3 scripts/verify_native.py
moon run examples/concurrent_agent --target native

MOONTRACE_DIR="$(mktemp -d /tmp/moontrace-replay.XXXXXX)" moon run examples/replay_agent
```

验收时应看到：

1. 45 项 native 测试通过；研究示例保存三条随机 ID 记录。
2. 含错误记录的 `tool.knowledge_base` 为错误状态，Agent 仍给出降级回答；导出的 HTML 可直接在浏览器打开。
3. 严格回归检查通过；回放示例显示原始回答与回放回答一致，且 `Live tool calls` 在回放前后保持不变。

0.1.2 使用随机 Trace ID，并拒绝用不同内容覆盖已有 ID。独立目录用于隔离演示数据。CLI 的 `replay` 命令只展示记录内容；真正的 Agent 离线重跑由 `examples/replay_agent` 演示。完整命令见 [CLI 指南](CLI_GUIDE.md)，固定输出样例见 [evidence](evidence/README.md)。

可选的真实模型示例需要自行配置 `BAILIAN_API_KEY`，不属于本离线验收流程。
