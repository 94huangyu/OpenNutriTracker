# M2 实施准备：四页核心记录流程

日期：2026-10-15。用户已确认M1第四版并要求继续。状态：**接入方案和环境预算已完成，固定SDK及原版构建已通过，正在M2.0营养数据保护修复；基线与失败边界见M2_BASELINE.md。**

## 设计与源码基线

- M1原型：`a3f05ccebcad5f41bcb81c35a3e47fe3c4d0c316`；阶段验收记录提交：`b80e98f25f6e2a589e21e6af6904d28990605195`。
- 开发分支：`feature/m2-core-diary`，从验收提交建立；设计分支保持独立。
- 原版业务基线：`8d2420f0305c96a4f798f3a111509827260f6df7`，Flutter固定3.44.6。
- 核心约束：包装大小、单份份量、营养基准独立；60/15/15与200/50/100验收算例；自由输入数量，不列数量预设；创建扫码只回填数字；四餐默认汇总、点开明细。

## 本机资源预算与授权范围

以下预算针对Flutter安装、项目依赖、原版Android debug构建，不包含模拟器、iOS工具链、后端或真机安装。

| 项目 | 已核实或估算 |
| --- | --- |
| Flutter包下载 | 2,211,701,158字节，2.06GiB；官方macOS arm64 3.44.6 |
| Flutter解压内容 | ZIP目录22,420项，合计4,245,087,045字节，3.95GiB；实际磁盘分配会略有差异 |
| 仅压缩包与解压SDK并存 | 文件字节合计6.01GiB，未计文件系统分配和下载临时开销 |
| 首次依赖、Gradle与构建产物 | 另外约3–7GiB，估算；缓存命中情况与插件构建会改变此值 |
| 整体磁盘预算 | 峰值约10–15GiB，建议至少预留15GiB；若需要额外Android组件另报预算 |
| 总网络流量 | SDK加首次依赖约3–5GiB，估算；不得把2.06GiB误称为全部流量 |
| 内存/CPU | 原项目Gradle JVM堆上限4GiB；含Dart/编译进程预留约6–10GiB运行内存，估算。限制并行构建，不启动模拟器；编译时CPU占用和发热可能明显 |
| 耗时 | SDK按1–10MB/s约4–40分钟；解压、依赖和首次编译另预留20–60分钟。均为估算，网络慢或构建错误会延长 |
| 当前可用磁盘 | 约71.7GiB；没有用当前空闲空间代替用户授权 |
| 已有Android组件 | platforms android-36、build-tools36.0.0、NDK28.2.13676358；与项目compileSdk及固定Flutter默认NDK一致，无需预先重复安装 |
| 费用 | SDK和本地编译无购买费用，不创建云服务或付费API |
| 修改位置 | 拟放在项目 `.tools/`；pub/Gradle缓存也尽量项目隔离，不改全局PATH或系统SDK设置，不提交工具包、缓存或密钥 |

官方来源：[发布清单](https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json)。SDK SHA-256：`e4824875f22cc7e0f4878bfc8b9382e98ff0137074c5d3ab4686f7a4b5ac775c`。预算阶段只读取了约3.1MiB远端ZIP目录和一个小配置文件；授权后开始下载完整SDK，待校验及版本验证。官方包内FlutterExtension.kt指定NDK28.2.13676358。

已通过系统硬件摘要确认本机为Apple M5、16GB内存、10核CPU。直接sysctl读取曾被权限限制，改用只读系统摘要后得到确认；上表6–10GiB仍是构建预算，不是实测峰值。首轮仅单项构建、Gradle最多2个worker，不同时启动模拟器。已有全局Gradle缓存约4.2G、wrapper约707M，不删除这些其他项目可能共用的资产。

用户最新要求：以后每次请示都先说明资源需求。该要求属于本项目持续约束；本次用户在完整预算后原文回复：“允许，按上述预算执行”。允许在上述范围安装SDK、验证原版编译并继续M2；超预算或额外Android组件须再说明并请示。

## 先补原版基线，后改界面

1. 授权后安装固定SDK并校验官方SHA-256，工具/依赖目录加入忽略规则。保留下载包直到解压和版本验证通过，不做全局配置修改。
2. 使用原工程依赖锁定文件；生成l10n/env等项目要求输出。没有Supabase凭据，不向作者服务索取或伪造密钥。
3. 先跑现有静态分析和测试，再构建原版debug APK，记录版本、SHA、日志及失败。未改业务代码的结果作为本机基线，不拿上游CI代替。
4. 原版启动初始化无条件调用Supabase.initialize，`.env.example`又是占位值。必须实测区分“编译成功”和“可启动”；如无配置导致本地功能无法启动，仅做独立、可测的无配置降级修复，不假称在线参考库可用。
5. 不连接或清空用户手机、Hive资料或演示profile；`dev_seed`会清活动profile，不默认执行。首次UI验证优先组件截图和隔离测试资料。

