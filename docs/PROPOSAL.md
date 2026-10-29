# MoonTrace 项目申报书

## 基本信息

- 项目名称：MoonTrace：MoonBit Agent 执行轨迹观测与调试工具
- 参赛者：陈彦玮
- GitHub 仓库链接：https://github.com/guo-dong-123/moon-trace
- Mooncakes 发布链接：https://mooncakes.io/docs/guo-dong-123/moon-trace@0.1.3
- 项目方向：MoonBit 开发工具 / Agent 可观测性基础设施
- 是否为移植项目：否
- 编译器要求：`moonc >= 0.10.14`；本项目固定验证版本为 `0.10.14+7d59c7ec9`，CI 会校验最低版本

## 项目简介

MoonTrace 是一个使用 MoonBit 原生实现的 Agent 执行轨迹观测与调试工具，面向使用 MoonBit 开发 AI Agent、工具调用工作流和自动化程序的开发者。它解决 Agent 执行过程不透明、工具调用失败难以定位、只能看到最终结果而无法检查中间步骤的问题。

开发者可以使用 `@trace.span` 和 `@trace.span_async` 包裹规划、检索、计算、知识库访问、模型调用和回答生成等步骤。MoonTrace 会记录调用层级、输入输出、事件、元数据、执行状态、错误信息和耗时，并将结果保存为本地 JSON 文件。开发者可通过 CLI 和终端树查看历史 trace，也可以导出包含统计信息、可折叠调用树和时间线的自包含 HTML 页面。项目核心无需云端服务或 API key，克隆仓库后即可构建、测试和运行离线示例；另提供可选的 Bailian Agent 真实模型演示。

## 核心功能范围

- 提供 Trace、Span、SpanEvent 和 SpanStatus 数据模型，记录一次 Agent 执行及其内部步骤；
- 提供 `start_trace`、`end_trace` 和闭包式 `span` API，自动建立嵌套调用的父子关系；
- 自动记录 span 的输入、输出、开始时间、结束时间和持续时间；
- 在工具调用失败时记录错误状态与错误信息，并保持原有错误传播语义；
- 支持自定义事件和元数据；并发请求使用 `TraceSession` / `TraceContext` 及 `span_in` / `span_async_in` 显式隔离上下文，旧全局 API 仅用于单执行流；
- 提供 MemoryStore 和 JsonFileStore，支持 trace 保存、读取、删除、摘要列表和条件过滤；文件快照原子提交、拒绝冲突覆盖，索引损坏后仍可恢复有效记录；
- 提供 `list`、`ids`、`show`、`compare`、`regress`、`replay`、`repair`、`export`、`export-all` 和 `delete` CLI 命令；
- 提供 ANSI 终端树形查看器，以及自包含 HTML 调用树和时间线导出；区分实际历时与累计 Span 时间，支持搜索、状态过滤与时间线联动；
- 提供研究型 Agent 示例，覆盖 Web 搜索、计算器、知识库超时和降级回答；
- 提供真实 Bailian Qwen 工具调用示例，展示模型选择工具、MoonBit 执行工具和模型综合回答的两轮流程；
- 提供 45 项 MoonBit 测试，覆盖同步与异步追踪、错误与取消、并发父子关系、存储恢复、旧 JSON 兼容、HTML 导出、离线回放与回归检查；另提供 3 项编译器门槛测试、多进程集成与浏览器验收脚本。

## 移植或参考说明

- 本项目为原创 MoonBit 项目，不是对其他语言项目源代码的直接移植；
- 项目在概念上参考了 OpenTelemetry 的 trace/span 模型，以及 LangSmith 对 Agent 执行过程进行分步骤观测的产品思路；
- 本项目没有复制 OpenTelemetry、LangSmith 或其他项目的源代码，数据结构、API、存储、终端查看器和 HTML 导出以 MoonBit 独立实现；原子文件提交使用一个自行实现的小型 C 辅助模块；
- 与云端 Agent 观测平台相比，MoonTrace 当前聚焦本地开发调试，采用 JSON 文件存储，不包含远程 Trace 服务、多用户权限或计费功能；
- 依赖 `moonbitlang/x@0.5.4` 与 `moonbitlang/async@0.20.1`，均保留 Apache-2.0 许可证边界；真实 Bailian 示例另外使用系统 `curl`；
- 本项目采用 MIT License，参考项目及概念来源不改变本项目原创实现和许可证边界。详见根目录 `THIRD_PARTY.md`。

## 验收与复现

最低编译器检查、类型检查、测试、覆盖摘要、原生构建与多进程集成均进入 GitHub Actions。评审可按 `docs/ACCEPTANCE.md` 逐项核对九项要求，并按 `docs/REVIEWER_DEMO.md` 运行无需密钥的离线演示。发布包的服务端构建及独立安装记录保存在 `docs/MOONCAKES_RELEASE.md`。
