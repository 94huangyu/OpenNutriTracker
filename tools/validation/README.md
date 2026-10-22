# Android M5 隔离验证

仅供明确启动的本地验证，不由 `lib/main.dart` 或常规集成测试自动调用。

- `validation` flavor：`com.opennutritracker.ont.opennutritracker.validation`，名称“食迹 验证”。原版基础包名和既有 `.develop` 身份不变。安装前仍须核对实际手机已有包、版本/证书、组件提供器标识及文件保护摘要；发现验证包已存在时不可默认覆盖。
- `m5_isolated_restore.dart`：先从实际 `PackageInfo` 检查完整包名，匹配后才获取路径和打开数据库。合成夹具还检查真实路径、私有沙箱和临时目录，拒绝链接或其他目录。不能把该入口编入原版/日常测试版执行。
- 合成夹具包含14类资料及三张现场生成、编码并解码过的图片/署名。新导入资料会生成新的存储范围；完整恢复按资料ID规范化该范围后逐项比对所有记录和附件。回滚比对保持严格，不忽略范围或记录字段。
- `write_failure` 在事务写入钩子抛出模拟ENOSPC；不会填满手机磁盘。`interrupt` 在日志落盘、部分数据写入后等待，宿主只强制停止 `.validation`，再次启动 `recover` 校验真实重启回滚。不是对用户原数据库做恢复。
- `seed_performance` 只向空的验证安装内写入1000条合成摄入、20个食品、90天汇总，其中200条在当天，不创建身体资料。已有业务记录则拒绝，不清空重种。随后可安装同身份/同签名的正常 `lib/main.dart` profile构建，测量真实页面；不能把profile数据写成最终release结论。

## 构建与驱动

下面操作会创建本地构建产物并短时占用CPU。先加载本项目既有 `.tools/env.sh`；不安装新SDK、不生成签名、不覆盖冻结APK。`build_android_validation.py` 强制离线，每次最多300秒，失败停止自身进程组并撤销临时配置。profile所需同版官方Flutter运行库须事先按资源预算补齐至 `.tools/m5-maven`；构建期间不下载。

```bash
python3 tools/validation/build_android_validation.py debug-probe
python3 tools/validation/build_android_validation.py profile-app
```

安装与设备命令必须显式指定已核对的独立ADB服务和设备，不默认取首台设备；不要运行旧 `dev_seed`、onboarding或清数据脚本。探针命令文件为验证包私有 `files/m5-command.json`，内容为 `{"mode":"roundtrip"}`、`write_failure`、`interrupt`、`recover` 或 `seed_performance`。结果原子写入私有 `files/m5-validation/status.json`。等待中断检查点后才允许宿主停止验证包，禁止替换成其他包名。

宿主原始证据、设备身份、安装/备份及VM服务令牌只能留本地忽略目录。每步按包身份/哈希/结果核对，不把安装、启动或文件名当测试通过。结束检查原版/既有测试版的包及保护摘要、恢复临时设置、停止本轮独立服务，保留USB信任。

`tools/benchmarks/capture_profile_trace.dart` 只连接显式localhost ADB转发；采集结束恢复原VM时间线标记。帧数据须按真实事件和线程解析，不能用Android窗口统计代替Flutter光栅帧，或用少量内存采样声称覆盖全部峰值。
