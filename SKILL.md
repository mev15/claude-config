---
name: codex-review-loop
description: Use when code implementation or test writing is complete and needs an external review gate. Triggers on "codex review", "外部审查", "codex 审一下", "让 codex 看看"
---

# Codex Review Loop

通过 Codex CLI 进行外部代码审查，按优先级迭代修复问题。Codex 只审查不改代码，修复由 Claude Code 执行。

**Announce at start:** "I'm using the codex-review-loop skill to get an external Codex review."

## When to Use

**在现有 review 流程之后，作为额外的外部审查关卡：**

| 阶段 | 触发时机 | review_type |
|------|----------|-------------|
| Test | 测试代码编写完成后 | `test` |
| Code | `subagent-driven-development` 每个 task 的 code-quality-review 通过后 | `code` |

**顺序铁律：test review 必须先于 code review，不可对调。**
先确认"验收标准"（测试）是否正确，再审查实现代码，符合 TDD 先行理念——测试没审对，code review 就是在错误的验收标准下进行。

**也可以独立使用：**
- 大型重构前后
- PR 合并前的最终审查
- 对关键模块的安全审查

## Modification Boundaries (Iron Rule)

**每种 review_type 有严格的修改边界，绝对不可越界：**

| review_type | 允许修改 | 禁止修改 | 禁止操作 |
|-------------|----------|----------|----------|
| `code` | 项目源代码（src/ 等） | 测试代码（tests/、*.test.*、*.spec.*） | — |
| `test` | 测试代码（tests/、*.test.*、*.spec.*） | 项目源代码（src/ 等） | 运行测试、修改项目代码 |

**Why：** 避免不同阶段的修改互相干扰，保持职责清晰。test review 阶段改了源码，code review 的审查对象就被污染了；反之亦然。

**违反边界的修复建议：** 记录到报告中标注"越界建议"，不执行修复，留给对应阶段处理，由用户决定。

## The Process

```
准备上下文 → 调 Codex（herdr 内：交互式 pane / 否则：codex exec）→ 读报告 → 在边界内按优先级修复 → 再调 Codex 验证 → 直到通过 →（herdr 模式）关闭 pane
```

### Step 1: Prepare Review Context

根据 `review_type` 准备不同的上下文：

**code:**
```bash
# 导出 diff（基于 git SHA 或 HEAD~N），排除测试文件
git diff <BASE_SHA>..<HEAD_SHA> -- . ':!tests/' ':!**/*.test.*' ':!**/*.spec.*' > /tmp/codex-review-input.diff
# 如果 diff 过大（>3000 行），按文件拆分，分批审查
```

**test:**
```bash
# 导出测试文件 diff
git diff <BASE_SHA>..<HEAD_SHA> -- "tests/**" "**/*.test.*" "**/*.spec.*" > /tmp/codex-review-input.diff

# 【关键】收集 case 目录中对应的测试用例文档作为上下文
# 查找项目中的 case/testcase/cases 目录
find . -type d -iname "case*" -o -type d -iname "testcase*" 2>/dev/null
# 将找到的 case 文档复制到临时目录
cp <case-docs> /tmp/codex-review-test-cases/
```

test 审查时，除了 diff 本身，还必须将相关的 case 文档一起提交给 Codex，使其能够：
- 对照 case 文档验证测试覆盖率（是否每个 case 都有对应测试）
- 验证断言准确性（断言是否与 case 中定义的预期结果一致）
- 发现遗漏的测试场景

### Step 2: Construct Review Prompt

根据 `review_type` 使用对应的审查 prompt：

**code:**
```
你是一个高级代码审查专家。请审查以下 git diff，按 Critical / Important / Minor 三级给出 review 报告。
注意：本次审查范围仅限项目源代码，不包含测试代码。如果你发现需要修改测试代码的问题，请在 Minor 中标注为"越界建议（测试）"。
审查维度：
- 安全问题：硬编码密钥、敏感信息泄露、SSL 校验关闭、注入风险
- 错误处理：异常是否被正确捕获和处理，是否有静默失败
- 类型安全：是否有 any 滥用、类型断言、未校验的外部输入
- 性能：是否有内存泄漏、无限增长的队列、缺少背压机制
- 架构设计：职责是否清晰、耦合度是否合理、是否违反 DRY/YAGNI
diff 文件路径：/tmp/codex-review-input.diff
```

**test:**
```
你是一个高级测试审查专家。请审查以下测试代码 diff，按 Critical / Important / Minor 三级给出 review 报告。
注意：本次审查范围仅限测试代码。如果你发现需要修改项目源代码的问题，请在 Minor 中标注为"越界建议（源码）"。
审查维度：
- 测试覆盖率：对照 /tmp/codex-review-test-cases/ 中的 case 文档，是否每个 case 都有对应测试
- 断言准确性：对照 case 文档中的预期结果，断言是否精确匹配
- 测试有效性：是否在测试真实行为而非 mock 行为
- 边界覆盖：是否覆盖了边界条件、错误路径、关键业务逻辑
- 测试隔离性：测试之间是否相互独立，是否有共享状态污染
- 可维护性：测试命名是否清晰，setup/teardown 是否合理
diff 文件路径：/tmp/codex-review-input.diff
case 文档路径：/tmp/codex-review-test-cases/
```

