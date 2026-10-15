# M2.0 本机原版编译基线

日期：2026-10-15。用户在查看下载、磁盘、内存、耗时及费用预算后明确授权：“允许，按上述预算执行”。本页补充M0审计的本机证据，不能替代设备验收。

## 结果

| 项目 | 结果 |
| --- | --- |
| 原版源码 | v2.4.0+66，8d2420f0305c96a4f798f3a111509827260f6df7；生成及构建前后lib/android/ios/pubspec与该提交完全一致 |
| SDK | Flutter3.44.6，Dart3.12.2；官方arm64压缩包SHA-256通过，版本通过 |
| 依赖 | flutter pub get --enforce-lockfile通过；锁文件未改 |
| 代码生成 | l10n及build_runner通过；已跟踪生成代码未改 |
| 静态分析 | dart analyze --format=machine通过，0条诊断；flutter analyze在中文工作目录下因SDK分析通道错误退出，未假报通过 |
| 原版全量测试 | 2592通过、1跳过、1失败，耗时100.47秒；失败为plaintext_destination_guard_test中对IPv6解析平台表现的断言 |
| Android | 原版develop debug构建成功，Gradle最终一次13分52秒；ARM64 Flutter引擎，未安装设备 |
| APK | 137,591,756字节；包名com.opennutritracker.ont.opennutritracker.develop，2.4.0-develop，版本号66，最低Android26、目标36；debug签名验证通过 |
| Supabase/设备/iOS | 未配置Supabase；未执行设备启动、相机、真实资料增删改、iOS测试 |

APK保留于本地`output/flutter/m0/original-v2.4.0-66-develop-arm64-8d2420f.apk`，不提交Git。SHA-256：`d528fb05dcd24a426f10ce750c9b330eaedc7ea940498d2207d20da4f4eba52d`。debug签名指纹及机器可读摘要见[evidence/m2-original-baseline.json](evidence/m2-original-baseline.json)。APK还含插件的其他ABI目录，但Flutter引擎只有arm64-v8a，不能称为通用APK。

## 本地环境与绕过方式

SDK、pub/Gradle缓存、Flutter配置、分析器状态及Android用户目录均放在`.tools/`；仅当前进程设置环境变量，不修改全局PATH，不删除原有SDK或缓存。最多2个Gradle worker、Kotlin进程内编译、不启动模拟器，禁止自动下载额外Android组件。现有API36、build-tools36和NDK28.2.13676358足够，无新增Android组件。

首次Flutter配置和分析器分别试图写入全局目录，被权限限制阻止；使用源码支持的XDG_CONFIG_HOME及ANALYZER_STATE_LOCATION_OVERRIDE指向项目目录后解决。工具遥测用FLUTTER_SUPPRESS_ANALYTICS/CI禁用。

两个工具链问题保留原始失败日志，未修改官方SDK或上游业务源码：

- Flutter3.44.6的`dart/analysis.dart`发送LSP消息时使用`message.length`，中文工作目录的UTF-8长度不同，导致分析服务读到截断JSON。改用同一SDK的`dart analyze`核验，输出0条诊断。
- Flutter写出的local.properties含UTF-8中文路径，但上游settings.gradle使用Java Properties的字节流读取，路径出现乱码。只将被忽略的local.properties路径转为Java Unicode转义，再直接调用原Gradle任务。后续可单独修复settings.gradle的读取编码。
- Kotlin后台编译试图写入全局Application Support目录，被阻止，后备编译又出现路径转义错误。指定`kotlin.compiler.execution.strategy=in-process`后相同源码构建成功；该配置是[Kotlin官方支持的编译方式](https://kotlinlang.org/docs/compiler-execution-strategy.html)。

复现入口为本机`.tools/env.sh`，缓存和日志被忽略。原版成功命令：

```sh
source .tools/env.sh
./android/gradlew -p android --max-workers=2 \
  -Pkotlin.compiler.execution.strategy=in-process \
  -Ptarget-platform=android-arm64 -Ptarget=lib/main.dart \
  -Ptrack-widget-creation=true assembleDevelopDebug
```

.env只使用原模板占位值，无真实服务密钥。编译成功不代表在线参考库或App启动已通过。完整本地日志位于`.tools/logs/`，包括baseline-tests.jsonl、baseline-dart-analyze.log、baseline-gradle-inprocess-build.log与APK元信息。

安装包下载2.06GiB、解压约4.0GiB；校验和版本验证完成后，仅删除本次新下载的压缩包释放2.06GiB，已安装SDK及缓存保留。最终构建后工具约11GiB、build约1.5GiB，另有APK归档和分析缓存，仍在15GiB峰值预算内。没有测得所有子进程的总内存峰值；系统查询只作为负载观察，不能当作编译进程内存测量。

## 后续保护修复

新增回归用例在原版上复现4项失败：遗漏的高级营养素、旧per100值重复缩放、清空字段无法成为未知、实际后端来源丢失。M2先单独修复这些数据保护问题，再实现三项规格表单与原基准回读；不追溯更改既有日记快照。

原版IPv6失败的断言要求`InternetAddress.tryParse`对转义区域地址返回null，本机返回地址。应验证“不触发DNS、URL保持原样”的实际安全合同，不能把某个平台的解析表现当通用前提；后续只改该测试，不改网络安全逻辑。
