# 无私有食品后端配置的开发构建

日期：2026-10-15。原版 `.env.example` 使用占位值，原初始化无条件调用 Supabase.initialize；这不能作为无配置本地功能可启动的保证。

本次将参考食品后端作为可选项：URL 不是有效 http/https 地址、匿名键为空或仍为 ANON_KEY 时，不初始化/注册 Supabase。参考库搜索直接返回空结果，不发请求、不使用假地址；Open Food Facts 与本地食品的数据路径保持独立。有效配置继续沿用原 Supabase 客户端与 RPC 查询，未改变作者服务授权边界。

这不代表已取得任何第三方服务账号或运行过真机 App；组件/单元测试仅证明无配置分支不会调用 Supabase 的平台初始化，以及有配置时既有模拟传输合同仍成立。搜索页还需在后续 M2.2 明确提示参考库未配置，不能把空结果伪称为该库查询成功。

Android settings.gradle 同时改为按 UTF-8 读取 Flutter 生成的 local.properties，处理中文工程/SDK路径。未修改 Flutter SDK 源码或系统 PATH。Dart分析仍绕过已记录的 Flutter analyze 中文路径问题，采用 dart analyze。

3项无配置/配置格式测试与3项既有模拟Supabase传输测试通过；包括全部模块的全量2614项测试通过，Dart分析0条诊断。没有有效账号时无法核验真实Supabase服务查询。

标准Flutter命令现已在中文工程路径构建成功：

```sh
source .tools/env.sh
flutter build apk --debug --flavor develop --target-platform android-arm64 --no-pub
```

本机缓存限制Gradle最多2个worker、Kotlin进程内编译，不自动下载额外Android组件、不启动模拟器。构建95.6秒，签名验证通过；新包独立归档到output/flutter/m2.1，原版归档未改。该命令使用的本地.env是原示例占位值，无真实后端凭据。编译通过不等于Android启动/相机通过。
