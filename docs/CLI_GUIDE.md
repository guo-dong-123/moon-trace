# MoonTrace CLI 演示指南

这份指南用于在没有 API Key 的情况下复现 MoonTrace 的核心 MVP。示例会生成嵌套 Agent Trace、保存 JSON，并导出可直接用浏览器打开的 HTML。

## 1. 构建和测试

```bash
moon update
moon build
moon test
```

预期结果：`17` 个测试通过，失败数为 `0`。

## 2. 生成示例 Trace

使用独立目录，避免影响默认用户数据：

```bash
rm -rf /tmp/moontrace-mvp-demo
MOONTRACE_DIR=/tmp/moontrace-mvp-demo moon run examples/research_agent
```

该示例包含正常工具调用、计算步骤、知识库失败和降级回答。它不访问网络，也不需要模型密钥。

## 3. 查看执行记录

```bash
MOONTRACE_DIR=/tmp/moontrace-mvp-demo moon run src/cli list
MOONTRACE_DIR=/tmp/moontrace-mvp-demo moon run src/cli show trace_1
```

`show` 输出应包含嵌套的 Agent、搜索、计算和知识库 Span，并显示失败 Span 的错误信息。

筛选历史 Trace：

```bash
MOONTRACE_DIR=/tmp/moontrace-mvp-demo moon run src/cli errors
MOONTRACE_DIR=/tmp/moontrace-mvp-demo moon run src/cli list --errors
MOONTRACE_DIR=/tmp/moontrace-mvp-demo moon run src/cli list --name research_agent
```

## 3.1 运行失败诊断 Demo

```bash
MOONTRACE_DIR=/tmp/moontrace-failure moon run examples/failure_diagnosis
MOONTRACE_DIR=/tmp/moontrace-failure moon run src/cli errors
```

这个 Demo 会展示一次知识库超时、错误 Span、`fallback_started` 事件和最终恢复结果。

## 4. 导出 HTML

```bash
MOONTRACE_DIR=/tmp/moontrace-mvp-demo \
  moon run src/cli export trace_1 docs/evidence/trace_1.html
```

然后用浏览器打开 `docs/evidence/trace_1.html`。页面包含 Span 数量、错误数量、总耗时、可折叠调用树和时间线。

## 5. 运行真实 Bailian Agent

真实模型示例需要用户自己提供环境变量：

```bash
BAILIAN_API_KEY='your-key' \
TEXT_MODEL='qwen3.7-plus' \
AGENT_QUERY='请指出 MoonTrace MVP 最适合现场展示的能力。' \
MOONTRACE_DIR=/tmp/moontrace-bailian \
moon run examples/bailian_agent --target native
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
| `moon run src/cli export <id> <file>` | 导出单个 HTML |
| `moon run src/cli export-all <dir>` | 批量导出 HTML 和索引 |
| `moon run src/cli delete <id>` | 删除指定 Trace |