### Step 3: Invoke Codex CLI

**先检测运行环境：** 环境变量 `HERDR_PANE_ID` 存在 → 在 herdr 内，用 Mode A（交互式 pane）；否则用 Mode B（`codex exec`，原流程）。

#### Mode A: herdr 交互式 pane（在 herdr 内时）

分裂一个新 pane 跑交互式 codex：用户可实时旁观审查过程，且多轮 re-review 共享同一 codex 会话上下文。

**首轮 review 前的一次性准备：**

```bash
# 1. 将 Step 2 构造的完整 review prompt 用 Write 工具写入 /tmp/codex-review-prompt.txt
#    （交互消息保持简短单行，规避 TUI 多行提交的不确定性）

# 2. 从当前 pane 向右分裂 review pane（不抢焦点）
PANE_ID=$(herdr pane split --pane "$HERDR_PANE_ID" --direction right --ratio 0.4 --cwd "$PWD" --no-focus | jq -r '.result.pane.pane_id')

# 3. 在新 pane 中启动交互式 codex（沙箱只读铁律不变），agent 名加时间戳避免撞名
AGENT="codex-review-$(date +%s)"
herdr agent start "$AGENT" --kind codex --pane "$PANE_ID" --timeout 60000 -- -s read-only -a on-failure
```

记住 `$PANE_ID` 和 `$AGENT` 的实际值——后续每次 Bash 调用是新 shell，变量不会保留。

**每轮 review：**

```bash
# 提交审查请求，阻塞等待 codex 完成（到达 idle/done/blocked 任一状态）
herdr agent prompt "$AGENT" "请阅读 /tmp/codex-review-prompt.txt 并执行其中的审查任务，审查报告直接输出在对话中" --wait --timeout 600000

# 完成后读取审查报告（recent-unwrapped：无折行快照，适合程序化解析）
herdr agent read "$AGENT" --source recent-unwrapped --lines 400 --format text
```

| 要点 | 说明 |
|------|------|
| `-s read-only` | 沙箱只读铁律不变；codex 无法写文件，报告从终端读取 |
| `-a on-failure` | 只读命令沙箱内自动执行，最小化交互审批（等价 exec 模式的 `--full-auto`） |
| `--wait --timeout 600000` | 阻塞至 codex 空闲，10 分钟上限；超时处理见 Troubleshooting |
| `--no-focus` | 不抢用户当前焦点 |

**Review 整体结束后必须关闭 pane**（见 Step 6 收尾）。

#### Mode B: codex exec（非 herdr 环境）

```bash
codex exec -s read-only --full-auto -o /tmp/codex-review-output.txt "<review-prompt>"
```

| 参数 | 作用 |
|------|------|
| `-s read-only` | 沙箱只读，保证 Codex 不修改任何代码 |
| `--full-auto` | 无需人工确认，自动完成审查 |
| `-o <file>` | 将审查报告写入文件 |

**超时处理：** 设置 Bash timeout 为 300 秒（5 分钟）。如果超时，汇报给用户并建议减小审查范围。

### Step 4: Read and Parse Report

```bash
# Mode A（herdr）：报告即 Step 3 中 herdr agent read 的输出（codex 回复行以 • 开头），直接解析
# Mode B（exec）：读取报告文件
Read /tmp/codex-review-output.txt
```

解析报告中的三个优先级，并按修改边界分类：

- **Critical（边界内）** — 必须立即修复
- **Critical（越界）** — 记录，不修复，汇报给用户
- **Important（边界内）** — 应该修复
- **Important（越界）** — 记录，不修复，汇报给用户
- **Minor** — 记录备查，可选修复

### Step 5: Fix by Priority (Within Boundary Only)

**修复顺序严格按优先级，且只修复边界内的问题：**

1. **修复所有 Critical（边界内）问题**
   - 逐个修复，每个修复后确认改动在边界内
   - 如果某个 Critical 问题的修复方案不明确，停下来和用户讨论

2. **修复所有 Important（边界内）问题**
   - 逐个修复，每个修复后确认改动在边界内
   - 如果某个 Important 问题与 Critical 修复冲突，优先保证 Critical 的修复正确

3. **Minor 问题（边界内）**
   - 列出所有 Minor 问题供用户决定
   - 用户确认后修复，或记录到后续 TODO

4. **越界问题汇总**
   - 所有越界建议单独列出
   - 标注建议来源（Codex review round N）
   - 留待对应 review_type 阶段处理

