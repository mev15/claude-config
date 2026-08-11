---
name: repo-memory
description: 用 GitHub issue 做项目的云 memory：把本地 memory/文档里的遗留 bug、未开发 feature 迁移成结构化 issue，多机器多 harness 共享读写，修复/开发 PR 用 Fixes #N 关联闭环。触发：/repo-memory init、/repo-memory migrate、「迁移 memory 到 issue」「把遗留 bug 建成 issue」「看 backlog」「做 #N」，或用户提到 issue 管理项目记忆/待办时。
---

# repo-memory — GitHub issue 作为项目云 memory

定位：每个仓库的 open issue = 该项目待办记忆（遗留 bug、未开发 feature、技术债）的**单一事实源**。
本地 memory 是单机私有的，issue 是所有机器共享的——任何机器上的 harness 都通过 gh CLI 读写同一份项目记忆。
本 skill 的资源文件在 `~/.claude/skills/repo-memory/assets/`。

## 协议

1. **issue 是待办记忆的唯一事实源**：工作中发现新 bug / 想到新 feature，先建 issue 再动手（这就是记忆写入）；本地 memory **不留正文副本，也不维护 issue 编号的指针/清单**——静态指针跟不上云端增删必腐。防分裂靠目标仓库 CLAUDE.md 的纪律段（init 第 4 步）；本地 memory 只收跨任务通用知识（偏好/方法论/机制）。
2. **Label 三组**（10 个，见 assets/labels.json）：类型 `bug|feature|chore|idea`、优先级 `P0|P1|P2`（P0=当前要做、P1=下一批、P2=有空再说）、`agent/ready|wip|blocked`（harness 调度状态机）。
3. **PR 规范**：conventional 标题，正文必带 `Fixes #N`，squash merge——合并即自动关 issue，记忆状态闭环零手工。
4. **多 harness 并发纪律**：`agent/ready` 是唯一授权开关（用户不打标，agent 不主动执行）；认领时打 `agent/wip` + 留认领评论，防止多机 harness 撞车；卡住打 `agent/blocked` + 评论卡点，停下等裁决。
5. **信息分层**：issue 正文 = 目标与验收标准；**📎 归档评论 = 排查素材与历史数据**——「做这个 issue 时才需要」的内容全下沉评论（须自足：数据、地址、教训写全，别的机器没有本地 memory）。**closed issue = 修复档案**：已完成修复可 backfill（正文标 📦 + 保留 tx/commit/关键数字做检索锚点，`gh issue close N --reason completed`，与 PR 自动闭环天然可区分）；排查「这症状修过吗」用 `gh issue list --state all --search "<关键词|tx>"`。

## 操作手册

### init — 给仓库装标准

目标仓库 = 当前目录仓库（`git remote get-url origin` 推断），用户另指定则以指定为准。会推送一个 commit，执行前告知用户。

```bash
# 1) labels（幂等 upsert）
jq -r '.[] | [.name,.color,.description] | @tsv' ~/.claude/skills/repo-memory/assets/labels.json | \
  while IFS=$'\t' read -r n c d; do
    gh label create "$n" -R <owner/repo> --color "$c" --description "$d" --force
  done
# 2) issue/PR 模板
mkdir -p .github
cp -r ~/.claude/skills/repo-memory/assets/ISSUE_TEMPLATE .github/
cp ~/.claude/skills/repo-memory/assets/PULL_REQUEST_TEMPLATE.md .github/
git add .github && git commit -m "chore: add issue/PR templates (repo-memory)" && git push
# 3) 只留 squash merge
gh repo edit <owner/repo> --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false
# 4) 在仓库 CLAUDE.md 写入「待办与项目记忆（GitHub Issues）」纪律段（与模板同 commit 或单独 commit）：
#    开工先读（含 closed 档案检索）/ 发现即写 / 完成即闭环（PR Fixes #N）/ agent-ready 授权。
#    这一步让不加载本 skill 的会话与机器也遵守体系——skill 只在装了它的机器有，CLAUDE.md 跟 repo 走。
```

注：`bug` label 与 GitHub 原生默认 label 撞名属预期（--force 幂等复用改描述）；其余原生 9 个默认 label 不冲突可留可清。

验证：`gh label list` 见 10 个 label；GitHub 开新 issue 出现 Bug/Feature 表单；仓库 CLAUDE.md 含纪律段。

### migrate — 本地记忆迁移成 issue（核心）

把散落在本地的项目待办记忆，一次性迁移为该仓库的结构化 issue。

**扫描源**（按存在性逐个检查）：
- 项目目录内：`CLAUDE.md`（TODO/已知问题/roadmap 段落）、`TODO.md`、`BACKLOG.md`、`docs/` 里的待办记录
- 全局 memory：`~/.claude/projects/<项目路径 slug>/memory/` 中的 `project_*` 文件（slug 由项目绝对路径 `/`→`-` 转换而来，如 `/home/u/myproj` → `-home-u-myproj`）
- `.remember/` 历史（`recent.md`、`archive.md` 中该项目相关段落）
- 用户口述的存量清单

