# MCP 与 Plugin

全局启用的 MCP server 与 plugin 清单及安装方式。示例中的凭证一律为 `<YOUR_*>` 占位符，须替换为自己的；建议为每个服务使用最小权限的独立凭证。

## MCP servers（用户级）

| server | 传输 | 运行方式 | 凭证 | 用途 |
|--------|------|----------|------|------|
| [context7](https://github.com/upstash/context7) | stdio | `npx -y @upstash/context7-mcp` | 无 | 实时拉取库/框架官方文档，避免依赖过时的 API 记忆 |
| [github](https://github.com/github/github-mcp-server) | stdio | Docker 镜像 `ghcr.io/github/github-mcp-server` | GitHub PAT（建议 fine-grained） | 仓库 / PR / issue / Actions 操作 |
| [etherscan](https://github.com/huahuayu/etherscan-mcp-server) | stdio | Go 二进制，放入 PATH | `ETHERSCAN_API_KEY` | 以太坊链上数据：交易、合约源码 / ABI、余额 |
| dune | http | `https://api.dune.com/mcp/v1` | `x-dune-api-key` header | Dune Analytics 查询与仪表盘 |

安装（`-s user` 全局生效；省略则仅当前项目）：

```bash
# context7（免凭证）
claude mcp add -s user context7 -- npx -y @upstash/context7-mcp

# github（需本机 Docker）
claude mcp add -s user github -- docker run -i --rm -e GITHUB_PERSONAL_ACCESS_TOKEN=<YOUR_PAT> ghcr.io/github/github-mcp-server

# etherscan（先从上游获取二进制放入 PATH）
claude mcp add -s user -e ETHERSCAN_API_KEY=<YOUR_KEY> etherscan -- etherscan-mcp-server

# dune（HTTP 远程 server）
claude mcp add -s user --transport http dune https://api.dune.com/mcp/v1 --header "x-dune-api-key: <YOUR_KEY>"
```

验证：`claude mcp list` 逐个检查连通性。注意其输出会回显完整启动命令（含内联凭证），公开粘贴前先脱敏。

## Plugins

| plugin | marketplace | 用途 | 前置依赖 |
|--------|-------------|------|----------|
| rust-analyzer-lsp | claude-plugins-official | Rust LSP：定义 / 引用 / 诊断级代码导航 | `rustup component add rust-analyzer` |
| typescript-lsp | claude-plugins-official | TypeScript LSP | `npm install -g typescript-language-server typescript` |
| remember | claude-plugins-official | 分层会话记忆：会话开始注入历史，过程自动采集，`.remember/` 下按日 / 周滚动压缩 | 无 |
| codex | openai-codex | `/codex` 命令集（review / rescue / transfer 等）+ codex-rescue agent | [Codex CLI](https://github.com/openai/codex) 已安装并登录 |

安装（官方 marketplace 开箱即用，第三方 marketplace 先注册）：

```bash
claude plugin install rust-analyzer-lsp@claude-plugins-official
claude plugin install typescript-lsp@claude-plugins-official
claude plugin install remember@claude-plugins-official

claude plugin marketplace add openai/codex-plugin-cc
claude plugin install codex@openai-codex
```

安装完成后 `~/.claude/settings.json` 中对应的键如下，可用于核对或直接同步：

```json
{
  "enabledPlugins": {
    "rust-analyzer-lsp@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true,
    "remember@claude-plugins-official": true,
    "codex@openai-codex": true
  },
  "extraKnownMarketplaces": {
    "openai-codex": {
      "source": { "source": "github", "repo": "openai/codex-plugin-cc" }
    }
  }
}
```

LSP 类 plugin 只是能力开关，语言服务器本体（rust-analyzer、typescript-language-server）需按上表前置依赖自行安装，否则不生效。
