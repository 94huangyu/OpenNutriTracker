# M3 源码上传审阅清单

2026-10-20。仅同步下列46个路径的本轮提交，其他路径继承原分支；以本地交付文档提交固定最终完整内容。确认前不上传文件。

## 目标与影响

目标仓库：[94huangyu/OpenNutriTracker](https://github.com/94huangyu/OpenNutriTracker)，目标分支`feature/m3-food-trust`。远端已只读核对仍为接手基线`dd8611b20ab3733283eaa8d11c8fed6481636d57`，与基线比较identical。本地M3共10个业务提交，随后单独提交这次交付文档；按现有提交同步并逐步验证精确Git树。开发分支已有内容不强推、不合main、不发布。

上传目的为保存M3源码、回归与验收证据摘要。这是源码外发：文件完整内容及本轮提交历史会保存到GitHub，受仓库可见性影响，历史内容不像本地草稿一样容易永久移除。网络文本载荷约1MiB（文件树JSON转义和协议开销另计），预计1–3分钟；不再构建、不连接或改动手机。同步前再次检查分支未被其他更新改变，变化时停止覆盖。

## 明确排除

不上传`.tools/`、`output/`、APK、构建产物、SDK/缓存、设备身份/序列号、私有备份、数据库、原始日志、`.env`、密钥或签名私钥。下列报告中的本地证据路径、合成QA名称、APK/截图哈希只提供引用，不等于上传对应文件。M4/M5不在此次范围。

## 完整文件列表

Blob列为本轮末态的Git内容哈希；本页自身由最终本地文档提交SHA固定，避免自引用哈希。除本页外，表中哈希可逐项用Git核对。

| 路径 | 用途 | 末态Blob SHA |
| --- | --- | --- |
| `android/app/src/main/kotlin/com/opennutritracker/ont/opennutritracker/MainActivity.kt` | vivo Android16系统栏恢复桥接 | bf1987e2d9ea4c5995a7d8323bdfa7662addc777 |
| `docs/china-fork/CURRENT_STATE.md` | 验收/格式/上传范围文档 | f53d3cf34fdb54ed0f243ea5d74885586241cb52 |
| `docs/china-fork/M3_PLAN.md` | 验收/格式/上传范围文档 | 944301b4ace5845930a05491faec9c00bb395b19 |
| `docs/china-fork/M3_SELF_ACCEPTANCE.md` | 验收/格式/上传范围文档 | 67408c2b79a26894f92c3020a9230fa28679f1f4 |
| `docs/china-fork/M3_UPLOAD_REVIEW.md` | 验收/格式/上传范围文档 | 本页由最终文档提交固定 |
| `docs/china-fork/evidence/m3-food-trust.json` | 验收/格式/上传范围文档 | 0e85f9eebf66bf41055cbed2a3e8af753fddd949 |
| `docs/export-format.md` | 验收/格式/上传范围文档 | 1e557527db0588c842ec20cf7372f28b32e2225a |
| `lib/core/data/data_source/custom_meal_data_source.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 5454c4e18fa4302bdbb06b300e01c88c2268bc0e |
| `lib/core/data/data_source/intake_data_source.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 50d13e380e79151277daeee4d8e6344e6fef5fc2 |
| `lib/core/data/data_source/personal_food_data_source.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | e73895edeed14809515bcb2a809238decb23f60c |
| `lib/core/data/data_source/recipe_data_source.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | e13261223f94e63298d8e6cae0797e9bc91da2b1 |
| `lib/core/data/dbo/meal_dbo.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 3d19f371fca9901f6f0ef3ba491d90d2eaccebca |
| `lib/core/data/dbo/meal_dbo.g.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | fefb5133d332019d5d6fb42c1a14c444e15d6524 |
| `lib/core/utils/csv_data_exporter.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 583b7a95c52bef03faf7b955d07c955f1c1656ec |
| `lib/core/utils/hive_db_provider.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 4f6b44454341182fe3382248c1e5c2034bc1c122 |
| `lib/core/utils/locator.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 929b693e904342f094ba2d5299d6c95b6a91b87c |
| `lib/core/utils/off_micronutrient_repair.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 6ec12c92a971871fa1e1696b65bf006245d0fde9 |
| `lib/features/add_meal/data/repository/products_repository.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 1bb3f81eb2bc39a73bd0448df03e11b5dfc0fa61 |
| `lib/features/add_meal/domain/entity/meal_entity.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 325ed1153d0fc9c2847a0957f4606a0735691365 |
| `lib/features/add_meal/domain/entity/meal_nutriments_entity.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 7c4370c00ed3172b083d316a6ff5cc654b217357 |
| `lib/features/add_meal/domain/usecase/search_products_usecase.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 92d5fe04a6950bf76d85faae470469052179e7e4 |
| `lib/features/add_meal/presentation/add_meal_screen.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | a35792b01ad1bbf17bfc0f1996ad3f8f236bdaa1 |
| `lib/features/add_meal/presentation/widgets/meal_item_card.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 86724682e1f1aa258f3902f4ce666cd3b6cd3293 |
| `lib/features/add_meal/presentation/widgets/personal_food_list.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | e95dd0ce9379e6e98cd62796d422b73c639d558b |
| `lib/features/add_meal/util/meal_relevance_ranker.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 21eafd5fa34ca6b8351941d53779cb49d38ca1ab |
| `lib/features/edit_meal/presentation/bloc/edit_meal_bloc.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 500781278d9f610219e3949e6262942cf96d2cdb |
| `lib/features/edit_meal/presentation/edit_meal_screen.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 4836555fe2a5b79c8ed5e092afb36d1af8398287 |
| `lib/features/meal_detail/meal_detail_screen.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 3cf5d8cc3f6786b25fe23754515cfb7ff830dfff |
| `lib/features/meal_detail/presentation/widgets/personal_food_actions.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | bb9ca3cadc0dce5bb6b2f63b2fdc716f938eb603 |
| `lib/features/recipes/presentation/screens/recipes_page.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 610bd3ec85a6946ad1f81180beb137b752892407 |
| `lib/features/scanner/domain/usecase/search_product_by_barcode_usecase.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | 2702c670a67fff337f468307f682e57080ed2c18 |
| `lib/features/settings/domain/usecase/export_data_usecase.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | d091dbc9e567ef92cf6938a820f828b587c4a9c4 |
| `lib/features/settings/domain/usecase/import_data_usecase.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | d02a299ea70337abd82d0fc978e5462f8dab69fa |
| `lib/l10n/intl_en.arb` | 食品数据/搜索/界面/营养实现或中英字符串 | 077fc83f1ddc1ea2a4a721de987c2043132976ba |
| `lib/l10n/intl_zh.arb` | 食品数据/搜索/界面/营养实现或中英字符串 | 883663cf5bf572d2232da9d19c9168acc910da62 |
| `lib/main.dart` | 食品数据/搜索/界面/营养实现或中英字符串 | cd2670b0a09b5467f55eaf193746258f4758f6bd |
| `test/features/meal_detail/personal_food_actions_test.dart` | M3回归与合成夹具 | 77077556b7315c36f7ec468bcef83a97a20a24c5 |
| `test/helpers/fake_hive_db_provider.dart` | M3回归与合成夹具 | 54185598794d953a6772d2b2c8a2b8dfb0f3b644 |
| `test/helpers/personal_food_fixture.dart` | M3回归与合成夹具 | 253452f792bd848959a64f9eb99911da92a2d4d9 |
| `test/unit_test/food_nutrition_basis_test.dart` | M3回归与合成夹具 | 790d0243cec86215dd43ef2f503e45eed8e76597 |
| `test/unit_test/m3_nutrition_tolerance_test.dart` | M3回归与合成夹具 | de1a89d0f322a3fcdcf21cda35f1f7b4463f9200 |
| `test/unit_test/off_micronutrient_repair_test.dart` | M3回归与合成夹具 | 5da600350e0b7e1ce9280a39d4d49be183e539f4 |
| `test/unit_test/personal_food_backup_test.dart` | M3回归与合成夹具 | 0648b3ebbba942f387aa40a141750c4d306ac70b |
| `test/unit_test/personal_food_lifecycle_test.dart` | M3回归与合成夹具 | 1348f541b226064531e2c6faae33f72f55fe32c6 |
| `test/unit_test/personal_food_persistence_test.dart` | M3回归与合成夹具 | df287b6ea1dc093fa5b11099a52d39ab3c3c78df |
| `test/widget_test/system_bar_contrast_test.dart` | M3回归与合成夹具 | 9ccad265beb0dc665208cbebef08d1643fee2e84 |

## 本地业务提交

- `dc39d573b43376b80d67bce6c9fac9a019c8f0ef feat: persist personal food favorites and evidence without changing diary snapshots`
- `bb21d1a90f1fe25fb37deb2db0ecf411500831f3 feat: add favorite filters and explicit personal food checks`
- `317296ddf45022790bdc84992924b4f1eba741f2 fix: account for fiber and label rounding in nutrition review hints`
- `70fd53043be05b9f3caecd3f75ed0ba055e60db8 test: isolate personal food migration fixtures between runs`
- `12d8d0231bcd0177760eccbe2769eeb09f959607 fix: clear food review validation errors while typing`
- `005dd860bc80e149d1ec99dbd9d04ad230cdf68e fix: restore Android system bar appearance after closing the keyboard`
- `5423e63b02434dccc23a66d33ad0b0b227829d07 fix: reapply edge-to-edge system bars after Android keyboard closes`
- `f21caaa3f7015fa34133785f741945ac5d2177ca fix: refresh stale Android status icons through the current rendered route`
- `04464397764ff5eda4d95dd8ea4301fd49381438 fix: refresh native Android status tint without overwriting the current Flutter style`
- `e4387928fa6b1c998bfa6afac15fb641a7f9e8a5 fix: restore Vivo status icons after returning from a keyboard route`

随后为本轮文档独立提交；其SHA由实际Git核对并随交付说明给出，不在文档里自引用。所有阶段包均保留，最终R7的源码、完整测试和实机覆盖边界见[M3_SELF_ACCEPTANCE.md](M3_SELF_ACCEPTANCE.md)及[evidence/m3-food-trust.json](evidence/m3-food-trust.json)。

完整本地差异冻结到`.tools/m3-upload-review.diff`，末态文件摘要在`.tools/m3-upload-review-summary.json`；这两项只留本地，不上传。当前业务提交e4387928，后续交付仅改文档，lib与Android树保持。

## 为什么需要本次确认

此前GitHub文件树写入被自动审批拒绝，理由为：大量源码和文档可能包含私有信息，缺少可信用户内容对具体仓库及完整载荷的授权。M3远端分支虽已建立，源码文件仍未上传，没有以其他接口绕过。本次只请求上述46个路径、本轮10个业务提交及交付文档到指定仓库/开发分支的确认，不是整个目录或其他账号操作的笼统授权。