### Step 6: Re-review (Validation Loop)

修复完 Critical 和 Important 后，**必须**再调一次 Codex 验证：

```bash
# 重新导出修复后的 diff（遵守同样的边界过滤）
# code: 排除测试文件
git diff <BASE_SHA>..HEAD -- . ':!tests/' ':!**/*.test.*' ':!**/*.spec.*' > /tmp/codex-review-input.diff
# test: 只包含测试文件
git diff <BASE_SHA>..HEAD -- "tests/**" "**/*.test.*" "**/*.spec.*" > /tmp/codex-review-input.diff

# Mode A（herdr）：同一会话继续，无需重发完整 prompt，直接描述修复内容
herdr agent prompt "$AGENT" "我已修复以下问题：<修复摘要>。diff 已更新（/tmp/codex-review-input.diff），请重新审查，确认修复是否到位、是否引入新问题" --wait --timeout 600000
herdr agent read "$AGENT" --source recent-unwrapped --lines 400 --format text

# Mode B（exec）：重新调用 Codex
codex exec -s read-only --full-auto -o /tmp/codex-review-output.txt "<review-prompt>"
```

**通过条件：** 报告中无 Critical（边界内）且无 Important（边界内）。

**最大迭代次数：5 次。** 超过 5 次仍有 Critical/Important，停止并向用户汇报，由用户决定是否继续。

**herdr 模式收尾：** review 整体结束后（通过 **或** 达到最大迭代次数）必须关闭 review pane：

```bash
herdr pane close "$PANE_ID"
```

例外：异常中断（codex 超时无响应、状态卡死）时**保留 pane 不关闭**，供用户直接查看现场，并在汇报中说明 pane 仍开着。

## Integration with Existing Workflow

### 与 subagent-driven-development 集成

```
每个 Task:
  implementer → spec-review → code-quality-review
       ↓ (全部通过)
  codex-review-loop(type=test)    ← 先审测试，只改测试代码
       ↓ (通过)
  codex-review-loop(type=code)    ← 后审实现，只改项目代码
       ↓ (通过)
  ✅ Mark task complete
```

### 独立使用

```
用户请求 review → 确定 review_type 和 diff 范围
       ↓
  codex-review-loop(type=test|code)
       ↓
  ✅ 输出最终审查报告和修复摘要
```

## Output Format

每次 review 循环完成后，向用户汇报：

```
### Codex Review Round N/5

**状态：** ✅ 通过 / ❌ 需要修复 / ⚠️ 达到最大迭代次数

**Codex 发现（边界内）：**
- Critical: X 个（已修复 Y 个）
- Important: X 个（已修复 Y 个）
- Minor: X 个（待用户决定）

**越界建议（不修复，待后续阶段处理）：**
- [越界问题列表及建议来源]

**本轮修复：**
- [具体修复内容和文件:行号]

**下一步：**
- [继续 / 再次 review / 交给用户决定]
```

## Red Flags

**Never:**
- 跳过 re-review（修复后必须验证）
- 在有 Critical（边界内）问题时继续下一阶段
- 越界修复（code review 时改测试，test review 时改源码或跑测试）
- 盲目接受 Codex 的所有建议（用 `receiving-code-review` skill 的原则评估）
- 让 Codex 修改代码（始终 `-s read-only`）
- 在未读取 review 报告时声称"审查通过"
- test review 时运行测试或修改项目源代码
- herdr 模式下 review 正常结束后不关闭 review pane（遗留僵尸 pane）

**If Codex is wrong:**
- 用技术理由 push back
- 在汇报中标注"Codex 误报"及理由
- 不因误报而跳过 re-review

## Troubleshooting

| 问题 | 处理 |
|------|------|
| Codex CLI 超时 | 减小 diff 范围，分批审查 |
| Codex 输出格式异常 | 重试一次；仍异常则直接展示原始输出给用户 |
| diff 超过 3000 行 | 按文件或模块拆分，分批审查，合并报告 |
| Codex 审查和内部 review 冲突 | 两者都列出，由用户裁决 |
| 找不到 case 文档目录 | 提示用户指定 case 文档路径，或跳过覆盖率审查维度 |
| herdr `agent start` 超时 | 确认 codex 可用（`which codex`）；pane 必须处于 shell 提示符状态；重试一次 |
| herdr `agent prompt` 返回 `agent_prompt_stalled` | 提交后 5 秒内未观察到状态变化；重试一次 prompt |
| herdr `agent prompt --wait` 超时 | `herdr agent wait "$AGENT" --timeout 300000` 再等一轮；仍未完成则 `agent read` 查看现场，保留 pane 汇报用户 |
| herdr 模式 codex 进入 `blocked` 状态 | `herdr agent read` 查看它在等什么（通常是命令审批），用 `herdr agent send-keys` 回应，或汇报用户 |
