# M1 核心记录原型

这是可直接打开的独立 HTML/CSS/JavaScript 设计样例，不属于正式 Flutter 页面。食品与营养数值为示例，扫码不调用相机，搜索不连接任何食品 API。操作状态只保留在当前浏览器标签页；关闭标签页可能丢失，不要用它记录真实饮食。

第四版：创建食品直接填写包装大小、单份份量、营养基准三个独立g/mL数值；记录时只输入实际数量和切换单位，不列预设数量。条码旁有扫码按钮，模拟识别后回填数字，不覆盖表单。原App已实现真实扫码回填，正式开发复用它。

第四版使用新的示例状态命名空间v4；前三版的v1浏览器状态仍保留，不覆盖删除。

## 预览

直接在浏览器打开同目录 `index.html`。`overview.html` 同时展示四个页面，完整交互和风格切换在 `index.html`。

如需通过本地地址预览，在仓库根目录运行以下命令。它只向本机提供当前仓库文件，运行期间占用8815端口，不安装任何 SDK；结束后在该终端按 Ctrl+C 关闭服务。

```sh
python3 -m http.server 8815 --bind 127.0.0.1 --directory .
```

浏览器访问 `http://127.0.0.1:8815/docs/china-fork/prototype/index.html`。

界面外的评审区可以切换配色、深色、字体、模拟搜索状态或重置。`?standalone=1&screen=detail` 可查看单独页面；screen 支持 home/search/detail/edit，style 支持 clear/warm，theme 支持 light/dark。趋势和我的只保留导航位置。

## 复核

计算测试使用 Node 自带测试工具，不需要安装项目依赖。在仓库根目录执行：

```sh
node --test docs/china-fork/prototype/model.test.cjs
```

`verify-browser.js` 和 `capture-review.js` 是 Playwright CLI 的 `run-code` 回调脚本，基于8815本地预览地址运行。前者检查完整操作与布局，后者输出截图和对比度数据。它们只操作本原型，不使用已有账号或浏览器个人资料。

若环境已有 Playwright CLI 与 Chrome，可先创建独立会话，再将脚本内容作为一个参数传给 `run-code`。下列命令会启动专用浏览器；缺少 CLI 或 Chrome 时需先自行配置，不应把浏览器无法启动当作测试通过。截图命令会覆盖 `output/playwright/m1/` 中同名的原型截图。

```sh
mkdir -p output/playwright/m1
playwright-cli -s=ont-m1 open http://127.0.0.1:8815/docs/china-fork/prototype/index.html --browser chrome
playwright-cli -s=ont-m1 run-code "$(cat docs/china-fork/prototype/verify-browser.js)"
playwright-cli -s=ont-m1 run-code "$(cat docs/china-fork/prototype/capture-review.js)"
playwright-cli -s=ont-m1 close
```

检查输出中不得出现 `### Error`，不能仅凭命令退出码认定通过。仓库提交的结果和边界见 [M1_VALIDATION.md](../M1_VALIDATION.md)。本轮 macOS 受限环境实际使用临时 npm 缓存和独立浏览器服务目录，未改变 Flutter 工具链。

## 素材与维护

图片复用原仓库已有演示素材，署名与来源见 [M1_DESIGN.md](../M1_DESIGN.md)。没有使用 YAZIO 专有素材。图标是原型内的线性 SVG；正式开发可映射已有 Material 图标，不需引入新依赖。

`model.js` 仅表达原型数值与快照规则，不能直接作为改写原 App 营养算法的依据。任何生产模型或结构变更须另行设计迁移与兼容测试。本原型随仓库按 GPL-3.0 提供。


第五版（m1-r5-recording）：依据2026-10-15用户修订，仅记录饮食摄入。首页取消目标/剩余/目标进度，保留实际摄入和四餐汇总；“我的”改为设置。没有身体资料步骤或免责声明弹窗。数据模型不变，保留v4示例状态，不清空既有浏览器记录。此版还不是Flutter首页或首次启动改造的交付。
