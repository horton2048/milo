# MILO · AppGallery Connect Submission Cheatsheet

The values below are pre-filled from the in-tree config so you can copy-paste
into the AGC form. The signed release HAP is produced locally by hvigorw
(see "Software package" below); all signing material stays on this machine.

## 1. App identity

| Field | Value | Source |
| --- | --- | --- |
| 应用名称（中文） | `MILO 米洛` | brand |
| 应用名称（英文） | `MILO` | brand |
| Bundle ID | `com.milo.echoes` | `apps/harmony/entry/src/main/module.json5` |
| 一级分类 | `工具` | product |
| 二级分类 | `效率` | product |
| 应用类型 | `App` (not 元服务) | platform |
| 适用设备 | `手机 / 平板 / 2in1` | HarmonyOS supported devices |

## 2. Application information (应用信息)

| Field | Value | Length |
| --- | --- | --- |
| 简短描述 | `回到过去的某一天 —— 让 AI 陪你唤醒一段记忆，沉淀成一篇属于你的日记。` | ≤ 80 chars |
| 完整描述 | 详见下文 | ≤ 4000 chars |
| 应用图标 | `docs/operations/agc-assets/app-icon-1024.png` (1024×1024 PNG) | required |
| 应用截图（手机） | `docs/operations/agc-assets/screenshot-01.png` ~ `screenshot-05.png` (5 张 1080×2340 PNG，2026-09-12 真机模拟器截取) | required |
| 应用截图（平板，可选） | 同比例 | optional |

### 完整描述（可直接粘贴）

```
MILO 是一款个人情绪日记与回忆应用。

你只需要转动光球、选一个模糊的时间（比如"去年夏天"），回响
MILO 的本地引导会一步步陪你说出当时的情景、困难或快乐、背后的原因，以及那一天对现在的意义。对话结束后，AI 以你的第一人称视角写成一篇日记（可手动开关、可编辑）。

特性：
· 离线优先 —— 飞行模式也能完整走完流程
· 隐私友好 —— 所有日记存在你的设备本地，不上传自有服务器
· 透明降级 —— AI 不可用时自动切回本地脚本与模板
· 多端 —— Web / HarmonyOS 原生，同一份后端契约

我们使用 MiniMax 作为对话与日记生成的 AI 处理者。MILO 不提供任何医疗、心理诊断或治疗服务。
```

## 3. Software package (软件包)

| Field | Value |
| --- | --- |
| 上传文件 | `apps/harmony/build/outputs/release/harmony-release-signed.app`（AGC 软件包管理要求 `.app` 格式；2026-09-12 已上传，合法性"已达标"） |
| 构建命令 | `cd apps/harmony && ./hvigorw assembleApp --mode project -p product=release -p buildMode=release` |
| 包内 HAP | `entry-default.hap`（≈6.8 MB，type=release） |
| 版本 | 1.0.0（versionCode 1000000） |
| Bundle ID | `com.milo.echoes` |
| 签名 Profile | AGC 发布 Profile `milo_release`（2026-09-12 创建，有效期至 2029-09-12） |
| 签名证书 | AGC 发布证书 `milo_release.cer`（certId 2037718107778208512，有效期至 2029-09-12，SHA1 指纹 `431c22413571fc3304f47f9801f458ceebb271e7`） |

> 2026-09-12 之前的旧发布证书 `milo` / 旧 Profile `com.milo.echoesRelease.p7b` 已废弃——其配对私钥随 9月11日 调试材料重建时丢失。勿再上传旧 Profile 对应的 HAP。
> ⚠️ 如 App 备案（ICP/App Filing）此前绑定的是旧证书指纹 `3ea4590089be234301d8b2933651989afdf8e4d4`，需在备案平台更新为新指纹 `431c22413571fc3304f47f9801f458ceebb271e7`。

## 4. Privacy & legal

| Field | Value |
| --- | --- |
| 隐私政策 URL | `{{ 你的 URL —— 来自 docs/operations/privacy-policy.template.md }}` |
| 权限声明 | `ohos.permission.MICROPHONE`，理由见 `apps/harmony/entry/src/main/resources/base/element/string.json#mic_reason` |
| 数据收集清单 | 见 `docs/compliance/data-flow.md` |
| 第三方 SDK | MiniMax（`api.minimax.chat`）—— 用途：对话与日记生成 |

