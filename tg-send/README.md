# tg-send

统一 Telegram 通知管道：一个零依赖 bash CLI（仅需 curl），凭据集中存 `~/.config/tg-send/`，Claude Code 的 cron / skill / hook 及任意脚本共用一个入口，不必在每处重复配置 bot token。

## 安装

```bash
sudo cp tg-send /usr/local/bin/tg-send && sudo chmod 755 /usr/local/bin/tg-send
mkdir -p ~/.config/tg-send && chmod 700 ~/.config/tg-send
cp bot.env.example ~/.config/tg-send/mybot.env && chmod 600 ~/.config/tg-send/mybot.env
# 编辑 mybot.env 填入 token/chat_id，然后设为默认 bot：
ln -sfn mybot.env ~/.config/tg-send/default.env
```

bot token 从 Telegram @BotFather `/newbot` 获取；bot 无法主动私聊，需先对 bot 发一次 `/start`。chat_id 即接收者的用户/群 ID。

## 用法

```bash
tg-send "消息"                 # 默认 bot（default.env symlink 所指）
tg-send -b mybot "消息"        # 指定 bot（对应 ~/.config/tg-send/mybot.env）
echo "长输出" | tg-send         # stdin 管道（cron 场景）
tg-send -c <chat_id> "消息"    # 临时覆盖收件目标
tg-send --help                 # 列出所有已配置 bot
```

- 新增 bot = 放一个 `<名>.env` 文件；切默认 = `ln -sfn <名>.env default.env`（原子，token 只存一份）
- 多 bot 的意义：不同发件身份（业务告警 / 节点监控 / Claude 通知）在 TG 里天然分线，退订/静音互不影响

## 行为约定

- 成功静默退出 0；失败信息进 stderr、退出非 0（cron 友好）
- 不信任 HTTP 层：校验 API 响应 `"ok":true` 才算成功，chat_id 错误等会带原始 JSON 报错
- 超 4000 字符自动截断加 `…(truncated)`（Telegram 单条上限 4096，截断送达优于整条失败）
- 网络瞬断由 `curl --retry 2` 兜底，单次发送最长 15s

## Claude Code 集成

全局 `~/.claude/CLAUDE.md` 加一行，之后所有 skill / cron 的 prompt 里一句"用 tg-send 通知"即可：

```markdown
## Telegram 通知
- Telegram 通知统一走 `tg-send` 命令：`tg-send "消息"`（默认 bot）或 `tg-send -b <bot> "消息"`；bot 配置在 `~/.config/tg-send/`
```
