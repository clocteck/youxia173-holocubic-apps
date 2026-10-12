# youxia173-holocubic-apps

HoloCubic 黄金矿工应用，原作者为游侠173，由 clocteck 维护此 fork。

当前版本为 1.2.12：介绍页内嵌 Base64 图标，并在页脚提供原作者 GitHub 地址。保留原版简体中文、繁体中文、英文和日文语言系统、资源相对路径及 `package/src` 结构。本仓库只维护黄金矿工，不包含 HID Pad 服务。

## 黄金矿工

| 目录 | 内容 |
| --- | --- |
| `gold-miner/package/` | 设备运行文件，含 `main.lua`、`app.info`、`info.html`、图标及资源 |
| `gold-miner/src/` | 开发说明、打包脚本及回归测试，不部署到设备 |
| `gold-miner/src/docs/` | 安装步骤和按键说明 |
| `gold-miner/src/dist/` | 完整安装包及上游历史安装包 |

直接复制 `gold-miner/package/` 中的内容到设备 `/sd/apps/gold_miner/`，不要把 `package` 目录本身复制上去。也可解压 [1.2.12 完整安装包](gold-miner/src/dist/黄金矿工_1.2.12_完整安装包.zip)，把其中的 `gold_miner` 文件夹放入 SD 卡的 `apps` 目录。

详见 [安装说明](gold-miner/src/docs/安装说明.md) 和 [开发与测试说明](gold-miner/src/README.md)。
