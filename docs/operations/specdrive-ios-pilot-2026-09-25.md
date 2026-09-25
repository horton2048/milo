# Specdrive + MILO iOS 实测记录

日期：2026-09-25。目标是更新 Specdrive，并用真实 iPhone 客户端的第一条用户路径验证框架，而不是只修改提示词。

## 已实现的范围

- 原生 SwiftUI：七种主要心情、可留空的此刻记录、保存、历史和详情。
- 本地版本化 JSON、原子写入、相同 ID 更新、重启读取；损坏文件不覆盖，保存失败保留输入。
- OpenSpec 1.13.2 的 proposal/specs/design/tasks，独立规划和实现审查。
- 项目内安装更新后的 Specdrive，来源 `horton2048/specdrive`，精确版本见 `.agents/skills/specdrive/PROVENANCE.json`。
- 原生构建、六条 UI 测试、软件键盘和大字体截图检查，以及 macOS GitHub Actions 验证。

本轮仅覆盖此刻速记，尚未覆盖过去回忆对话、AI、账号、同步、导出、签名或上架。Web/HarmonyOS 的既有工作区改动未纳入本次提交。

## 已执行的验证

| 验证 | 实际结果 |
| --- | --- |
| Specdrive 运行器行为测试 | 本地 19/19，通过；GitHub macOS/Linux 均通过 |
| 云端审图回执验证 | 本地 7/7 通过，拒绝旧运行、旧源码、图片改动、路径越界和超时 |
| 独立框架正向实测 | 成功、续跑、旧证据失效、失败阻断评审、修复、前置环境恢复全部符合预期 |
| 独立发现的两个路径缺陷 | 父目录符号链接和 `/tmp` 别名问题均修复，原复现独立重测通过 |
| OpenSpec 严格验证 | 已通过；规划文件变更后需要重新获取当前证据 |
| Swift 业务行为测试 | 17/17 通过，含实际文件重开、空白/长中文、排序去重、异常保护 |
| SwiftUI 本地类型检查 | 使用 macOS SDK 通过，不能等同于 iOS 编译 |
| 独立代码审查 | 已通过；检查了核心存储、错误状态、原生验证配置和证据路径 |
| 本地 iOS 环境 | blocked：未安装完整 Xcode；不会由业务单测代替 |
| GitHub 第一轮原生构建 | Xcode 16.4 / Swift 6.1 / iOS 18.5 / iPhone 16e，真实构建通过 |
| GitHub 第一轮 UI | 4/5 通过；最大字号输入时误触保存，验收正确失败，修复后重跑 |
| 最终视觉验收/归档 | 待实际截图检查，OpenSpec change 保持未归档 |

## 可核查的位置

- 框架 PR：https://github.com/horton2048/specdrive/pull/1
- iOS PR：https://github.com/horton2048/milo/pull/1
- 原生验证：https://github.com/horton2048/milo/actions/workflows/ios-specdrive.yml
- 规格与任务：`openspec/changes/ios-offline-journal/`
- 本地执行日志：`apps/ios/.specdrive/pilot-2/`（未提交，含每个命令的退出码和输出）
- 运行说明：`apps/ios/README.md`

本地第一次实际执行约 11 秒：规格、19 项框架测试、17 项业务测试通过；Xcode 前置检查返回 78，依赖它的构建和 UI 没有被误执行或勾选。第二次执行复用了三项已通过结果，仅重查环境。环境连续缺失达到配置上限后，运行器停止重复尝试并保留日志。安装 Xcode 后，应先记录环境改变，再创建新的验证运行；旧运行保留，不靠清除失败记录获取绿灯。

## 本次实测促成的改进

1. 由宿主实际能力适配 Codex 和 Claude，不依赖不存在的工具名称。
2. 把检查超时、次数、无进展停止、输入和日志哈希、锁和恢复放进可执行程序。
3. 工程配置单独负责，按独立功能分工，避免为并发而并发。
4. 明确分开“核心逻辑通过”和“iOS 真正构建/运行通过”。
5. 截图和 xcresult 必须存于被指纹校验的证据目录，不能只检查一份写着 pass 的文档。
6. 屏幕键盘必须实际出现；选择的模拟器和编译器必须满足当前工程最低要求。
7. 第一轮原生实测发现最大字号下按钮过高、编辑器点击被遮挡。框架保存了失败视频和日志，没有把“可编译”误报为“可交付”。
8. 云端原生测试后保留同一个执行状态，最多等待十分钟的独立审图；回执绑定运行编号、源码版本和每张截图的哈希，恢复后执行完整门禁。CI 的只读凭据无法自批回执。

第一轮云端证据：[run 36153565983](https://github.com/horton2048/milo/actions/runs/36153565983)，源提交 `111f74b07ceba00c4e63568f2fbb8bf4d0ba844c`。已通过的四条 UI 路径是保存后重启、空记录与空历史、写入失败保留输入、损坏文件重启后继续阻断；失败项是最大字号长中文与深浅模式检查。原始 artifact 在 Actions 保留 14 天，本次下载副本位于 `/tmp/milo-ci-36153565983/`。

第二轮 [run 36155819644](https://github.com/horton2048/milo/actions/runs/36155819644)，源提交 `e531bf74649be6bee3d8b01891905ae08831f1fd`，前五项（含真正 iOS 编译）通过，但苹果 UI 测试运行器初始化返回 `AXDisableAccessibilityOnTermination: kAXErrorCannotComplete`，未执行任何测试、未产生截图。因此本轮不能证明大字号修复成功。保留该轮证据后，在下一轮显式等候所选模拟器启动、打开 Simulator 并关闭测试克隆并行。该处理参考了 [GitHub runner-images 中的同类报告及维护者验证步骤](https://github.com/actions/runner-images/issues/11874)；属于待实测的环境缓解措施，不保证消除所有云端波动。

Specdrive 已证明能组织实际开发、捕获问题和拒绝过早验收。它仍是编排技能与检查执行器：没有后台模型服务、自动唤醒、模型费用硬限制，也不是防篡改证据系统。
