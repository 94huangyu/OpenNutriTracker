# 本Fork的设备工具与安全续作

先读[当前状态与交接规则](../../docs/china-fork/CURRENT_STATE.md)。手机调试和同签名保留数据升级的已有授权继续有效；不要因换聊天重复索取。实际设备锁屏/断开与新的资源需求分别调查，不假定需要重装SDK或重新授权。

## 当前可用范围

- `adb-driver.sh`只提供界面定位/输入辅助，必须显式设置已核对的DEVICE；不再查询并选择首台设备。加载脚本不会连接手机；调用辅助函数才操作界面。
- 操作前核对设备、目标包/版本、APK及签名；安装前保护私有数据。确认所用ADB进程与端口；助手需自行设置合适的独立服务，不能假定本机旧端口仍由本轮持有。
- 结束只清理本轮临时记录、恢复本轮临时设置并停止本轮服务。不能清空资料、卸载App或关闭共享ADB来“重试”。序列号/私有备份/用户日志留本地忽略目录，不提交。
- 本文件的示例只解释工具接口，不能代替当前中文版实际控件与业务流程检查。

## 已停用的上游脚本

`walk-onboarding.sh`和`run-branch-tests.sh`原流程包含清空App数据、身体资料初始化，后者还切换分支、使用原版包名和复制签名相关文件。它们与当前只记录摄入的产品不兼容。本Fork的两个入口现在在执行任何外部命令前以状态2拒绝，直接运行和source均受保护，没有绕过开关。原实现可从Git历史查阅，不应在用户手机上恢复运行。

防误用回归只使用本机临时目录与假工具，不接手机、不构建：

```sh
python3 tools/adb/test_safety.py
```

## 界面辅助工具的使用原则

先只读核对目标设备，再显式提供DEVICE并加载驱动；下面的占位符必须替换为已核对设备，不能照抄旧日志中的序列号：

```bash
DEVICE='<已核对的设备序列号>'
source tools/adb/adb-driver.sh
```

驱动调用默认PATH中的adb。若使用独立端口，调用者须先明确配置实际adb入口/服务，再核对连接；不要将“提供DEVICE”误认为已完成服务隔离。执行界面动作前重新抓取当前UI，确认目标唯一；键盘和滚动后不可沿用旧坐标。手动与系统对话框均检查text/content-desc，空的App节点输出不等于屏幕空白。

### Flutter widgets on Android use `content-desc`, not `text`

When inspecting the uiautomator dump, the visible text of Flutter widgets is reported under `content-desc`, not `text`. System dialogs (DatePicker, AlertDialog) use `text`. Test drivers that find widgets by visible label must check both.

### Form fields drift between taps

Flutter `TextField` / `TextFormField` widgets all report screen-wide `bounds` in the uiautomator dump (the `container: true` gotcha applied to every form input). Tapping a field by hard-coded coordinates from an earlier dump only works once — the moment the keyboard pops up, every layout in the form shifts, and the next tap lands on the wrong row.

The `adb-driver.sh` helpers `tap_field_by_hint`, `enter_text_in_field`, and `fill_fields_by_hint` re-dump the UI before every tap and locate the field by its placeholder `hint` attribute (uiautomator dumps the TextField's placeholder there even when there's no `Semantics(identifier:)` on the field). They also hide the keyboard between fields so the next field's hit target is calculated against the post-IME layout, not the pre-IME one.

以下为上游驱动接口示例；实际中文字段先查当前UI，不运行旧onboarding：

```bash
# 先按上文显式设置DEVICE
source tools/adb/adb-driver.sh
fill_fields_by_hint \
  'Meal name'     'Greek%syoghurt' \
  'Energy (kcal)' '100' \
  'Carbohydrates' '4' \
  'Fat'           '5' \
  'Protein'       '10'
```

Pass `clear` as a third argument to `enter_text_in_field` when overwriting an existing value:

```bash
enter_text_in_field 'Protein' '10' clear
```