## 接入地图与改造顺序

| 批次 | 原代码接入点 | 具体行为与保护 |
| --- | --- | --- |
| M2.0 基线与保护检查 | `lib/core/utils/locator.dart`、现有测试 | 先确认缺Supabase时能否启动；复现M0发现的高级字段保存/重复缩放问题，必要保护修复独立提交，不改Hive结构 |
| M2.1 食品创建与摄入闭环 | `features/edit_meal/presentation/edit_meal_screen.dart`、`bloc/edit_meal_bloc.dart`；`features/meal_detail/util/meal_quantity_converter.dart`及详情页 | 简单/高级都保留三项规格；源码已有条码扫描回填直接复用；沿用per100归一化与份到g/mL换算；去掉数量预设；先完成两个用户算例与保存/回读截图 |
| M2.2 样式与搜索 | `core/styles/app_theme.dart`、`app_palette.dart`、`dimens.dart`；`features/add_meal/presentation/add_meal_screen.dart`及已有BLoC | 统一输入、按钮、字号、颜色；保留本地自建/配方/最近/缓存和OFF适配，不新接付费数据源，不凭名称粗暴去重 |
| M2.3 日记与首页 | `core/presentation/main_screen.dart`、`features/home/home_page.dart`、`features/diary/diary_page.dart`、`CalendarDayBloc` | 四餐默认折叠；保留直接添加和记录操作；日期使用已支持任意日期的CalendarDayBloc，不能把仅加载今天的HomeBloc硬套到历史日；保留逻辑日开始偏移、历史目标与活动计算 |

每批独立提交、测试和截图再推进，最后才切换默认导航。沿用现有BLoC/GetIt和路由，不创建第二套仓储。`locator`注册factory的BLoC不能重新取实例读状态。

### 数据与计算合同

- 包装写回MealEntity.mealQuantity/mealUnit；单份写回servingQuantity/servingUnit。现有数据库的营养值继续存per100。用户在2026-10-15明确选择重新编辑时保留原营养基准（例如15g/80kcal）；为此新增可空的原基准元数据，旧数据缺值时按100读取，并补Hive/JSON/CSV兼容测试。
- 保存：每基准X g/mL的标签营养N，存N×100/X；摄入A份先换算A×单份g/mL，再乘per-unit。包装大小不参与热量分母。
- 现有结构没有单独持久化“原录入营养基准”；用户已确认需要保留原填写方式。新增字段只记住基准，不改变per100计算、历史摄入量或历史营养值；不能用包装或单份数猜测基准。重新显示时用该基准换算原表单数值。
- 保留全部已有24项营养数据；未知null不等于0，不将已有per100旧值再次乘100/X。营养校验只提示，不用4/4/9强行覆盖标签热量。
- 编辑模板不追溯更改既有记录食品快照。收藏和个人核对在原持久化模型中不足，M3再做兼容设计，M2不能自动生成“已核验”或伪装已保存。
- Hive typeId及加密保持不变；仅为用户已确认的原营养基准新增可空字段并覆盖现有导入导出兼容。完整备份缺项的全面整改不在本批；M0备份缺口仍存在，不能对用户宣传已完成完整备份恢复。

## 验收与回退

- 现有相关测试：`edit_meal_simple_mode_scale_test.dart`、`edit_meal_serving_unit_test.dart`、`edit_meal_simple_empty_field_test.dart`、`edit_meal_energy_unit_round_trip_test.dart`、`meal_quantity_converter_test.dart`、`edit_meal_unwind_test.dart`；在SDK就绪后先跑基线，再新增两个包装算例、字段完整保留和无配置启动回归。
- 核心交互：录入两组规格→保存→查回→按份/g/mL记录→改量/删除/重复→核对当日汇总和历史快照；创建条码扫描返回及取消不清空输入。
- 组件截图：四个核心页、深色、窄屏和大字号，测输入/下拉高度；实际相机权限/设备扫码仍需Android真机，不能由组件测试代替。
- 每步提交到M2独立分支，不强推、不合并main、不改品牌包名/签名或上传商店；验收失败回到前一提交。

## 本轮已做与未做

已做：M1确认、M2独立分支、SDK校验和安装、锁定依赖及代码生成、Dart分析、原版全量测试与Android debug APK基线。正在进行营养数据保护回归。未做：M2正式界面交付、设备启动与相机验收。
