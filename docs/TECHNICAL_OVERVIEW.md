# MoonTrace 详细技术说明

## 一、项目概述

MoonTrace 是一个使用 MoonBit 编写的 Agent 执行轨迹观测与调试工具。它通过轻量的闭包式 API 记录 Agent 的规划步骤、工具调用、输入输出、耗时、事件和错误，并提供终端查看与 HTML 导出能力。

项目面向使用 MoonBit 开发 Agent、工具调用工作流和自动化程序的开发者，目标是让一次 Agent 执行从“只看到最终答案”变成“可以检查完整过程”。MoonTrace 不依赖云端服务或 API key，适合本地开发、调试和教学演示。

## 二、问题与目标

Agent 的最终输出通常不足以解释程序为什么得到这个结果。一次请求可能经过规划、检索、计算、知识库访问和回答生成等多个步骤。出现错误时，开发者需要知道哪一个步骤失败、失败发生在调用链的什么位置、当时传入和返回了什么，以及错误是否触发了降级逻辑。

MoonBit 生态中缺少一个面向 Agent 执行过程的原生、轻量调试工具。MoonTrace 的目标是提供一套不依赖外部观测服务的基础能力：

1. 用一行闭包式调用记录一个 Agent 步骤；
2. 自动建立嵌套调用的父子关系；
3. 自动记录成功、失败、输入、输出和耗时；
4. 将 trace 保存为可回读的 JSON 文件；
5. 通过 CLI、终端树和 HTML 页面检查执行过程。

## 三、产品能力

### 3.1 Agent 埋点

开发者可以使用以下 API 包裹任意 Agent 步骤：

```moonbit
let result = @trace.span("tool.web_search", Some(query), () => {
  search_web(query)
})
```

多个嵌套 span 可以表示“规划 → 搜索 → 计算 → 综合回答”的调用树，调用方不需要修改原有函数签名。

### 3.2 执行信息记录

每个 span 记录名称、父 span、开始和结束时间、持续时间、输入、输出、状态、错误信息、事件和元数据。墙上时钟用于保存可读的执行时间，单调时钟用于计算持续时间，避免系统时间调整导致耗时异常。

当闭包抛出错误时，MoonTrace 会把当前 span 标记为错误，同时重新抛出原错误，保持业务代码原有的错误传播行为。外层 Agent 可以捕获错误并继续执行降级路径。

### 3.3 本地存储与查看

项目提供内存存储和 JSON 文件存储。JSON 存储使用单条 trace 一个文件和 `index.json` 索引，默认目录为 `~/.moontrace/traces/`，也可以通过 `MOONTRACE_DIR` 指定目录。

CLI 提供以下命令：

```text
moontrace list
moontrace show <trace_id>
moontrace export <trace_id> [output.html]
moontrace export-all [directory]
moontrace delete <trace_id>
```

终端查看器展示 trace 摘要和带颜色的嵌套树。HTML 导出器生成自包含页面，包含统计卡片、可折叠 span 树和时间线。

## 四、技术实现

项目由五个模块组成：

| 模块 | 作用 |
|---|---|
| `trace` | Trace、Span、事件、元数据、生命周期和上下文传播 |
| `storage` | MemoryStore、JsonFileStore、索引和过滤查询 |
| `tui` | 终端列表视图与详情树 |
| `exporter` | 自包含 HTML 和时间线导出 |
| `cli` | list、show、export、export-all、delete、help 命令 |

核心状态由 tracer 管理。嵌套 span 创建时读取当前 span 作为父节点，完成或失败时更新对应记录。上下文 API `capture_context` / `with_context` 用于显式传递 trace 上下文。

项目完全使用 MoonBit 实现，不依赖 Python、Node.js、数据库或远程观测服务；当前外部依赖仅为 `moonbitlang/x@0.5.4` 的文件系统能力。

## 五、MVP 完成情况

当前 MVP 已经具备从埋点到结果检查的完整闭环：

- Agent 步骤可以形成嵌套 trace 树；
- 工具调用成功和失败状态都能被记录；
- 失败会保留错误信息，并且不会破坏外层 span 栈；
- trace 可以保存到 JSON 文件并重新读取；
- CLI 可以列出和查看历史 trace；
- trace 可以导出为自包含 HTML；
- 示例包含 Web 搜索、计算器、知识库超时和降级回答。

MVP 验证结果：

```text
moon build       通过
moon test        15 个测试通过，0 个失败
demo_agent       生成嵌套工具调用 trace
research_agent   生成 3 条 trace，包含成功和错误路径
CLI              list / show / export 验证通过
```

研究型 Agent 示例不调用真实服务，使用可控的模拟工具稳定复现成功、失败和降级流程，评审无需 API key 即可运行。

## 六、项目特色

1. **MoonBit 原生**：使用 MoonBit 类型系统、闭包和错误处理机制实现 Agent 观测能力。
2. **接入成本低**：闭包式 `span` API 不要求改变被观测函数的接口。
3. **错误信息完整**：错误状态、错误文本和调用层级同时保留，并维持原有错误传播语义。
4. **本地优先**：JSON 文件即可完成存储、回读和调试，不要求部署服务。
5. **结果易分享**：导出的 HTML 文件可直接在浏览器中打开。

## 七、演示方式

评审可以执行以下命令完成验证：

```bash
git clone https://github.com/guo-dong-123/moon-trace.git
cd moon-trace
moon update
moon build
moon test
moon run examples/demo_agent
MOONTRACE_DIR=/tmp/moontrace-mvp moon run examples/research_agent
MOONTRACE_DIR=/tmp/moontrace-mvp moon run src/cli list
MOONTRACE_DIR=/tmp/moontrace-mvp moon run src/cli show trace_1
MOONTRACE_DIR=/tmp/moontrace-mvp moon run src/cli export trace_1 /tmp/moontrace-mvp/trace_1.html
```

基础 Demo 展示 `agent_think`、`tool.web_search`、`tool.calculator` 和 `tool.knowledge_base` 的嵌套关系。研究型 Agent 展示正常查询、知识库不可用和回答降级三个执行结果。

## 八、后续方向

在当前本地调试闭环的基础上，后续可以增加性能分析、trace 对比、采样策略、实时查看和 OpenTelemetry 兼容导出。这些方向属于 MVP 之后的扩展，不影响当前项目完成 Agent 追踪、存储、查看和导出的核心目标。

## 九、项目信息

- **项目名称**：MoonTrace
- **GitHub 仓库**：https://github.com/guo-dong-123/moon-trace
- **技术栈**：MoonBit
- **规模**：15 个 `.mbt` 文件，约 2067 行代码
- **测试**：15 个正式单元测试，全部通过
- **许可证**：MIT
