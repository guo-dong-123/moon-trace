# MVP 复现证据

本目录用于保存不含密钥的演示产物。执行下面的命令可以重新生成同类文件：

```bash
rm -rf /tmp/moontrace-mvp-evidence
MOONTRACE_DIR=/tmp/moontrace-mvp-evidence moon run examples/research_agent
MOONTRACE_DIR=/tmp/moontrace-mvp-evidence moon run src/cli export trace_1 docs/evidence/trace_1.html
```

证据内容：

- `trace_1.json` / `trace_1.html`：正常执行的嵌套 Trace 和自包含可视化页面；
- `trace_8.json` / `trace_8.html`：知识库失败后降级的 Trace，其中包含 1 个错误 Span；
- `README.md`：生成命令和检查方式。

这些文件不包含 API Key、网络响应或个人信息。
