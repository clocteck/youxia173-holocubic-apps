# 黄金矿工打包与回归检查

运行文件位于 `../package/`；本目录放开发工具、说明和安装包归档，不部署到设备。

```text
gold-miner/
├── package/
│   ├── app.info
│   ├── info.html
│   ├── main.lua
│   ├── main.png
│   ├── assets/
│   └── font/
└── src/
    ├── README.md
    ├── build_package.py
    ├── test_package.py
    ├── test_info.cjs
    ├── docs/
    └── dist/
```

## 相对资源路径

- 字体和图片声明使用 `font/...`、`assets/...`。
- 固件的字体文件路径以 SD 根目录为基准，LVGL 图片还需要 `S:` 驱动前缀，不能直接把 `assets/...` 交给它们。
- `main.lua` 从 `app.current().entry` 获取实际目录，将资源相对路径转换为 LVGL 可用路径，支持 `/apps/...`、`/sd/apps/...` 和 `S:/apps/...` 入口形式。
- 不再读取其他应用的字体；系统语言配置仍保留设备级固定路径。
- 诊断页面使用当前 `app.route_base()`，应用目录改名后不会占用原应用的路由。

## 打包和测试

依赖：Python 3.9+、`lupa`（包含 Lua 5.4）、Node.js。以下命令从仓库根目录运行：

```sh
python gold-miner/src/build_package.py
python gold-miner/src/test_package.py
node gold-miner/src/test_info.cjs
```

打包脚本按 `package/app.info` 的版本号生成 `src/dist/` 下的完整 ZIP，压缩包内只有 `gold_miner/` 及 `package/` 中的运行文件，不额外嵌套 `package` 目录。

回归测试在 Lua 5.4 中执行真实游戏脚本，模拟固件的绘图、输入及定时器接口，覆盖：

- 三种入口路径形式及目录改名后的资源、诊断路由和资源释放；
- 机身 HOME 短按/长按、手柄 SELECT/HOME 上升沿退出；
- 原版简繁中文、英文、日文识别，以及其他语言或配置缺失/损坏时默认简体中文；
- A/START/上键开始游戏，确认这些按键不会退出；
- 全部资源存在、元数据、版本、ZIP 与源码字节一致；
- 介绍页 36 个翻译字段、中英文切换及无脚本默认文案一致。

这些是离线回归测试，不代表实体设备的渲染、蓝牙按键和固件兼容性已实测。
