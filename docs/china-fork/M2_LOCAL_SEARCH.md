# M2.4 本地搜索、历史保护与四页自验交付

日期：2026-10-20。M2核心记录范围通过代理自验，逐项目标见[M2_SELF_ACCEPTANCE.md](M2_SELF_ACCEPTANCE.md)。这是阶段开发包，不是最终产品release验收。

## 本批结果

食品搜索支持中文单字本地查询，本地结果不等待公共来源。每个远程来源独立展示加载、失败、未配置、关闭或确实没有结果；个人结果下面不会再出现通用“未找到结果”。快速输入、清空、刷新共用取消顺序，旧请求不会回盖新结果；缓存写入失败也不丢弃已取得的有效结果。

合并结果仅折叠规格、单份和已有24项营养均相同且核心热量/宏量已知的OFF重复项。同名不同包装、钠、热量或未知营养的条目仍保留；个人食品和配方不按名称合并。不凭“来自数据库”赋予已核验状态。

删除食品库模板现在只删除模板，保留历史摄入的食品快照与当天总量。真实Hive回归保留两天记录、删除模板并重新打开数据库，再逐字段比较历史JSON；真机另用本轮临时模板验证删除、升级、重启后125kcal仍在。

界面还修正了详情未知营养被显示为0、创建前多余确认弹窗，以及创建/返回/撤销后的状态栏浅底白字。相机错误增加中文解释和可重试操作；两个扫码入口共用错误组件，异步重试期间禁用按钮、失败后恢复。创建页安全区只包正文与底栏，App根部按主题提供状态栏样式回退。

继续沿用原BLoC/GetIt、仓储、Hive加密与per100营养计算；本批不新增依赖或数据库字段，不改既有历史营养。搜索与配方页的factory BLoC在页面生命周期内持有、关闭，不在重建时重新获取空实例。

## 源码与安装包

- Fork：94huangyu/OpenNutriTracker；分支 `feature/m2-core-diary`。
- GitHub业务提交：`6b7fcebdfd7f940c10c396113ea793646c1377bc`。
- 本地构建提交：`9aac03b4c11d70f17eeefd53b75feca7473c8481`，保留于 `archive/m2-local-search-local-20261020`。
- 两者树相同：`f74f1a50ee3117842acbc5a650883c1b42e6f8b1`。所有本批独立提交映射见[evidence/m2-local-search.json](evidence/m2-local-search.json)。GitHub工具创建提交的元数据不同，以精确树SHA确认源码一致。
- 最终APK：`output/flutter/m2.4/m2.4-local-search-r3-v2.4.0-66-develop-arm64-debug.apk`。
- 字节数：137591756；SHA-256：`a53f3b89f00dde7a51614454ed966d8fc9c7f42c625736f046c44bf0a1b4b572`。
- 签名SHA-256：`8b5adf8691201ac71c7fc4037f5121e639b0e8f84269902cb52d5bb1eb4e61e0`。
- 版本沿用 `2.4.0-develop` / 66、ONT Develop、原develop包名、target36；没有为重新打包升版本或换签。Flutter指定android-arm64，aapt仍列部分传递插件的其他ABI，不能据此宣称APK仅含一个ABI。
- 该APK已在vivo X300 / Android16同签名覆盖安装，读取安装后的base.apk核对相同SHA。

R1/R2 APK和M0/M2.1/M2.2/M2.3所有冻结包保留，不覆盖、不删除。R1是搜索/历史保护实机长流程使用包；R2增加快速创建和相机错误；R3增加状态栏修复并用于最终实机回归。R2未安装。每个包的来源提交、SHA与检查边界单列于本地元数据，不混用截图证明后来改动。

## 自动化与构建

| 检查 | 结果 | 本地日志 |
| --- | --- | --- |
| 最终源码完整测试 | 2659通过，0失败，0跳过；93295ms | `.tools/logs/m24-r3-final-full-tests.jsonl`、`m24-r3-final-test-summary.json` |
| Dart静态分析 | 0诊断 | `.tools/logs/m24-r3-final-analyze.log` |
| Android develop debug构建 | 成功 | `.tools/logs/m24-r3-final-build.log` |
| 最终源码UI截图子集 | 32通过；28张组件图 | `.tools/logs/m24-r3-ui-captures.log`、`output/flutter/m2.4-r3-self-review/` |

32项属于全套中相关测试的再次截图运行，不能再相加宣称2691个不同测试。`flutter analyze`仍受固定SDK中文路径LSP问题影响，本轮使用并明确记录 `dart analyze --format=machine`；未把前者说成成功。Android SDK XML版本提示仍存在，未阻断构建，未额外安装组件。

关键测试：

