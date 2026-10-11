# youxia173-holocubic-apps

游侠173 的 HoloCubic 社区应用。每个应用一个目录，之后的新应用也放在这个仓库里。

## 黄金矿工

| 目录 | 内容 |
| --- | --- |
| `gold-miner/代码/` | 应用根目录，对应设备 `/sd/apps/gold_miner/` |
| `gold-miner/安装包/` | 完整安装包，首次安装和覆盖更新都用这一份 |
| `gold-miner/说明/` | 安装步骤和按键 |

解压安装包，把里面的 `gold_miner` 文件夹放到 SD 卡的 `apps` 目录，不要多套一层。

## 网页手柄

在官方 HID Pad 上增加网页接管，当前版本 1.1.4。

| 目录 | 内容 |
| --- | --- |
| `hidpad/代码/` | 应用根目录，对应设备 `/sd/apps/hidpad/` |
| `hidpad/安装包/` | 更新包。设备上已有官方手柄服务时使用 |
| `hidpad/说明/` | 按键、改键和接管说明 |

这是更新包，不包含 `modules/hidpad.so` 和 `config.json`，安装时不要覆盖这两份设备文件。打开 `http://设备IP/hidpad/remote/` 即可使用。