⚠️ 标记「已完成/RESOLVED/SHIPPED」的记录也要**通读正文**——followup、观察项、open 问题常埋在长文中段，只看标题/索引状态会漏活待办（实战：5 个「已完成」文件里挖出 4 条未迁移 followup）。

**判别规则**——只迁「针对这个仓库的待办性质记忆」：
- ✅ 迁为 open：遗留 bug、未开发 feature、技术债、待优化项、搁置的想法
- 📦 已完成事项：不进 open；可选 backfill 为 **closed 修复档案**（协议 5，创建后立即 `close --reason completed`），方便未来按症状/tx 检索
- ❌ 不迁：用户偏好（feedback/user 类 memory）、环境/凭据/部署配置、跨项目基础设施记录
- ❌ 敏感内容过滤：凭据、token、IP、私钥路径等不进 issue 正文（即使私有库），必要时写「见本地配置」

**流程**：
1. 扫描 → 提取候选（标题、类型、正文素材、来源文件:行）。
2. `gh issue list -R <owner/repo> --state all --limit 200` 拉现有 issue，按标题/语义去重。
3. **生成迁移清单给用户确认——批量创建前必须过目**：分两组列出——open 候选（标题 | 类型 | 来源）与 📦 closed 档案候选（已完成事项：标题 | 修复 commit | 来源）。
4. 确认后逐条 `gh issue create`：bug 按「现象与期望 + 复现步骤」组织，feature 按「目标 + 验收标准 + 上下文」组织；信息不足的字段如实写「待细化」，不编造。打上类型标签（`bug/feature/chore/idea`），能判断的加 `P0/P1/P2`。📦 档案组按协议 5 组织正文（📦 标注 + 问题/根因/修复/验证 + tx/commit 锚点），只打类型不打优先级，创建后立即 `gh issue close N --reason completed`。
5. 素材下沉与清源：每条 issue 把「做它时才需要」的排查素材（数据、地址、教训、原始数字）以 **📎 归档评论**附上；然后**删除**已迁移的源 memory 文件/条目——跨任务通用的坑与方法浓缩进 feedback 类 memory 或仓库 CLAUDE.md，本地不留任何 issue 编号引用（协议 1）。输出迁移报告（成功清单 + 跳过原因）。
6. 顺带审计仓库 CLAUDE.md 的同类影子内容（手工维护的测试清单、外部 schema 副本、时点计数）——与本地待办副本同源同病，建议缩为指向事实源（`ls tests/`、`sqlite3 .schema`、`cargo test`），提请用户裁决后执行。

### 记 — 增量写入

```bash
gh issue create -R <owner/repo> -t "<一句话>" -b ""     # 裸记合法（收件箱），细化时再补
gh issue create ... -l "bug" -l "P0"                    # 能判断就顺手带标签
```
细化 #N：`gh issue edit N` 把正文补成对应表单结构（bug=现象/复现，feature=目标/验收标准/上下文），验收标准要写到「照着做完就能自证完成」。

### 看 — 读取项目记忆

```bash
gh issue list -R <owner/repo> --limit 50                # 全量
gh issue list -R <owner/repo> -l "bug"                  # 只看遗留 bug
gh search issues "owner:<owner> state:open label:P0" --limit 50 \
  --json repository,number,title \
  --template '{{range .}}{{.repository.nameWithOwner}}#{{.number}}  {{.title}}{{"\n"}}{{end}}'   # 跨仓库
```

### 做 #N — 消费与闭环

1. `gh issue view N` 读正文；验收标准缺失或不可验证 → 先让用户补，不猜。
2. （harness 场景）确认无 `agent/wip` 后认领：打 `agent/wip` + 认领评论。
3. 分支 `fix/N-<slug>` 或 `feat/N-<slug>`，实现 + 测试，对验收标准逐条自验。
4. PR：conventional 标题，正文 = 变更说明 + `Fixes #N` + 验证结果；CI 绿后 squash merge，确认 issue 自动关闭。
5. 过程中的新发现（其他 bug、技术债）→ 顺手建 issue，这是记忆写入的一部分。

## harness 消费协议（多机共享的读写约定)

- **开工先读**：进入一个项目干活前 `gh issue list --state open`，open issue 就是这个项目的当前记忆；排查 miss/回归先 `gh issue list --state all --search "<症状|tx>"` 查修复档案。
- **发现即写**：任何新 bug/feature/技术债，先建 issue 再继续手头工作。
- **完成即闭环**：一律走 PR `Fixes #N`，不手动关 issue。
- **核查闭环（例外）**：排查存量 open issue 时发现实际已被历史工作顺带修复——对照验收标准用代码/日志/测试验证后，手动 `close --reason completed` + 评论注明修复 commit 与验证证据（这与 backfill 档案同为合法的手动 close 场景）。
- **并发防撞**：认领必打 `agent/wip`；见到别人的 `agent/wip` 就跳过。

## 边界

- init/migrate 都产生远程写入；migrate 批量创建前必须给用户清单确认。
- 只操作用户明确指定的仓库。
- 只有用户打了 `agent/ready` 的 issue，agent 才允许主动认领执行。
