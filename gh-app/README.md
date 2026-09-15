# gh-app

agent 机器上的 `gh` 与 `git` 以 GitHub App **`mev15-bot[bot]`** 的身份操作，不用人账号的 PAT：
身份独立（能 approve 人开的 PR、操作来源一眼可辨）、token 一小时过期、权限按仓库细分、
每台机器一把私钥可单独吊销。对所有仓库通用，与具体项目无关。

三个标识都从 GitHub 页面取，不写在仓库里：**App ID** 在 Settings → Developer settings → GitHub Apps →
mev15-bot 页面顶部；**Installation ID** 是 Install App 装完后地址栏 `settings/installations/<数字>`；
bot 的 **user id** 用 `gh api '/users/mev15-bot[bot]' --jq .id` 取。装到哪些仓库在 Settings → Applications →
Installed GitHub Apps 里改。

## 文件

| 文件 | 作用 |
|---|---|
| `gh-app-token` | 用私钥签 10 分钟 JWT → 换 1 小时 installation token，本地缓存 50 分钟；`--jwt` 只输出 JWT |
| `gh` | 装成 `/usr/local/bin/gh` 的包装：任何进程调 `gh` 都自动带 bot token，再 exec `/usr/bin/gh` |
| `config.example` | `~/.config/gh-app/config` 模板 |

## 新机器接入（约 3 分钟）

1. App 页面 Private keys → Generate a private key，下载 `.pem`（**每台机器一把**，机器下线就在页面吊销那一把）
2. 放私钥与配置：
   ```bash
   mkdir -p ~/.config/gh-app && chmod 700 ~/.config/gh-app
   mv ~/Downloads/mev15-bot.*.pem ~/.config/gh-app/mev15-bot.pem && chmod 600 ~/.config/gh-app/mev15-bot.pem
   cp gh-app/config.example ~/.config/gh-app/config   # 填入 App ID / Installation ID
   ```
3. 装脚本与包装，并让 git 的凭据助手走包装：
   ```bash
   sudo install -m 755 gh-app/gh-app-token /usr/local/bin/gh-app-token
   sudo install -m 755 gh-app/gh /usr/local/bin/gh
   git config --global --replace-all credential.https://github.com.helper '!/usr/local/bin/gh auth git-credential'
   git config --global --replace-all credential.https://gist.github.com.helper '!/usr/local/bin/gh auth git-credential'
   ```
   `/usr/local/bin` 在 PATH 里排在 `/usr/bin` 前面，所以与 shell 启动文件无关——Claude Code 的 Bash 工具
   不读 `~/.bashrc`，靠 rc 文件注入 `GH_TOKEN` 会漏（第一次接入时 PR 作者就错成了人账号）。
   某个仓库里如有本地的 `credential.*.helper` 覆盖（`gh auth setup-git` 会写成 `/usr/bin/gh`），同样 `--replace-all` 改掉。
4. git 提交身份：
   ```bash
   git config --global user.name "mev15-bot[bot]"
   git config --global user.email "<user id>+mev15-bot[bot]@users.noreply.github.com"
   ```
5. 验证：`which gh` 是 `/usr/local/bin/gh`；`gh auth status` 第一行是 `mev15-bot[bot] (GH_TOKEN)`；
   `gh api /installation/repositories --jq '.repositories[].full_name'` 列出仓库；
   随便一个仓库 `git push origin HEAD:refs/heads/bot-auth-test && git push origin --delete bot-auth-test` 能推能删。

## 日常

- 包装尊重已存在的 `GH_TOKEN`（CI 场景照旧）；要临时用人账号：`GH_HUMAN=1 gh …` 或直接 `/usr/bin/gh`
- 换不到 token（断网、私钥被吊销）时包装不设 `GH_TOKEN`，`gh` 会**退回** `~/.config/gh` 里登录的人账号——
  涉及身份的操作（开 PR、review）前看一眼 `gh auth status` 第一行是谁
- installation token 不能调 `/user`，这是 App 的正常行为，不是配置错
- bot 开的 PR 只能由人账号 approve；人开的 PR 可以由 bot approve（GitHub 不允许作者 approve 自己的 PR）
- 限额：每个安装每小时 5,000 次 API；建 issue / 评论 / PR / review 这类写操作每小时 500 次；不收费
- 多 agent 要分身份时，再建一个 App（各自一个 `[bot]`），或同一个 App 换 token 时缩小权限
