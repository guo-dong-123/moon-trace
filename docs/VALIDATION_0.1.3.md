# 0.1.3 编译器与验收验证

日期：2026-10-29。此次验证使用正式工具链：

```text
moon 0.1.20260920 (914d7da 2026-09-20)
moonc v0.10.14+7d59c7ec9 (2026-09-18)
moonrun 0.1.20260920
```

`.moonbit-version` 固定安装版本；本地与 CI 使用相同文件。旧工具链 `moonc 0.10.12` 已实测被 `scripts/check_toolchain.py` 拒绝。

## 本地实测结果

| 检查 | 结果 |
|---|---|
| 编译器门槛检查 | PASS，满足 moonc >= 0.10.14 |
| 类型检查，编译器警告视为错误 | PASS |
| MoonBit native 测试 | 45/45，通过；包括启用覆盖率的运行 |
| Python 编译器门槛测试 | 3/3，通过；覆盖旧版本、最低版本、新版本、异常输出和预发布版本 |
| Native 构建，编译器警告视为错误 | PASS |
| 多进程集成脚本 | PASS，16 个独立进程写入 48 条不同记录；损坏索引恢复、CLI、回放与并发会话通过 |
| Chromium 检查 | PASS，筛选联动、空结果、折叠恢复、键盘操作、转义及 1440/390/320px 视口 |

## 编译器适配

- 黑盒测试显式使用包限定名，避免新版编译器的隐式导入警告。
- 使用显式 `extend` 声明公开的序列化和 Debug 方法，保持 SDK 方法接口。
- 研究示例以稳定格式记录规划和搜索结果，移除已弃用的集合 Show 用法。

## 复现命令

```bash
python3 scripts/check_toolchain.py
python3 -m unittest discover -s scripts -p 'test_*.py'
moon check --target native --deny-warn
moon test --target native --enable-coverage --deny-warn
moon coverage report -f summary
moon build --target native --deny-warn
python3 scripts/verify_native.py
python3 scripts/verify_html.py
```

覆盖摘要会包含没有单元测试入口的 CLI 与示例，因此不能把整库摘要冒充核心功能的覆盖率或宣称 100% 覆盖。CLI、多进程和浏览器路径另由集成脚本验证。真实付费模型请求不在本次离线验收范围内。

本地平台为 macOS native；Linux native 以 [GitHub Actions](https://github.com/guo-dong-123/moon-trace/actions/workflows/ci.yml) 对应提交的结果为准。许可证、公开仓库和发布要求见 [九项验收清单](ACCEPTANCE.md)，正式包的验证记录见 [发布记录](MOONCAKES_RELEASE.md)。
