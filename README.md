# SubBoost on Android：免 Root 安卓部署指南

**基于 DroidDesk 与 PRoot 的免 Root 部署实践**

通过 DroidDesk、PRoot 和 Cloudflare Tunnel，在未 Root 的 Android 设备上自托管 SubBoost，探索闲置手机的低成本再利用。

> 社区部署指南，非 SubBoost 官方项目；目前仅在荣耀 20S 上实测。

建议 GitHub 仓库名：`subboost-on-android`。

## 荣耀 20S 实践：让闲置手机成为 SubBoost 轻量服务器

如果只是想运行一个订阅管理工具，专门购买 NAS 的设备和硬盘成本可能偏高。对于已经有闲置手机的人，用现有设备承载轻量服务，是一种更低门槛的旧设备再利用方式。本文记录一次荣耀 20S 的实际部署，并整理了过程中遇到的兼容性问题。

**这不是完整 NAS 的替代品，也不是适配所有安卓手机的一键教程。** 手机缺少 NAS 的存储扩展、冗余和成熟的长期运维能力；本方案更适合个人使用、学习和实验。本文没有对功耗、并发性能或长期稳定性做基准测试，也不宣称“零成本”“永不掉线”。

## 目录

- [AI 辅助声明](#ai-辅助声明)
- [项目来源与贡献边界](#项目来源与贡献边界)
- [实测环境与适用范围](#实测环境与适用范围)
- [原理与几个重要概念](#原理与几个重要概念)
- [开始前的准备](#开始前的准备)
- [第一步：准备脚本和 SSH 公钥](#第一步准备脚本和-ssh-公钥)
- [第二步：安装 Debian 内的依赖](#第二步安装-debian-内的依赖)
- [第三步：电脑连接手机](#第三步电脑连接手机)
- [第四步：构建和启动 SubBoost](#第四步构建和启动-subboost)
- [第五步：通过 Cloudflare Tunnel 访问公网](#第五步通过-cloudflare-tunnel-访问公网)
- [第六步：重启恢复与日常维护](#第六步重启恢复与日常维护)
- [踩坑记录](#踩坑记录)
- [熄屏挂机与电池保护](#熄屏挂机与电池保护)
- [安全与备份](#安全与备份)
- [验证结果与未验证事项](#验证结果与未验证事项)
- [参考资料与致谢](#参考资料与致谢)

## AI 辅助声明

本教程及配套脚本在整理过程中使用了 **OpenAI Codex（AI 编程助手）**，辅助完成文档撰写、命令与脚本编写、兼容性问题排查和测试检查。用户提供了实际设备、部署需求、操作反馈及部分项目来源；本文基于这次协作部署的记录整理，不应理解为全部由人工独立编写。

**AI 生成或辅助修改不等于已经验证。** 本文区分了实际部署中验证过的结果与尚未验证的事项；整理后的公开脚本尚未在全新环境中完整重跑。具体范围请参阅[验证结果与未验证事项](#验证结果与未验证事项)。AI 输出可能存在错误、遗漏或版本差异，执行前请结合上游文档检查命令，备份重要数据，尤其留意权限、密钥和公网暴露设置。

AI 辅助不改变第三方项目的作者归属、版权或许可证要求，也不代表 OpenAI 或相关上游项目对本教程提供官方支持或背书。所使用的第三方工具与资料仍按本文的来源说明和参考资料予以引用。

## 项目来源与贡献边界

本文使用的是 **[SubBoost/subboost](https://github.com/SubBoost/subboost)**，不是本文作者开发的订阅管理程序。官方提供 [一键部署](https://docs.subboost.org/deploy/one-click) 和 [高级部署](https://docs.subboost.org/deploy/advanced) 文档，建议先了解它们。[1][2]

本方案依赖 DroidDesk、Termux 相关运行环境、PRoot / proot-distro、Debian、Node.js、PostgreSQL，以及 Cloudflare Tunnel。本文的工作是**把这些现有工具组合起来，记录手机适配、排错和部署流程**。以下共享内存参数也来自 PRoot 上游实现，并非本文发明。[3][4][5]

仓库内的 `scripts/` 是从本次部署辅助脚本整理出的公开示例，不是任何上游项目的官方安装器。它们只负责编排依赖、进程和配置，**不包含 SubBoost 源码、第三方二进制或本次部署的真实密钥**。第三方软件仍遵循各自许可证；引用不等于获得任意转载或重新许可的权利。

SubBoost 当前使用 **AGPL-3.0-only**。若修改 SubBoost 并通过网络向用户提供服务，应遵守其对应源代码提供义务，保留上游署名与许可证，不要移除原有来源信息。以 [上游 LICENSE](https://github.com/SubBoost/subboost/blob/v2.8.1/LICENSE) 为准。[1]

## 实测环境与适用范围

| 项目 | 本次部署 |
| --- | --- |
| 手机 | 荣耀 20S，8 GB 内存，ARM64 |
| Android Root / Bootloader 解锁 | 均不需要 |
| 安卓应用环境 | 已安装 DroidDesk，可进入其原生终端 |
| 最终 Linux 用户空间 | Debian 13，运行在 PRoot 内 |
| SubBoost | 2.8.1 |
| Node.js | 22.23.3，Linux ARM64 官方发行包 |
| 数据库 | PostgreSQL 17，专用实例 |
| 公网连接器 | cloudflared 2026.9.3，Linux ARM64 |
| 操作电脑 | Windows，使用 PowerShell 和 OpenSSH |

虽然最初手机上已有被称作 Ubuntu 的环境，**最终跑通的路径是 DroidDesk 内的 Debian 13**，不能据此声称 Ubuntu 流程也已验证。

没有完整记录 DroidDesk 和手机系统的版本，因此本文不能保证其他版本复现一致。DroidDesk 作者为 **orailnoor**，来源是 [orailnoor/DroidDesk](https://github.com/orailnoor/DroidDesk)，独立 Android 应用的下载入口为该仓库的 [Releases](https://github.com/orailnoor/DroidDesk/releases)。实测应用包名为 `com.orailnoor.droiddesk`。[3]

DroidDesk 仓库同时描述了独立 APK 和基于普通 Termux 的安装脚本，**本文对应独立 APK 的私有目录布局，不能混用两种方案的路径**。它是独立项目，并非 Termux、Termux:X11 或 Ubuntu 官方产品。作者还提供第三方软件清单和发布合规进度；本文仅引用来源，不为二进制发布的完整合规性背书。[3]

## 原理与几个重要概念

```text
浏览器
  |
  | HTTPS
  v
Cloudflare 边缘网络
  |
  | 手机主动建立的加密 Tunnel
  v
荣耀 20S / Android / DroidDesk
  |
  +-- PRoot + Debian
        +-- cloudflared
        +-- SubBoost / Node.js :3000
        +-- PostgreSQL :5433
        +-- 定时任务进程
```

- **不需要 Android Root**：PRoot 提供的是用户空间环境，不是刷入一个独立 Linux 内核。
- **Debian 中的 `root` 不等于手机已 Root**：它是 PRoot 的身份模拟，不会赋予安卓系统管理员权限。
- **不用 Docker**：未 Root 安卓通常不具备直接运行常规 Docker 所需的内核权限。本次采用源码构建。
- **不依赖 systemd**：本方案用脚本管理进程，不使用 `systemctl` 或 `cloudflared service install`。
- **不要求公网 IP**：Cloudflare Tunnel 由手机主动连接 Cloudflare，不需要路由器端口映射。[8]
- **PRoot 不是安全隔离沙箱**：不要把它当成隔离恶意程序的容器，也不要给陌生人共享这个运行环境。

> SubBoost 用于配置转换和管理，并不等于在手机上部署了代理出口。Tunnel 在这里仅发布 SubBoost 网页和接口，不是代理节点。[1]

## 开始前的准备

准备闲置手机、可靠网络和电源、足够的可用存储空间，以及一台便于输入命令的电脑。源码、npm 依赖和构建产物会占用数 GB 空间，开始前请检查 `df -h`，不要把闪存填满。

公网部分还需要：自己的域名、Cloudflare 账号，以及域名已使用 Cloudflare 的权威 DNS。如果只在本机使用，可以跳过公网部分。

全文严格区分三种命令位置：

| 标记 | 执行位置 |
| --- | --- |
| Windows PowerShell | 电脑终端 |
| DroidDesk 原生终端 | 手机应用提供的宿主终端，尚未进入 Debian |
| Debian 终端 | 已通过脚本或 SSH 进入手机的 Debian |

**不要在 Debian 内再次启动 PRoot。** 需要重新进入或切换 PRoot 用户时，先退出到 DroidDesk 原生终端。[4]

本文默认从一个没有 `/opt/subboost`、`/opt/subboost-data`、`/opt/subboost-tools` 的新 Debian 环境开始。已有部署请先备份，不能照着初始化步骤覆盖。

## 第一步：准备脚本和 SSH 公钥

### 1. 将本教程脚本放到手机

从本教程仓库下载文件，把 `scripts/` 中的全部文件放到手机 DroidDesk 的：

```text
$HOME/subboost-phone/
```

这是 **DroidDesk 原生终端中的 `$HOME`**，不是 Debian 的 `/root`。可以先用手机文件管理器下载、解压，再在 DroidDesk 允许访问的存储目录中复制文件。如果系统提示存储访问权限，请按应用实际界面处理。不要假定所有版本都能直接读取 `/sdcard`。

这些脚本请保留 LF 换行。文件夹内容应包括 `enter-debian.sh`、`bootstrap-debian.sh`、`run-services.sh`、`sshd_config`、`subboost` 和三个安装/构建辅助脚本。

### 2. 电脑生成专用 SSH 密钥

**Windows PowerShell：**

```powershell
ssh-keygen -t ed25519 -f "$HOME\.ssh\subboost_phone_ed25519"
Get-Content "$HOME\.ssh\subboost_phone_ed25519.pub"
```

可以给私钥设置口令。若同名密钥已存在，不要覆盖，换一个名称，并同步修改后续命令。找不到 `ssh-keygen` 时，在 Windows 的“可选功能”中安装 OpenSSH 客户端。

把 `.pub` 文件输出的**整行公钥**放到手机 `$HOME/subboost-phone/authorized_keys`。例如可以在原生终端中用文本编辑器编辑该文件。

**私钥文件不能上传到手机，也不能提交 GitHub。** `authorized_keys` 也不应作为所有读者共用的配置公开发布，仓库已经默认忽略它。

### 3. 确认已有 Debian 13

**DroidDesk 原生终端：**

```bash
printf '%s\n' "$PREFIX"
command -v proot-distro
proot-distro list
```

实测应用的前缀是 `/data/user/0/com.orailnoor.droiddesk/files/usr`。脚本通过 `$PREFIX` 获取实际位置，不要改成普通 Termux 的固定路径。

应能看到已安装、名称为 `debian` 的环境。如果没有，先使用该版本 DroidDesk 提供的发行版安装功能完成 Debian 安装；具有标准 proot-distro 命令的版本通常提供 `proot-distro install debian`。**不同 DroidDesk 版本的首次安装界面未在本文重新验证**，遇到路径或加载器错误时不要继续套用普通 Termux 的安装命令。

## 第二步：安装 Debian 内的依赖

**DroidDesk 原生终端：**

```bash
bash "$HOME/subboost-phone/enter-debian.sh" --root /bin/bash
```

**进入 Debian 后：**

```bash
cat /etc/os-release
uname -m
bash /mnt/subboost-bootstrap/bootstrap-debian.sh
exit
```

预期为 Debian 13、`aarch64`。不是这个组合时，先核对依赖和下载架构，不要直接执行安装脚本。

脚本会安装 OpenSSH、Git、Python、PostgreSQL 17 等依赖，创建 `subboost` 用户，拉取 SubBoost `v2.8.1`，并下载、校验官方 Node.js ARM64 包。[1][6][7]

安装脚本会阻止创建 Debian 默认数据库集群，因为本文使用独立的 `/opt/subboost-data/postgres`。它也会拒绝覆盖已存在的部署目录。中途失败后，先检查错误和已创建文件，不要删除目录后盲目重跑。

### 两个最重要的兼容设置

`enter-debian.sh` 在运行服务时使用：

```bash
--user subboost
--env "PROOT_DONT_SHARE_LIBANDROID_SHMEM=1"
```

第一个参数让**整个 PRoot 会话**以普通用户身份运行，避免 PostgreSQL 的用户/文件所有者检查失败。只在一个模拟 root 的会话中执行 `su` 或 `runuser`，不一定足以解决所有者映射问题。

第二个参数是 PRoot 自带的选项：让其不用与 `libandroid-shmem` 共享的模式，而走内部共享内存处理路径；**不是关闭所有共享内存**。本次排查发现，重定位的 DroidDesk 环境会在原模式下触发共享内存助手卡住，切换模式后数据库初始化成功。[5]

此外还显式传入 `PROOT_TMP_DIR`、`PROOT_LOADER` 和 `PROOT_LOADER_32`。在实测版本中，单纯在宿主终端 `export` 部分变量，不足以确保它们被 proot-distro 传入后续环境。[4]

## 第三步：电脑连接手机

**DroidDesk 原生终端：**

```bash
bash "$HOME/subboost-phone/enter-debian.sh"
```

保持这个终端打开。它会以 `subboost` 用户启动 Debian 内的 SSH，监听 **8023**。看到 `listening` 和主机密钥指纹后，再从电脑连接。

手机和电脑应在同一可信局域网。手机 Wi-Fi 详情里可以查看局域网 IP。以下 `192.168.1.100` 只是示例，必须替换。

**Windows PowerShell：**

```powershell
ssh -i "$HOME\.ssh\subboost_phone_ed25519" -p 8023 subboost@192.168.1.100
```

第一次连接时核对电脑显示的主机密钥指纹，确认与手机一致后再接受。出现主机密钥变化警告时，先调查原因，不要直接关闭检查。

本示例只允许 `subboost` 用户使用公钥登录，不允许密码或 root SSH 登录。`UsePAM no`、`StrictModes no` 是针对本次 PRoot 环境的兼容配置，不应照搬到正常公网 Linux 服务器。PRoot 内的权限检查不能提供与真实多用户系统相同的隔离能力。

**不要给 8023 做公网端口映射，也不要在后面的 Tunnel 中发布它。** 原始排错过程曾用到额外的宿主 SSH 8022，但那不是最终方案必需步骤，本文已省略。

## 第四步：构建和启动 SubBoost

以下均在**电脑 SSH 连接后的 Debian 终端**执行：

```bash
export PATH=/opt/subboost-tools/node/bin:$PATH
cd /opt/subboost
node --version
npm ci --no-audit --no-fund
bash /opt/subboost-tools/build-app.sh
python3 /opt/subboost-tools/subboost prepare
npm --prefix /opt/subboost/local run db:migrate
python3 /opt/subboost-tools/subboost start
python3 /opt/subboost-tools/subboost status
curl -fsS http://127.0.0.1:3000/api/health/ready
```

**逐条执行，上一条成功后再执行下一条。** 不要在构建没有结束时重复运行。构建脚本给 Node 堆设置了 2048 MB 上限，但这不是整个构建进程的内存上限。具体耗时取决于手机温度、网络和存储性能。

`prepare` 会在手机本地生成随机数据库密码、加密密钥、JWT 密钥、定时任务密钥及管理员初始化令牌，写入权限受限的 `/opt/subboost/local/.env`。不要把整份 `.env` 贴到论坛或提交 GitHub，也不要每次启动都重新生成 `ENCRYPTION_KEY`。

如果只做本地部署，也执行一次 `python3 /opt/subboost-tools/subboost enable`，让后续运行手机启动脚本时自动带起应用；没有 Tunnel 令牌文件时，不会启用隧道。

数据库采用专用端口 **5433**，只监听 `127.0.0.1`，TCP 使用 SCRAM 密码认证；Unix socket 放在私有目录中。本示例对该 Unix socket 使用本地 trust，只适用于这个受信任的单应用环境，不适用于多人共用主机。[7]

成功时健康接口应返回：

```json
{"ok":true,"database":"ready"}
```

### 在电脑浏览器初始化管理员

**公开脚本默认让网页只监听 `127.0.0.1:3000`。** 原始实测曾使用 `0.0.0.0` 方便局域网诊断，公开版本收紧为本机监听。电脑需要通过 SSH 转发访问。

在电脑另开一个 PowerShell 窗口：

```powershell
ssh -N -L 3000:127.0.0.1:3000 -i "$HOME\.ssh\subboost_phone_ed25519" -p 8023 subboost@192.168.1.100
```

该窗口一直没有新输出通常是正常的，保持它运行。如果电脑 3000 端口已被其他服务使用，改成 `-L 13000:127.0.0.1:3000`，浏览器也相应使用 13000，不要停止无关服务。

在之前的 Debian SSH 窗口执行：

```bash
python3 /opt/subboost-tools/subboost setup-url
```

在电脑浏览器打开命令输出的完整链接，例如 `http://127.0.0.1:3000/login#setup-token=...`。若用了 13000 转发，只替换链接中的端口，保留原有片段。该链接含私有令牌，**不要分享、公开截图或提交 GitHub**。

设置管理员账号和至少 10 位密码。建议先完成管理员初始化，再将服务发布到公网。只打开普通 `/login` 而没有初始化令牌时，创建管理员按钮不可用，是安全限制，不是部署失败。如果只是更改了地址中的 `#setup-token` 片段，页面没有读取新值，可以刷新一次。

## 第五步：通过 Cloudflare Tunnel 访问公网

下文使用 `subboost.example.com`，请替换成自己的子域名。无需开放路由器入站端口。[8]

### 1. 创建 Tunnel

登录 Cloudflare 后进入 Zero Trust / Cloudflare One。界面名称可能变化，本次入口为：

```text
网络 → 连接器 → 创建隧道 → Cloudflared
```

首次使用可能需要开通计划。个人小规模使用可先核对 **Zero Trust Free** 的当前额度和条件，不要误选付费计划。是否要求付款资料或接受条款，以自己账号当时的页面为准；本次 Free 激活页面显示基础费用为 `$0/月`，不能由此推断所有相关服务或未来超额用量都永久免费。

隧道可以命名为 `subboostphone`。只创建这一项所需资源，不修改已有域名和其他隧道的配置。

### 2. 安装手机 ARM64 客户端

**Debian 终端：**

```bash
python3 /opt/subboost-tools/install-cloudflared.py
```

脚本从 [Cloudflare 官方发布页](https://github.com/cloudflare/cloudflared/releases) 获取 Linux ARM64 包，并检查发布元数据中的 SHA256。若 GitHub API 限流或没有提供摘要，脚本会停止，不会忽略校验继续安装。[9]

公开安装脚本读取执行时的最新稳定版本，因此不保证仍为本次实测的 2026.9.3。更新后需要重新做连接测试，不能把客户端的新版本默认为已验证。

### 3. 安全保存令牌

Cloudflare 的安装命令中包含一个很长的连接器令牌。**只复制令牌本身**，不是整条 `service install` 命令。不要在这个 PRoot 环境执行需要 systemd 的服务安装命令，也不要把令牌直接放在进程命令行或 shell 历史中。

在 Debian 的 Bash 终端依次执行：

```bash
umask 077
read -r -s -p 'Paste tunnel token, then press Enter: ' TUNNEL_TOKEN
printf '\n'
printf '%s' "$TUNNEL_TOKEN" > /opt/subboost-data/tunnel-token
unset TUNNEL_TOKEN
chmod 600 /opt/subboost-data/tunnel-token
```

在出现提示后粘贴令牌，再按回车。输入不显示是正常现象。令牌拥有运行对应隧道的权限，泄露后应在 Cloudflare 端轮换。[8]

### 4. 配置公开主机名

在“已发布应用程序”或“Public Hostname”中配置：

| 字段 | 示例 |
| --- | --- |
| 子域名 | `subboost` |
| 域 | `example.com` |
| 路径 | 留空 |
| 服务类型 | **HTTP** |
| 服务 URL | `127.0.0.1:3000` |

**这里是 HTTP，不是 HTTPS。** 这是手机内 cloudflared 到本机网页的连接；公网访问仍使用 HTTPS，手机到 Cloudflare 的隧道也有加密。不要用关闭证书校验来掩盖协议选错的问题。

DNS 通常由向导自动创建。若提示同名记录冲突，先核对已有记录用途，不要删除或覆盖其他服务。

### 5. 切换应用地址并启动隧道

先在 Debian 终端设定自己的域名：

```bash
python3 /opt/subboost-tools/subboost public-url https://subboost.example.com
python3 /opt/subboost-tools/subboost enable
python3 /opt/subboost-tools/subboost stop
python3 /opt/subboost-tools/subboost start
```

`public-url` 只更新本机 `APP_URL`，**不会替你创建 DNS 或 Cloudflare 路由**。`enable` 会让手机启动脚本在下次运行时启动服务；存在令牌文件时同时启用隧道。

本示例将 cloudflared 设置为 HTTP/2，并仅在本机 `20241` 端口提供状态接口。检查：

```bash
curl -fsS http://127.0.0.1:20241/ready
curl -fsS https://subboost.example.com/api/health/ready
curl -sS -o /dev/null -w '%{http_code}\n' https://subboost.example.com/api/subscriptions
```

在没有登录 Cookie 的情况下，最后一个订阅管理接口应返回 **401**；健康接口则应返回数据库就绪。这些检查分别验证隧道、应用和鉴权，不应只凭“进程启动了”就判断公网部署成功。

再用另一个网络，例如另一台手机的移动数据，打开公网域名，以确认不是只在家庭局域网内可用。

## 第六步：重启恢复与日常维护

**手机重启后，打开 DroidDesk，在原生终端执行：**

```bash
bash "$HOME/subboost-phone/enter-debian.sh"
```

启用过 `enable` 后，它会启动 SSH、PostgreSQL、SubBoost、定时更新和已配置的 Tunnel。保持该终端运行，不要重复打开多个实例。

这叫“运行启动脚本后恢复服务”，**不是 Android 开机自启动，也不是进程崩溃后自动拉起**。`--no-autoupdate` 也意味着 cloudflared 需要手动维护更新。

正常停止时，在手机运行启动脚本的那个终端按 `Ctrl+C`。不要直接强制清除 DroidDesk 数据，也不要在数据库写入时反复杀进程。电脑 SSH 断开与手机宿主终端退出不是同一件事；部署完成后不需要电脑持续运行。

**Debian 终端常用命令：**

```bash
python3 /opt/subboost-tools/subboost status
tail -n 50 /opt/subboost-data/logs/app.log
tail -n 50 /opt/subboost-data/logs/postgres.log
tail -n 50 /opt/subboost-data/logs/tunnel.log
tail -n 50 /opt/subboost-data/logs/cron.log
```

查看日志后再分享时要脱敏：日志也可能含订阅地址、主机名或其他隐私信息。示例未配置日志轮转，需要定期检查磁盘空间。

定时任务脚本大约每 6 分钟调用一次订阅更新接口，每 10 轮调用一次规则索引更新接口；任务自身耗时会拉长间隔。这是本文辅助脚本的调度频率，不是官方承诺的实时更新频率。

## 踩坑记录

| 现象 | 排查方向与处理 |
| --- | --- |
| `Address already in use` / 无法绑定 8023 | 通常是旧 SSH 仍在运行。回到原来的手机终端停止它，不要另开窗口反复启动。需要终止进程时先查明 PID 和用途，不能照抄别人的 PID 或使用无差别 `pkill`。 |
| 先显示 `SSH ready`，随后绑定失败 | 旧脚本的提示打印太早。本文脚本在启动后检查进程是否仍在运行，仍应结合 `listening` 日志和实际连接判断。 |
| PostgreSQL 提示不能以 root 运行或目录所有者不对 | 退出原 PRoot 会话，以 `--user subboost` 重进。PRoot 的所有者映射与真实 Linux 不同。 |
| `initdb` 停在选择连接数，`proot --shm-helper` 占用 CPU | 本次由 `libandroid-shmem` 路径兼容问题引起，加入 `PROOT_DONT_SHARE_LIBANDROID_SHMEM=1` 并重启整个 PRoot 会话后解决。其他设备需单独诊断。 |
| 只有 `PG_VERSION` 文件却启动不了数据库 | 它可能是失败初始化留下的目录，不能仅靠这个文件认定成功。应检查 `global/pg_control` 和日志。本文脚本只自动保留并改名一种已知不完整目录，其余情况会停止要求人工检查。 |
| 修改启动脚本后仍表现相同 | 已运行的 PRoot 不会自动读取新的环境变量，需要先正常停止，再重新启动。 |
| 报 `systemctl`、systemd 不可用 | 本方案不用 systemd，使用配套管理脚本和 `cloudflared tunnel run`。 |
| Cloudflare 提示 1033 | 重点检查隧道是否连接、令牌是否正确和手机网络，不要先修改数据库。 |
| Cloudflare 返回 502 | 检查本机健康接口、服务端口和 HTTP/HTTPS 类型，确认源站为 `http://127.0.0.1:3000`。 |
| 锁屏后网站失联 | 检查系统后台限制、网络休眠、手机发热和进程存活，不能简单认定“锁屏密码导致服务停止”。 |

## 熄屏挂机与电池保护

目标是**熄屏后服务继续运行**，不必为了这个目的取消手机锁屏密码。

荣耀系统的入口名称随版本变化，可检查以下设置：允许 DroidDesk 自启动和后台活动、不对它进行电池优化、关闭省电模式、允许休眠时保持网络连接，并在最近任务列表中锁定该应用。

若原生终端支持，可以先检查：

```bash
command -v termux-wake-lock
```

只有命令存在并且该 DroidDesk 版本支持相应唤醒机制时，才尝试 `termux-wake-lock`。**不能把普通 Termux 的行为直接视作 DroidDesk 的保证**。熄屏 15 分钟、1 小时后分别从另一设备检查健康接口。

### 注：电脑投屏时关闭手机屏幕

scrcpy 是独立的开源投屏工具，不是本部署的依赖。[10] 配置 USB 调试并授权自己的电脑后，可以运行：

```powershell
scrcpy --turn-screen-off --stay-awake
```

这适用于电脑仍连接手机时；`--stay-awake` 的作用依赖供电条件，不能当作拔线后仍然有效的独立保活方案。

## 安全与备份

1. 只发布需要的 SubBoost HTTP 服务，不发布数据库、SSH、桌面或整个局域网网段。
2. 使用强管理员密码，保护 Tunnel 令牌、SSH 私钥、`.env` 和初始化链接。
3. 不要把 `ENCRYPTION_KEY` 当成可以随时替换的普通设置；丢失后可能无法解密已有业务数据。
4. 安装只从可核实的上游来源获取，更新前先备份；固定版本是复现起点，不代表可以永不安装安全更新。
5. 订阅链接和生成配置可能本身包含访问凭据，不能认为“能打开的 URL 就没有隐私”。遵守相关法律法规和服务条款。

### 备份示例

**Debian 终端：**

```bash
umask 077
backup_dir="$HOME/subboost-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 "$backup_dir"
/usr/lib/postgresql/17/bin/pg_dump \
  -h /opt/subboost-data/run -p 5433 -U subboost_admin \
  -Fc -f "$backup_dir/subboost.dump" subboost
cp /opt/subboost/local/.env "$backup_dir/app.env"
chmod 600 "$backup_dir/app.env" "$backup_dir/subboost.dump"
printf '%s\n' "$backup_dir"
```

确认 `pg_dump` 成功后，用 SCP 将备份保存到另一台设备的受保护目录，并加密保管。`app.env` 含敏感密钥，不要提交到教程仓库。仅把备份留在手机里，不能抵御卸载应用、清除数据或闪存故障。

示例只备份业务数据库和应用配置；SSH 密钥、Tunnel 凭据和其他运行配置需要另外受保护地保存，或者在恢复时重新生成、重新授权。恢复前应在隔离环境里用 PostgreSQL 的 `pg_restore` 做演练，不能只因有一个 `.dump` 文件就声称备份可用。[7]

## 验证结果与未验证事项

**原始设备上已验证：**

- SubBoost 2.8.1 的依赖安装和生产构建成功。
- PostgreSQL 17 初始化成功，6 项 Prisma 迁移全部应用。
- 公网 HTTPS 健康接口返回 `ok: true`、`database: ready`。
- 无登录凭据的订阅管理 API 返回 401。
- Cloudflare 隧道健康，观测到 4 条就绪连接。
- 两类定时更新接口首次调用均返回 200；这不等于完整业务数据或所有订阅源都已验证。
- 管理员初始化页面正常读取私有初始化令牌。
- 原始部署的最终管理员创建结果及账户内全部业务操作正常。
- 重复执行服务启动命令时没有产生第二套已管理服务进程。

**尚未验证或不能保证：**

- 荣耀不同系统版本、其他手机和其他 DroidDesk 版本的兼容性。
- Android 冷启动后的全流程无人值守恢复、系统杀后台后的自动恢复。
- 数天或数月连续运行、真实订阅业务的完整回归、高并发和存储寿命。
- 本仓库经过整理的全新安装流程在清空设备上的完整重放。

**公开脚本与原始部署存在小幅差异**：域名改为参数、网页默认只监听本机、安装步骤合并、Node 和 SubBoost 固定版本、SSH 只允许普通用户。这些改动便于公开复用，但不能冒充在所有设备上重新实测过的官方安装器。

整理时已检查 5 个 Shell 脚本的 Bash 语法、Python 脚本语法，并通过 6 项离线单元测试。这些检查不等于设备端集成测试。读者可以在本教程仓库根目录运行：

```bash
python -m unittest discover -s tests -v
```

## 结语

这次实践的价值不在于“旧手机等于 NAS”，而在于：**在 NAS 购置成本对轻量需求偏高时，让已有的闲置设备承担它胜任的小任务。** 保留对成本、维护和可靠性的判断，比单纯追求“跑起来了”更重要。

## 参考资料与致谢

以下为上游资料。正文步骤是本次实践的整理，不代表上游官方推荐或承诺支持荣耀 20S。

1. **SubBoost 项目及贡献者**：[官方仓库](https://github.com/SubBoost/subboost)、[v2.8.1](https://github.com/SubBoost/subboost/tree/v2.8.1)、[许可证](https://github.com/SubBoost/subboost/blob/v2.8.1/LICENSE)。应用功能、源代码及原有设计归上游项目及相应权利人。
2. **SubBoost 官方部署文档**：[一键部署](https://docs.subboost.org/deploy/one-click)、[高级部署](https://docs.subboost.org/deploy/advanced)。本文从官方部署入口出发，改为针对无 Root 手机的源码部署。
3. **DroidDesk / orailnoor**：[作者仓库](https://github.com/orailnoor/DroidDesk)、[Releases](https://github.com/orailnoor/DroidDesk/releases)、[GPL-3.0 许可证](https://github.com/orailnoor/DroidDesk/blob/main/LICENSE)、[第三方声明](https://github.com/orailnoor/DroidDesk/blob/main/THIRD_PARTY_NOTICES.md)、[合规进度](https://github.com/orailnoor/DroidDesk/blob/main/COMPLIANCE.md)。它使用了修改过的 Termux:X11 组件；相关上游为 [Termux](https://github.com/termux/termux-app) 和 [Termux:X11](https://github.com/termux/termux-x11)，不能将这些项目的工作归为本文原创。
4. **PRoot / proot-distro 项目及贡献者**：[Termux PRoot](https://github.com/termux/proot)、[proot-distro](https://github.com/termux/proot-distro)。用户空间 Linux、路径映射和运行参数来源。
5. **共享内存实现依据**：[PRoot sysvipc.c](https://github.com/termux/proot/blob/master/src/extension/sysvipc/sysvipc.c)、[sysvipc_shm.c](https://github.com/termux/proot/blob/master/src/extension/sysvipc/sysvipc_shm.c)、[libandroid-shmem](https://github.com/termux/libandroid-shmem)。`PROOT_DONT_SHARE_LIBANDROID_SHMEM` 来自这些上游实现；主分支代码可能随时间变化。
6. **Debian / Node.js**：[Debian](https://www.debian.org/)、[Node.js v22.23.3 官方文件及校验和](https://nodejs.org/dist/v22.23.3/)。运行环境和官方发行包来源。
7. **PostgreSQL 文档**：[版本 17](https://www.postgresql.org/docs/17/)、[initdb](https://www.postgresql.org/docs/17/app-initdb.html)、[备份](https://www.postgresql.org/docs/17/backup.html)。数据库初始化、认证和备份方式的参考。
8. **Cloudflare Tunnel 文档**：[Tunnel 概述](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/)、[远程管理隧道](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/)。公网连接与路由配置的依据。
9. **Cloudflare cloudflared**：[官方仓库](https://github.com/cloudflare/cloudflared)、[发行版](https://github.com/cloudflare/cloudflared/releases)。隧道客户端来源。
10. **Genymobile scrcpy**：[官方仓库](https://github.com/Genymobile/scrcpy)、[屏幕控制说明](https://github.com/Genymobile/scrcpy/blob/master/doc/device.md)。可选投屏和熄屏操作的参考。
