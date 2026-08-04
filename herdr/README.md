# herdr 无头服务器提醒三件套

herdr 跑在无头服务器上、通过 mosh/ssh 远程使用时，agent 状态提醒存在三个断点：

1. **提示音无声**——herdr 的提示音走本地 MP3 播放（`paplay` 等），无声卡的服务器上必然失败；
2. **toast 弹窗默认关闭**；
3. **窗口标题无全局状态**——herdr 只转发焦点 pane 的标题，后台 pane 的 agent 在干什么外层完全不可见。

本目录三个文件分别补上这三个断点。已在多台 Ubuntu 无头服务器 + mosh 远程场景验证。

## 1. `pw-play` — BEL 提示音 shim

假 MP3 播放器：herdr 每次"播提示音"时实际向 client 终端写 BEL（`\a`）。BEL 属于终端数据流本身,mosh/ssh 原生转发,最终由**你本地终端**发出系统提示音——和 Claude Code `terminal_bell` 通知同一条链路。

原理依据 herdr `src/sound.rs`（0.8.0）：Linux 播放器按 `paplay → pw-play → ffplay → mpg123 → mpv` 顺序 PATH 探测,exit 0 即成功,每次重新探测。无头服务器上 `paplay` 缺失或必失败,shim 以 `pw-play` 之名顺位命中,真实系统组件零改动。

```bash
cp pw-play ~/.local/bin/ && chmod +x ~/.local/bin/pw-play
```

验证：`~/.config/herdr/.bel-shim-last` 记录 shim 最近被调用的时间戳；herdr client 日志不再出现 `sound playback failed`。

## 2. toast 弹窗 — config.toml 片段

追加到 `~/.config/herdr/config.toml`（若已有内容注意合并,勿覆盖）：

```toml
[ui.toast]
delivery = "herdr"
```

然后 `herdr server reload-config`。此后后台 agent 完成/需要输入时 TUI 内弹 toast。

> 为什么不用 `delivery = "terminal"`：该模式发 OSC 9/99 系统通知序列,仅支持 iTerm2/WezTerm/Ghostty/Kitty 且要求终端身份变量可见;mosh 是状态同步器而非字节管道,不透传自定义 OSC——mosh 链路下此路不通,BEL shim 是等效替代。

## 3. `herdr-title-daemon.sh` + `herdr-title.service` — 标题状态面板

每秒轮询 `herdr agent list`,把全部 agent 的状态计数写进外层终端标题（OSC 0,穿 mosh/ssh）：

```
⠹ mynode 🟡2 🔴1 🔵1 🟢3
```

- `🟡` working `🔴` blocked（等输入） `🔵` done（完成待看） `🟢` idle `⚪` unknown,非零才显示;
- 需要关注的状态靠前;有 working/blocked 时开头的 braille 帧每秒转一格;
- 配色语义对齐 herdr 官方 `state_dot()`（黄=working、红=blocked、青=done、绿=idle）;标题栏不渲染 ANSI 色,彩色来自 emoji 字形本身;
- 主机标识自动取 tailscale MagicDNS 节点名（回退 hostname）,一份脚本多机通用;
- 写往所有持有 tty 的 herdr client——多终端同时 attach 时每块屏幕同步;
- agent 无关:状态检测由 herdr 在 pane 层完成,claude/codex 等一视同仁。

```bash
cp herdr-title-daemon.sh ~/.local/bin/ && chmod +x ~/.local/bin/herdr-title-daemon.sh
sudo cp herdr-title.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now herdr-title.service
```

## 依赖与假设

- herdr ≥ 0.8.0（sound 探测顺序、`agent list` JSON 字段以此版本为准）
- `jq`；`tailscale`（可选,仅用于节点名）
- 文件内路径假设 root 用户（`/root/...`）,其他用户请按环境调整脚本与 unit 中的路径

## 已知限制

- **shim 脆弱点**：herdr 若改动 `src/sound.rs` 探测逻辑（加缓存/改顺序/弃 PATH 探测）,shim 失效——升级后提示音异常先查此处;
- 标题与焦点 pane 内应用自设的标题（如 Claude Code 原生 spinner 标题）存在覆盖交替,属已知取舍;
- 提示音/toast 仅在后台（unseen）agent 完成或需输入时触发,焦点内事件不提醒,是 herdr 的设计语义。