- `test/unit_test/products_bloc_search_test.dart`：Product/Food本地单字、远程防抖、旧请求、清空和失败重试。
- `test/unit_test/search_products_usecase_test.dart`、`meal_relevance_ranker_test.dart`：来源状态、本地保留、保守去重。
- `test/unit_test/delete_custom_meal_history_test.dart`：真实Hive删除模板、两天快照/总量和重新打开。
- `test/features/add_meal/search_screen_states_test.dart`：慢来源独立呈现、整页异常态、直接创建和中文返回。
- `test/features/edit_meal/presentation/food_specification_form_test.dart`：两组规格、原基准、20项高级营养、键盘保存和布局。
- `test/features/meal_detail/unknown_nutrients_display_test.dart`：未知为“—”、已知0仍为0；自由数量与实时换算沿用相关详情测试。
- `test/features/scanner/scanner_camera_error_test.dart`：拒绝/普通错误中文、重试忙状态/失败恢复、窄屏大字。
- `test/widget_test/system_bar_contrast_test.dart`：真实App根部、Android平台、路由进入/退出与浅深主题下的SystemChrome样式。

## 组件与真机视觉证据

最终组件目录含首页、创建简单/高级、详情、搜索、来源页、相机错误；覆盖320宽1.6倍和390宽2倍等指定状态。已人工检查三项规格、窄屏搜索/首页、详情未知/深色、底部保存及高级末段；滚动截图不冒充初始全屏。组件使用测试字体，CustomIcons字形在部分截图不全；手机实际扫码图标另查，不将测试字体缺字误报为App错误。

真机截图分版本保存：

| 来源 | 目录/文件 | 核实内容 |
| --- | --- | --- |
| R1：64966518业务树 | `output/flutter/m2.4-device/` 的02–12 | 单字Q本地、来源状态、详情半份、200/50/100高级/键盘保存、深色、删临时模板保留记录；其中旧状态栏缺陷后来修复 |
| R3：6b7fcebd业务树 | `output/flutter/m2.4-r3-device/01-upgraded-history-125.png` | 删模板后升级仍保留125kcal |
| R3 | `02-direct-create-no-confirmation.png`、`05-home-status-bar-125.png` | 一步创建、创建/返回首页状态栏清晰 |
| R3 | `06-record-half-serving.png`、`07-deleted-125.png`、`08-undo-250.png` | 0.5份=25g125kcal；复制250→删除125→撤销250 |
| R3 | `09-edit-ten-grams.png`、`10-independent-edit-175.png` | 独立记录改10g50kcal；另一条125不变，共175 |
| R3 | `11-cleaned-home-zero.png`、`12-original-templates-retained.png`、`13-restored-settings.png`、`14-final-home.png` | 仅本轮测试摄入清理至0；原QAFoodA/B保留；系统外观/kcal恢复 |

重启后再次读到175kcal以及10g/25g两条独立记录，然后才清理测试摄入。删除模板后的最近记录仍可从日记快照出现，是历史保留行为，不表示模板未删除。

### 相机证据边界

`03-camera-permission-feedback.png`实际是系统权限请求；`04-camera-denied-localized.png`实际已返回创建表单并显示条码值6973886191480，文件名不代表断言通过。尝试拒绝后检查重试的操作因页面已返回表单而中止，不能从该图推断“拒绝→重试”成功；也没有保存可核验的实物条码输入过程，因此本轮不列真实解码通过。没有把后来观察到的授权状态归因为某个未经证实的原因，没有在清理时擅自改动相机授权。

2026-10-15单次真实识别回填的历史证据见[M2_RECORDING_ONLY.md](M2_RECORDING_ONLY.md)。这仍不能外推为国内外条码全覆盖。完整设备权限与实物矩阵留M5，当前中文错误和重试的实现由组件验证。

## 数据保护与收尾

三个受保护Hive文件（身体/运动/体重）与安装前SHA相同；只删除本轮QA_M24_Flow模板及摄入，原两个食品模板保留。外观恢复跟随系统、kcal显示未改；临时插电亮屏2恢复原值0；App已停止，独立15038 ADB服务已关闭，其他共享调试服务与USB信任未改。最后一次重启后的本应用进程日志无崩溃/布局异常匹配；该日志范围不代表整个历史生命周期。

安装前加密文件私有快照只存本地忽略目录，未上传；它不是完整恢复测试。公开证据仅有摘要/相对路径/安装包与截图哈希，不含设备序列号、用户内容、凭据或完整日志。

本批没有Hive字段迁移；M2已存在18原营养基准、19/20原来源/条目编号可空字段继续兼容旧数据。per100、24项营养和历史快照不变，JSON/CSV相关兼容回归通过。完整备份缺项、恢复非原子和重复导入问题仍在M4，不能据本批声明完整备份已修复。

## 后续阶段

M3再做个人核对/收藏持久化与数据可信度、营养口径；M4做完整备份恢复/趋势等；M5做release、品牌、性能、多设备及完整扫码矩阵。当前M2没有已知待实施的核心流程缺口，不要求用户重新查漏；也不自动开始后续阶段。