## 5. 发布设置

| Field | Value |
| --- | --- |
| 发布地区 | `中国 / 全球（推荐先选中国）` |
| 上架类型 | `首次上架` |
| 审核类型 | `首次审核` |
| 预计上线时间 | `审核通过后立即` |

## 6. Pre-submit checks

```bash
# From repo root:
node scripts/device-checklist.mjs https://<your-gateway-url>

# Expect:
#   ✅ gateway /health
#   ✅ unsigned HAP exists
#   ⚠️  p12 candidates (none found — DevEco will ask for the path)
```

## 7. After submission

- 审核通常 1-3 工作日。
- 在 `docs/compliance/release-checklist.md` 的 Step 12 "Sign-off" 追加：
  - AGC 提交记录 URL
  - 提交时间戳
  - 审核结果

## 7.5 Submission draft status (2026-09-12 盘点)

AGC 草稿地址：`#/myApp/6917615962315597189/v2035850932872307584`（版本信息 → 准备提交）。

已完成（无需再动）：

- 应用信息步骤全部就绪：名称 MILO-米洛、图标、分类（应用/工具）、标签（AI 主标签 + 健康/笔记/专注/健康管理）、客服邮箱/QQ
- 软件包已上传并通过合法性校验（"已达标"），上架自检任务已启动（报告在 软件包管理 → 上架自检 → 报告）

剩余必填项（表单里的顺序）：

| # | 字段 | 状态 | 说明 |
| --- | --- | --- | --- |
| 1 | 应用介绍（≤8000字）+ 一句话简介（≤17字） | 可抄本文档 §2 | 直接粘贴 |
| 2 | 应用介绍截图 3~10 张 | ⚠️ 尺寸待核 | 表单要求最低 1920×1080（16:9）；现有截图 1080×2340 竖向，上传时若被拒需补横版或确认竖向最低 1080×1920 |
| 3 | 内容分级问卷 | 可填 | "设置"按钮进入问卷 |
| 4 | 隐私政策 | 🔴 需用户决策 | 选"隐私托管"（AGC 协议服务生成）或"自定义隐私政策"（需 URL） |
| 5 | 隐私标签：是否涉及个人信息收集 | 可答"是" | App 有 AGC 邮箱登录 |
| 6 | AI 功能声明 | 🔴 需用户决策 | App 含可选 AI 对话；"涉及"可能触发深度合成备案要求 |
| 7 | 备案信息：APP类型/主办单位类型/名称/证件号 | 🔴 需用户输入 | 需工信部 App 备案；单机 APP 选项可能简化流程 |
| 8 | 应用审核信息 | 可填 | 勾"需要登录进行审核"，备注：邮箱输 `milo` 直接进入 |
| 9 | 联系方式：手机号+短信验证码 | 🔴 仅用户 | 需接收短信并"提交验证" |
| 10 | 上架时间 | 可选"审核通过立即上架" | |

## 8. Update path (after first release)

```bash
cd apps/harmony
# 1. Bump version in entry/src/main/module.json5 (versionCode + versionName)
# 2. ./hvigorw assembleHap --mode module -p product=release -p buildMode=release
# 3. AGC → 我的项目 → milo → MILO-米洛 → 版本管理与发布 → 上传新版本 HAP
# 4. 提交审核
```

## 9. Release signing materials (local machine only)

Created 2026-09-12, all under `~/.ohos/config/`, never committed:

| File | What |
| --- | --- |
| `release_harmony_milo.cer` | 发布证书链（leaf=黄运樟 Release，SHA1 `431c2241…`） |
| `release_harmony_milo.p7b` | 发布 Profile `milo_release`（AGC 控制台创建下载） |
| `default_harmony_*.p12` | 与发布证书同密钥对的 keystore（`debugKey`，debug/release 共用） |

`build-profile.json5` 中 `signingConfigs.release` 引用以上文件；`products.release` 使用该签名。若 p12 密码变更，DevEco Studio 重新打开工程时会刷新 `material` 里的加密密码串。