# MILO iOS 产品复刻迭代

当前工作对应 `openspec/changes/ios-harmony-product-parity`，最终验收以当前鸿蒙工作树的完整产品为准。早期 `ios-offline-journal` 是历史工具链试验，不代表本次完成。

已实现的页面包括：登录、心情圆环、词环、此刻/过去分流、此刻输入、过去时间、对话、日记、回忆长廊、详情、双模板卡片、我的、AI 设置。保留鸿蒙原始星球 PNG、深色星空和紫粉按钮，原生适配键盘、安全区域和辅助字号。

数据仍只存本机。Schema 1 记录读取不改原文件，成功写入迁移为 Schema 2。草稿、完整对话、日记和卡片模板单独持久化；写入失败保留文字，收藏重试使用持久化 ID 避免重复。API Key 使用按账号/目的地址隔离的 Keychain。

## 实际验证

- Core：31 项测试通过，涵盖迁移、损坏/未来版本保护、双流程、上下文清理、草稿恢复、原子删除和幂等收藏 ID。
- 协调器：26 项无网络检查通过（11 项 AI、15 项存储/恢复），覆盖取消、晚到响应、草稿冲突双份保留、失败重试和私有缓存清理；另一位审查者独立运行通过。这不代表真实服务接通。
- 原生 iOS：Xcode 26.6 / iOS 26.5 / iPhone 17e。修复阶段第三轮预构建和 **11/11 条操作测试通过**，含实际长文末尾输入、光标几何、模板切换及重启持久化。第三轮保存 9 张实际操作截图。
- 全状态截图：首轮修复前的完整 53 状态产出 183 张原图；独立审查按状态去重后实看 97 张附件（全局 91 个不同图像）。修复后新的完整采集在 `login--email` 未找到滚动几何标记而失败，尚未产出新命名状态截图。旧图不能作为当前版本的通过证据。计划和原始失败记录见 `docs/visual-parity/visual-repair-plan.md` 与 `visual-repair-progress.json`。
- 导出：已从两种卡片的真实系统分享操作取得 1080×1434 / 1080×1530 PNG，原图与校验信息保存在本机 `apps/ios/evidence/parity/exported-cards/`。独立审图未见缺失、遮挡或裁切；中文短末行仍可改进。
- 证据工具：24 项测试通过，覆盖源与构建关联、图片损坏、错用截图、滚动遗漏、字号冲突和预构建时间约束。
- 最终视觉：`docs/visual-parity/cases.json` 的 53 项必需对照（包括 8 项大字号、长页完整滚动）全部需要两端原图和独立评审；目前不能宣称完整复刻或最终美学验收通过。

## 仍需完成

1. 鸿蒙模拟器首次运行需要接受其软件许可和随附隐私声明，已请求用户确认，尚未代为接受。参考端当前工作树已成功构建。
2. iOS AGC 应用配置和真实 SDK/provider 接入仍缺失。`milo` 是明确的本地入口；DEBUG 合成账号仅作截图，远程登录不会假报成功。
3. 默认 AI 网关在当前鸿蒙版本也未配置。个人模型的网络代码已实现，真实邮箱、真实模型及真机麦克风/相册验证须单独留证。
4. 尚未进行实体 iPhone 测试。模拟器截图不能代替真机结论。
5. 新版完整截图采集仍需修复，并验证最大字号和嵌套编辑器的全部滚动覆盖。当前正式验收格式只支持单个滚动区域，不能将编辑器偏移冒充整页偏移。
6. 本轮 Specdrive 状态 `apps/ios/.specdrive/parity-visual-repair-20260926` 保留 5/11 → 9/11 → 11/11 的真实结果及后续截图失败；预构建已执行 3 次，不清零或追加同义运行来获得通过。
7. 最新独立审图仍发现实际模板切换后的选项上移、碰到页码，左侧副标题受底栏遮挡。单独模板夹具的几何测试通过不能关闭这张操作图的问题；需进一步区分稳定布局缺陷和过早采集，再复验。

## 运行

```sh
xcodegen generate --spec apps/ios/project.yml
swift test --package-path apps/ios/MiloCore
apps/ios/scripts/test-journal-ai.sh
node --test apps/ios/tests/parity-evidence.test.mjs
node .agents/skills/specdrive/scripts/specdrive.mjs init apps/ios/specdrive.parity.json --project .
```

使用 `init` 输出的原状态目录执行 `run`、修复后恢复同一状态。`full-visual-parity` 和 `real-agc-auth` 保持必需检查，缺失外部证据时会明确阻塞，不能通过删除检查获得“完成”。

`--parity-case` 只在 DEBUG 且 `--uitest-id` 为合法 UUID 时生效，存储固定进入 `MILO-UITests/<UUID>`。不能以这些参数重置生产数据。
