# Mooncakes 发布与安装验证

## 发布记录

- 发布时间：2026-10-25，Asia/Shanghai。
- 模块：`guo-dong-123/moon-trace`。
- 版本：`0.1.0`。
- 公开包页面：https://mooncakes.io/docs/guo-dong-123/moon-trace@0.1.0
- 发布包下载：https://download.mooncakes.io/user/guo-dong-123/moon-trace/0.1.0.zip
- 发布源码提交：`af79ce0`；Git 标签：`v0.1.0`。
- `moon publish` 服务端响应：`Server status: 200 OK`，命令退出码为 0。
- 已在浏览器中确认包页面显示 `0.1.0 (latest)`、README、安装命令和下载入口。

从公开下载地址获取的 ZIP 与本地上传 ZIP 的 SHA-256 一致：

```text
b5476c4456402b69c8d0e8abfee92736bc0657b377f8ad2e8d8592f51ac4ab23
```

## 发布前验证

```text
moon check --target native      passed
moon test --target native       Total tests: 33, passed: 33, failed: 0.
moon build --target native      passed
```

发布命令还对上传 ZIP 解包后再次执行了 `moon check`，结果为 `Check passed`。检查过程中保留了研究示例原有的三项 `Show` 弃用警告，没有编译错误。发布包未包含本地凭证或填入密钥的 `.env` 文件。

## 独立项目安装验证

在仓库之外创建了独立 MoonBit 项目，通过以下命令下载注册表中的正式发布包；未使用本地路径依赖或源码 checkout：

```bash
moon add --no-update guo-dong-123/moon-trace@0.1.0
moon add --no-update moonbitlang/x@0.5.4
moon run . --target native
```

当时索引已包含新版本，但自动全量更新的 `git pull` 停滞，因此安装验证使用了 `--no-update`。正常安装命令为 `moon add guo-dong-123/moon-trace@0.1.0`。额外的 `moonbitlang/x` 导入用于验证程序把 HTML 写入文件。

独立程序导入了正式包的 `trace`、`storage`、`replay`、`exporter` 和 `tui`，完成以下断言：

1. Agent 根 span 与工具子 span 组成两层追踪，工具返回值正确。
2. 追踪成功保存为 JSON，再次读取后仍有两条 span。
3. 回放返回已记录的工具输出，消费次数为 1。
4. 原始记录与读回记录的严格回归比较通过。
5. 终端视图包含工具名称，HTML 包含 Agent 名称和工具输出，并成功写入文件。

实际输出：

```text
Mooncakes integration: tracing, JSON storage, replay, regression, terminal view and HTML export passed
Trace: traces/trace_1.json
HTML: traces/registry-smoke.html
```

本记录证明已发布和可安装；赛事重新验收结果由赛事方确认。

## 0.1.1 发布记录

- 变更提交：`da27ff2 feat: enrich trace export debugging view`。
- 导出 HTML 新增 Span metadata、事件列表、搜索和状态筛选。
- 修复 Span 结束时 metadata/events 被旧局部对象覆盖的问题。
- 发布版本：`0.1.1`，Mooncakes 服务端返回 `200 OK`，构建状态为 `success`。
- 公开包页面：https://mooncakes.io/docs/guo-dong-123/moon-trace@0.1.1
- 包校验和：`7c2ee1c605aacf862b0489c785c3b78744f113c44a0b820234332faa7918534b`。
- 发布前验证：`moon check --target native`、`moon test --target native`（33/33）、`moon build --target native`；上传包解包后再次 `moon check` 通过。

## 0.1.2 发布记录

- 发布时间：2026-10-29，Asia/Shanghai。
- 发布源码提交：`62c70f9`。
- `moon publish` 返回 `Server status: 200 OK`；上传 ZIP 解包后的类型检查通过。
- 公开页面：https://mooncakes.io/docs/guo-dong-123/moon-trace@0.1.2
- 浏览器确认页面显示 `0.1.2 (latest)`；官网公开 manifest 的 `build_status` 为 `success`。
- 发布包：https://download.mooncakes.io/user/guo-dong-123/moon-trace/0.1.2.zip
- 下载包与本地上传 ZIP 字节一致，SHA-256：

```text
a3d549220d936910e3e5c46c8a40a7cefc9d0600d796c832925681053fc3711a
```

发布前通过 45 项 MoonBit native 测试、16 个独立进程的 48 条快照写入验证，以及 Chromium 的筛选联动、折叠恢复、转义和 1440/390/320px 视口检查。详细范围见 [验证记录](VALIDATION_0.1.2.md)。研究示例原有的三项 `Show` 弃用警告仍存在。

在仓库之外创建独立消费项目，依赖正式的 `guo-dong-123/moon-trace@0.1.2`，未引用本地 checkout 或路径依赖。完整注册表更新超时，因此临时使用官网公开 manifest 中的原始元数据补齐该包的本机索引；下载仍来自正式注册表，校验和与公开 ZIP 一致，验证后已恢复原索引状态。

独立项目实际运行结果：

```text
PASS: Mooncakes 0.1.2 installed independently; concurrent tracing, Int64 timestamps, atomic storage, recovery, replay, terminal and HTML export
```
