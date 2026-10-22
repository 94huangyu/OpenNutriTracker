# 食迹 Android 正式安装包

2026-10-22。独立正式 Android 包已发布为 [GitHub Release shiji-v2.4.0-66](https://github.com/94huangyu/OpenNutriTracker/releases/tag/shiji-v2.4.0-66)，未上传应用商店。

- 显示名称：食迹；图标：用户选定的原版C杏白；启动：同款系统静态图标接Flutter金点单次脉冲。
- 正式应用身份：`com.huangyu.shiji`，构建flavor：`shiji`；现有版本保持`2.4.0 / 66`。
- CPU：arm64-v8a；最低Android8.0/API26，目标API36。旧full/develop/validation应用身份保留。
- 新正式包有独立存储，首次安装不自动迁移原版/开发版/验证版数据。禁止通过卸载旧包、清空旧数据或修改签名来处理共存问题。
- 正式包使用独立长期PKCS12证书。后续覆盖更新要使用同一包名、同一签名；实际更新时递增versionCode。私钥与密码不随源码或APK公开。

## 对应源码与重建

APK运行源码与`evidence/shiji-release-v1.json`内641项运行输入指纹逐项对应。GitHub发布使用`shiji-v2.4.0-66`标签，对应提交`d62d9992ec9cb70755ac9b8f4132d98ad3a60a2f`；该标签的完整源码与许可证随GitHub自动源码归档提供。历史本机交付ZIP基于`27e1ebfe4e2144cdcd4fd03faff79354f073b1af`加当时未提交修改，是另一份冻结快照，保留不覆盖。公开Git仅包含源码、测试及脱敏验收摘要，不包含任何个人迁移资料、私钥或真实环境配置。

使用Flutter3.44.6、Java17或兼容Android构建JDK、Android SDK36。源码保留GPL许可和上游说明。`.env.example`是占位配置，复制为`.env`后按实际环境配置，再生成环境与本地化代码；不要上传真实配置。

签名配置JSON只存本地路径和别名，不直接存密码，例如：

```json
{
  "alias": "shiji-release",
  "keystore": "/private/path/shiji-release.p12",
  "passwordFile": "/different/private/path/store-password.txt"
}
```

以下操作会下载构建依赖、生成本机文件并读取指定签名资产；不会发布。先确认磁盘和网络预算。不要重新生成密钥来替代已有正式密钥。

```sh
flutter pub get
# 按.env.example配置好.env后运行
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
export SHIJI_SIGNING_CONFIG='/private/path/signing-private.json'
flutter build apk --release --flavor shiji --target-platform android-arm64
```

常规输出为`build/app/outputs/flutter-apk/app-shiji-release.apk`。不要在正式构建中使用`--no-pub`跳过插件清单重建，否则之前测试可能留下开发专用插件引用。不要手改GeneratedPluginRegistrant.java。

本机受预算限制复用了现有Flutter原生release二进制，并与官方Maven ZIP目录逐条目CRC和大小核对；正式嵌入JAR/POM来自官方服务器。Android Lint使用现有官方31.13.0缓存，对应临时AGP覆盖参数值8.13.0；保留release检查，不通过关闭Lint换取成功。临时配置构建后撤销；不安装新SDK。

## 验收边界

本轮结果以`evidence/shiji-release-v1.json`及交付校验摘要为准。既有完整业务测试/两台Android16扫码与用户手选图片验证保留其原有覆盖范围。本轮针对正式签名、独立身份、正式APK启动及同包同证书重装保留数据补验；同一APK重装不等于未来所有版本迁移都已验证。iOS、读屏、商店发布不参与。
