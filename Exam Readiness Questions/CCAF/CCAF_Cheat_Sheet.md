# 📋 CCAF Quick Reference & Exam Day Cheat Sheet

> **Use this for rapid last-minute review before the exam.**

---

## 🏗️ Architecture at a Glance

```
┌─────────────────────────────────────────────────────────────────────┐
│                     CLAUDE ECOSYSTEM MAP                           │
│                                                                     │
│  ┌──────────┐  ┌────────────┐  ┌────────────┐  ┌───────────────┐  │
│  │ Claude   │  │ Agent SDK  │  │ Claude     │  │ MCP Protocol  │  │
│  │ API      │  │            │  │ Code       │  │               │  │
│  │          │  │ • Agents   │  │ • Terminal │  │ • Tools       │  │
│  │ • Messages│ │ • Hooks    │  │ • Built-in │  │ • Resources   │  │
│  │ • Tools  │  │ • Task tool│  │   tools    │  │ • Servers     │  │
│  │ • Batches│  │ • Sessions │  │ • CLAUDE.md│  │ • .mcp.json   │  │
│  └──────────┘  └────────────┘  └────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🔑 Top 30 Concepts — One-Liner Each

| # | Concept | One-Liner |
|---|---------|-----------|
| 1 | `stop_reason` | THE only reliable loop termination signal (`end_turn` = done, `tool_use` = continue) |
| 2 | Subagent isolation | Subagents do NOT inherit parent context — pass data explicitly |
| 3 | Task tool | Must be in `allowedTools` or coordinator can't spawn subagents |
| 4 | Programmatic hooks | 100% deterministic enforcement for critical business rules |
| 5 | PostToolUse hook | Transforms tool results AFTER execution, BEFORE model sees them |
| 6 | Tool call interception | Blocks/redirects tool calls BEFORE execution |
| 7 | Parallel subagents | Multiple Task calls in ONE response = parallel execution |
| 8 | Tool descriptions | #1 factor in tool selection — include purpose, inputs, outputs, boundaries |
| 9 | Tool count | 4-5 per agent optimal; 18+ degrades selection reliability |
| 10 | `tool_choice: "auto"` | Model MAY return text instead of calling a tool |
| 11 | `tool_choice: "any"` | Model MUST call a tool but chooses which one |
| 12 | Forced tool selection | `{"type":"tool","name":"X"}` — guarantees specific tool |
| 13 | MCP error categories | Transient, Validation, Business, Permission |
| 14 | `isRetryable` flag | Tells agent whether to retry or pivot |
| 15 | Empty results ≠ errors | Distinguish valid empty results from access failures |
| 16 | `.mcp.json` | Project-level (shared, version-controlled) |
| 17 | `~/.claude.json` | User-level (personal, not shared) |
| 18 | `${ENV_VAR}` | Environment variable expansion in .mcp.json for secrets |
| 19 | MCP resources | Read-only catalogs that reduce exploratory tool calls |
| 20 | Grep vs Glob | Grep = file CONTENT search; Glob = file PATH/NAME search |
| 21 | CLAUDE.md hierarchy | User (`~/.claude/`) → Project (`.claude/`) → Directory (subdirs) |
| 22 | `context: fork` | Runs skill in isolated context, prevents output pollution |
| 23 | Path-scoped rules | `.claude/rules/` with `paths: ["**/*.test.*"]` |
| 24 | `-p` flag | Non-interactive mode for CI/CD |
| 25 | Explicit criteria | "Flag contradictions" > "be conservative" |
| 26 | Few-shot examples | 2-4 examples > detailed prose for consistency |
| 27 | Nullable fields | Prevent hallucination for absent data |
| 28 | Self-review limitation | Same session can't effectively review its own output |
| 29 | Case facts block | Extract transactional data outside summarized history |
| 30 | Batch API | 50% savings, up to 24h, no blocking workflows |

---

## ❌ Anti-Pattern Quick Reference

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| Parsing text for "I'm done" | Brittle; pending tool calls missed | Check `stop_reason` |
| Iteration caps as primary stop | Kills complex tasks early | `stop_reason: "end_turn"` |
| Prompt-only business rules | ~88% compliance, not 100% | Programmatic hooks |
| All tools to all agents | Selection degrades at 18+ | 4-5 tools per agent |
| Generic "Operation failed" | Can't distinguish retry vs stop | Structured error categories |
| Empty results as success | Hides failures silently | `isError: true` with context |
| Same-session self-review | Retains reasoning bias | Independent review instance |
| Sentiment-based escalation | Doesn't correlate with complexity | Explicit trigger criteria |
| Self-reported confidence | Poorly calibrated | Structural decision criteria |
| Required field for optional data | Forces hallucination | Nullable fields |
| Full workflow kill on 1 failure | Wastes completed work | Local recovery → propagate |
| Resuming after major refactor | Stale file references | New session + summary |
| Vague instructions ("be careful") | Inconsistent results | Explicit criteria + examples |

---

## 📁 Configuration File Locations

| File | Scope | Shared? | Purpose |
|---|---|---|---|
| `~/.claude/CLAUDE.md` | User | ❌ Not shared | Personal coding preferences |
| `.claude/CLAUDE.md` | Project | ✅ Version-controlled | Team standards & conventions |
| `CLAUDE.md` (root) | Project | ✅ Version-controlled | Project-wide instructions |
| `.claude/rules/*.md` | Project | ✅ Version-controlled | Path-scoped rules with globs |
| `.claude/commands/` | Project | ✅ Version-controlled | Team slash commands |
| `~/.claude/commands/` | User | ❌ Not shared | Personal slash commands |
| `.claude/skills/` | Project | ✅ Version-controlled | Team skills |
| `~/.claude/skills/` | User | ❌ Not shared | Personal skills |
| `.mcp.json` | Project | ✅ Version-controlled | Team MCP servers |
| `~/.claude.json` | User | ❌ Not shared | Personal MCP servers |

---

## 🔧 Hook Types Comparison

```
┌────────────────────────┐     ┌────────────┐     ┌──────────────────┐
│ Tool Call Interception  │────►│ Tool       │────►│ PostToolUse      │
│ (BEFORE execution)     │     │ Executes   │     │ (AFTER execution)│
│                        │     │            │     │                  │
│ • Block refunds > $500 │     │            │     │ • Normalize dates│
│ • Require verification │     │            │     │ • Trim fields    │
│ • Redirect to human    │     │            │     │ • Redact PII     │
│ • Log for audit        │     │            │     │ • Format output  │
└────────────────────────┘     └────────────┘     └──────────────────┘
   Deterministic YES/NO           Actual work        Transform results
```

---

## 🎯 `tool_choice` Decision Matrix

```
What do you need?
│
├─ Text response is acceptable
│  → tool_choice: "auto"
│
├─ MUST get structured output (tool call guaranteed)
│  │
│  ├─ Model picks which tool
│  │  → tool_choice: "any"
│  │
│  └─ Specific tool must run
│     → tool_choice: {"type": "tool", "name": "extract_metadata"}
│
└─ Force tool ordering (extract → then enrich)
   → Turn 1: force "extract_metadata"
   → Turn 2+: "auto"
```

---

## 🚨 Escalation Decision Tree

```
Customer interaction:
│
├─ Customer says "I want a human" → ESCALATE IMMEDIATELY
│
├─ Policy is silent/ambiguous on customer's request → ESCALATE
│
├─ Customer is frustrated but issue is simple
│  → Acknowledge frustration + resolve
│  → Escalate ONLY if customer reiterates demand for human
│
├─ Multiple customer matches found → ASK for more identifiers
│  (don't pick one heuristically)
│
└─ Agent can't make progress after reasonable attempts → ESCALATE
   with structured handoff summary
```

---

## ⚡ Error Category Quick Reference

| Category | Retryable? | Agent Action | Example |
|---|---|---|---|
| **Transient** | Usually yes | Wait + retry | Database timeout |
| **Validation** | No (fix input) | Correct the input, retry | Invalid order ID format |
| **Business** | No | Explain to user, escalate | Return window expired |
| **Permission** | No | Escalate | Unauthorized access |

---

## 📊 Batch vs. Synchronous Decision

| Criterion | Synchronous API | Message Batches API |
|---|---|---|
| **Cost** | Full price | **50% savings** |
| **Latency** | Immediate | Up to 24 hours |
| **Tool calling** | Multi-turn supported | ❌ No multi-turn tools |
| **Use when** | Blocking workflows | Non-blocking workflows |
| **Examples** | Pre-merge checks, live support | Overnight reports, weekly audits |

---

## 📐 Context Management Strategies

| Problem | Solution |
|---|---|
| Transactional facts lost in long conversations | Extract into persistent "case facts" block |
| Middle of long inputs processed poorly | Place key summaries at beginning; use section headers |
| Tool returns 40 fields, only 5 needed | PostToolUse hook to trim to relevant fields |
| Context degradation in long sessions | Scratchpad files + `/compact` + subagent delegation |
| Cross-contamination in multi-issue sessions | Structured per-issue data layers |
| Stale context after codebase refactor | New session with structured summary of key findings |

---

## 🏗️ Multi-Agent Architecture Checklist

```
✅ Coordinator has Task tool in allowedTools
✅ Each subagent has only 4-5 relevant tools
✅ Subagent prompts include ALL needed context explicitly
✅ Critical rules enforced via hooks, not just prompts
✅ Errors propagated with structured context (not generic messages)
✅ Local error recovery attempted before propagating
✅ Iterative verification loop for coverage gaps
✅ Parallel subagent spawning for independent tasks
✅ Structured handoff summaries for human escalation
✅ Crash recovery via structured state manifests
```

---

## 📝 CLAUDE.md & Rules Checklist

```
✅ Team standards in project-level .claude/CLAUDE.md (not user-level)
✅ Large CLAUDE.md split into .claude/rules/ or @import
✅ Path-scoped rules for file-type conventions (glob patterns)
✅ Verbose skills use context: fork
✅ Destructive skills restricted with allowed-tools
✅ Shared commands in .claude/commands/ (not user directory)
✅ MCP secrets via ${ENV_VAR} expansion (not hardcoded)
✅ Shared MCP servers in .mcp.json; personal in ~/.claude.json
```

---

## 🎓 Last-Minute Review Checklist

> [!TIP]
> ### Before the Exam — Verify You Know:
>
> **The #1 answer for each category:**
> - Loop termination → `stop_reason`
> - Tool selection factor → **tool descriptions**
> - Business rule enforcement → **programmatic hooks** (not prompts)
> - Guaranteed structured output → **`tool_use` with JSON schemas**
> - Prevent hallucination of missing data → **nullable fields**
> - Escalation trigger → **explicit customer request for human**
> - Unreliable escalation signals → **sentiment + self-reported confidence**
> - Improve output consistency → **few-shot examples** (not more instructions)
> - Error handling anti-pattern → **silent suppression (empty results as success)**
> - Context preservation → **persistent case facts block**
> - CI/CD mode → **`-p` flag** (non-interactive)
> - Rules for scattered files → **glob patterns in `.claude/rules/`**

---

## 📚 Complete Training Guide Index

| Part | Chapters | Topics |
|------|----------|--------|
| [Part 1](file:///Users/pushparajnaik/.gemini/antigravity-ide/brain/3e8edcdd-14aa-4eae-ba97-d2e555bf37aa/CCAF_Training_Guide_Part1.md) | Ch 0-2 | Foundations, Core Concepts, Domain 1: Agentic Architecture |
| [Part 2](file:///Users/pushparajnaik/.gemini/antigravity-ide/brain/3e8edcdd-14aa-4eae-ba97-d2e555bf37aa/CCAF_Training_Guide_Part2.md) | Ch 3-4 | Domain 2: Tool Design & MCP, Domain 3: Claude Code Configuration |
| [Part 3](file:///Users/pushparajnaik/.gemini/antigravity-ide/brain/3e8edcdd-14aa-4eae-ba97-d2e555bf37aa/CCAF_Training_Guide_Part3.md) | Ch 5-6 | Domain 4: Prompt Engineering, Domain 5: Context Management |
| [Cheat Sheet](file:///Users/pushparajnaik/.gemini/antigravity-ide/brain/3e8edcdd-14aa-4eae-ba97-d2e555bf37aa/CCAF_Cheat_Sheet.md) | — | Quick reference tables, decision trees, last-minute review |

## 📊 Complete Question Bank Index

| Part | Questions | Domain |
|------|-----------|--------|
| [Part 1](file:///Users/pushparajnaik/.gemini/antigravity-ide/brain/3e8edcdd-14aa-4eae-ba97-d2e555bf37aa/claude_architect_foundations_exam_part1.md) | Q1–Q75 | Agentic Architecture & Orchestration |
| [Part 2](file:///Users/pushparajnaik/.gemini/antigravity-ide/brain/3e8edcdd-14aa-4eae-ba97-d2e555bf37aa/claude_architect_foundations_exam_part2.md) | Q76–Q135 | Tool Design & MCP Integration |
| [Part 3](file:///Users/pushparajnaik/.gemini/antigravity-ide/brain/3e8edcdd-14aa-4eae-ba97-d2e555bf37aa/claude_architect_foundations_exam_part3.md) | Q136–Q195 | Claude Code Configuration & Workflows |
| [Part 4](file:///Users/pushparajnaik/.gemini/antigravity-ide/brain/3e8edcdd-14aa-4eae-ba97-d2e555bf37aa/claude_architect_foundations_exam_part4.md) | Q196–Q255 | Prompt Engineering & Structured Output |
| [Part 5](file:///Users/pushparajnaik/.gemini/antigravity-ide/brain/3e8edcdd-14aa-4eae-ba97-d2e555bf37aa/claude_architect_foundations_exam_part5.md) | Q256–Q310 | Context Management & Reliability |
| [Part 6](file:///Users/pushparajnaik/.gemini/antigravity-ide/brain/3e8edcdd-14aa-4eae-ba97-d2e555bf37aa/claude_architect_foundations_exam_part6.md) | Q311–Q350 | 🔥 Practice Test Questions (All Domains) |
| [Index](file:///Users/pushparajnaik/.gemini/antigravity-ide/brain/3e8edcdd-14aa-4eae-ba97-d2e555bf37aa/claude_architect_foundations_exam_index.md) | — | Master index with topic coverage map |

---

*Good luck on your exam! 🚀*
