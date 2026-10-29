# 项目验收清单

适用版本：MoonTrace 0.1.3。固定工具链为 `moonc 0.10.14+7d59c7ec9`、`moon 0.1.20260920`。

| 要求 | 项目证据 |
|---|---|
| 1. 主要使用 MoonBit，moonc 不低于 0.10.14 | `src/` 与 `examples/` 以 MoonBit 实现；`.moonbit-version` 固定版本，`scripts/check_toolchain.py` 实际校验编译器，CI 执行同一检查 |
| 2. GitHub 公开且提交清晰 | https://github.com/guo-dong-123/moon-trace；沿用 `main`，功能、发布与验证记录分别提交 |
| 3. 结构清晰且核心功能可运行 | `trace`、`storage`、`replay`、`tui`、`exporter`、`cli` 六个模块；原生存储使用一个小型 C 辅助模块 |
| 4. README 含目标、安装、使用和示例 | 根目录 README；独立项目通过 Mooncakes 安装，仓库示例无需模型密钥即可复现核心流程 |
| 5. CI 覆盖检查、构建与测试 | `.github/workflows/ci.yml`；固定编译器、版本门槛、类型检查、测试与覆盖摘要、native 构建和集成验证 |
| 6. 至少一个可运行示例 | `examples/demo_agent`、`research_agent`、`concurrent_agent`、`replay_agent` 等 |
| 7. 测试覆盖核心功能路径 | 45 项 MoonBit 测试；3 项 Python 编译器门槛测试；多进程存储、CLI、回放和浏览器验收脚本 |
| 8. 发布到 Mooncakes | https://mooncakes.io/docs/guo-dong-123/moon-trace；各版本发布和独立安装证据见 `MOONCAKES_RELEASE.md` |
| 9. OSI 认可许可证及参考说明 | 根目录 MIT `LICENSE`；`THIRD_PARTY.md` 记录 Apache-2.0 依赖与概念参考来源 |

## 从公开源码复现

```bash
git clone https://github.com/guo-dong-123/moon-trace.git
cd moon-trace
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash -s -- "$(cat .moonbit-version)"
export PATH="$HOME/.moon/bin:$PATH"
python3 scripts/check_toolchain.py
moon update
moon check --target native --deny-warn
moon test --target native --enable-coverage --deny-warn
moon coverage report -f summary
moon build --target native --deny-warn
python3 -m unittest discover -s scripts -p 'test_*.py'
python3 scripts/verify_native.py
moon package
python3 scripts/verify_package.py
```

浏览器验证另外运行 `python3 scripts/verify_html.py`，需安装开发工具 `agent-browser` 和 Chromium。真实 Bailian 模型示例需要用户自己的 API Key，不是上述离线验收的前置条件。最新 CI 结果以 [GitHub Actions](https://github.com/guo-dong-123/moon-trace/actions) 中对应提交为准。
