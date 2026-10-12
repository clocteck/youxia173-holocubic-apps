# youxia173-holocubic-apps

HoloCubic 黄金矿工应用，原作者为游侠173，由 clocteck 维护此 fork。

当前版本为 1.2.10：支持中文（简体、繁体）和英文，非中文或无法识别的设备语言默认英文；资源按应用目录动态解析。本仓库只维护黄金矿工，不包含 HID Pad 服务。

## 黄金矿工

| 目录 | 内容 |
| --- | --- |
| `gold-miner/package/` | 设备运行文件，含 `main.lua`、`app.info`、`info.html`、图标及资源 |
| `gold-miner/src/` | 开发说明、打包脚本及回归测试，不部署到设备 |
| `gold-miner/src/docs/` | 安装步骤和按键说明 |
| `gold-miner/src/dist/` | 完整安装包及上游历史安装包 |

直接复制 `gold-miner/package/` 中的内容到设备 `/sd/apps/gold_miner/`，不要把 `package` 目录本身复制上去。也可解压 [1.2.10 完整安装包](gold-miner/src/dist/黄金矿工_1.2.10_完整安装包.zip)，把其中的 `gold_miner` 文件夹放入 SD 卡的 `apps` 目录。

详见 [安装说明](gold-miner/src/docs/安装说明.md) 和 [开发与测试说明](gold-miner/src/README.md)。
