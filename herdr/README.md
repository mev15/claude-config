# herdr 无头服务器提醒三件套

herdr 跑在无头服务器上、通过 mosh/ssh 远程使用时，agent 状态提醒存在三个断点：

1. **提示音无声**——herdr 的提示音走本地 MP3 播放（`paplay` 等），无声卡的服务器上必然失败；
2. **toast 弹窗默认关闭**；
3. **窗口标题无全局状态**——herdr 只转发焦点 pane 的标题，后台 pane 的 agent 在干什么外层完全不可见。

以下三节分别补上这三个断点（第 3 节已迁移为 herdr 插件）。已在多台 Ubuntu 无头服务器 + mosh 远程场景验证。

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

## 3. 标题状态面板 — 已迁移为 herdr 插件

原 `herdr-title-daemon.sh` + `herdr-title.service`（1s 轮询 + 旁路直写 `/dev/tty` 的 systemd 方案）已于 2026-08-10 退役,脚本内容见 git 历史。替代方案为 fork 插件 [mev15/herdr-ghostty-tab-title](https://github.com/mev15/herdr-ghostty-tab-title)（上游 [wjarka/herdr-ghostty-tab-title](https://github.com/wjarka/herdr-ghostty-tab-title),叠加 tailscale 节点名 label、braille spinner、紧凑间距、🔵 done 等生产默认）：

```bash
herdr plugin install mev15/herdr-ghostty-tab-title --yes
```

相比 daemon：事件驱动替代每秒轮询;走 herdr 官方 `client.window_title.set` API 而非从进程表反查 tty,`herdr --remote`（server 无 tty）拓扑照常工作;自带单元与集成测试。配色语义仍对齐 herdr 官方 `state_label_color()`（青 done→🔵）。

## 依赖与假设

- herdr ≥ 0.8.0（sound 探测顺序以此版本为准）
- 文件内路径假设 root 用户（`/root/...`）,其他用户请按环境调整

## 已知限制

- **shim 脆弱点**：herdr 若改动 `src/sound.rs` 探测逻辑（加缓存/改顺序/弃 PATH 探测）,shim 失效——升级后提示音异常先查此处;
- 标题与焦点 pane 内应用自设的标题（如 Claude Code 原生 spinner 标题）存在覆盖交替,属已知取舍;
- 提示音/toast 仅在后台（unseen）agent 完成或需输入时触发,焦点内事件不提醒,是 herdr 的设计语义。
