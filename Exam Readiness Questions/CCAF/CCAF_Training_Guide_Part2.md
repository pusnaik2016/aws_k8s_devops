# 📘 CCAF Training Guide — Part 2

## Domain 2: Tool Design & MCP Integration (18%) + Domain 3: Claude Code Configuration (20%)

---

# Chapter 3: Domain 2 — Tool Design & MCP Integration

## 3.1 How Claude Selects Tools

When Claude has access to multiple tools, it reads each tool's **description** to decide which one to call. This is the single most important factor in tool selection.

```
Claude receives a user query: "Check my order status"

Available tools:
┌──────────────────────────────────────────────────────────────┐
│ Tool: get_customer                                           │
│ Description: "Retrieves customer information"  ← TOO VAGUE  │
├──────────────────────────────────────────────────────────────┤
│ Tool: lookup_order                                           │
│ Description: "Retrieves order details"         ← TOO VAGUE  │
└──────────────────────────────────────────────────────────────┘

Problem: Both descriptions are so similar that Claude can't reliably
         distinguish between them.
```

### Writing Effective Tool Descriptions

```
✅ GOOD tool description:

Tool: lookup_order
Description: "Retrieves order details including status, shipping info,
and line items. Input: order_id (format: ORD-XXXXX) or tracking_number.
Use this when the customer asks about order status, delivery tracking,
or order contents. Do NOT use for customer account information —
use get_customer for that."

Why this works:
• States what it returns (status, shipping, line items)
• Specifies input format (ORD-XXXXX)
• Explains WHEN to use it (order status, delivery, contents)
• Explains when NOT to use it (differentiates from get_customer)
```

### The Tool Description Checklist

Every tool description should include:

| Element | Example |
|---|---|
| **Purpose** | "Retrieves order details including status and shipping info" |
| **Input format** | "Accepts order_id in format ORD-XXXXX" |
| **Example queries** | "Use for: 'where is my order', 'order status'" |
| **Output** | "Returns: status, ship_date, carrier, tracking_url, line_items" |
| **Boundaries** | "Do NOT use for customer account info — use get_customer instead" |
| **Edge cases** | "Returns empty array if order has no line items" |

---

## 3.2 Tool Naming and Splitting

### Overlapping Tools — A Common Problem

```
❌ PROBLEM: Two tools with overlapping names and descriptions

  analyze_content: "Analyzes content for key information"
  analyze_document: "Analyzes a document for insights"

  → Claude can't tell them apart → misrouting

✅ FIX: Rename and differentiate

  extract_web_results: "Extracts structured data from web search results.
                        Input: raw HTML or search result JSON."
  
  summarize_document: "Summarizes a PDF or document file.
                       Input: file path to a document."
```

### When to Split vs. Consolidate Tools

```
Split a generic tool into specific tools:
  
  ❌ analyze_document (does everything)
  
  ✅ extract_data_points  → pulls structured data from docs
     summarize_content    → creates summaries
     verify_claim         → fact-checks claims against source
```

---

## 3.3 How Many Tools Is Too Many?

```
Optimal: 4-5 tools per agent
  → High selection reliability
  → Low decision complexity

Problematic: 18+ tools
  → Selection reliability degrades significantly
  → Agent misuses tools outside its specialization

                Tool Selection Reliability
   100% ┤██████████████████████
    90% ┤█████████████████████
    80% ┤████████████████████
    70% ┤██████████████
    60% ┤███████
    50% ┤
        └───┬──┬──┬──┬──┬──┬──┬──┬──
            2  4  6  8  10 12 14 16 18
                  Number of Tools
```

> [!WARNING]
> **Exam Key**: Agents with tools outside their specialization tend to misuse them. A synthesis agent with web search tools will start searching instead of synthesizing.

---

## 3.4 `tool_choice` Configuration

The `tool_choice` parameter controls how Claude selects tools:

| Setting | Behavior | Use Case |
|---|---|---|
| `"auto"` | Claude may call a tool OR return text | General conversation; might not get structured output |
| `"any"` | Claude MUST call a tool, but chooses which | Guaranteed structured output when multiple schemas exist |
| `{"type":"tool","name":"X"}` | Claude MUST call tool "X" specifically | Force a specific tool first (e.g., extract_metadata) |

### Decision Matrix

```
Need structured output guaranteed?
├── NO  → tool_choice: "auto"
└── YES → Do you care which tool?
          ├── NO  → tool_choice: "any" (model picks the tool)
          └── YES → tool_choice: {"type":"tool","name":"specific_tool"}
```

### Forced Tool Ordering Example

```
Turn 1: tool_choice: {"type":"tool","name":"extract_metadata"}
        → Metadata extraction runs first (guaranteed)

Turn 2: tool_choice: "auto"
        → Claude freely chooses enrichment tools
```

---

## 3.5 Structured Error Responses for MCP Tools

### The Problem with Generic Errors

```
❌ Every tool returns: {"error": "Operation failed"}

Agent behavior:
  • Retries policy rejections endlessly (will never succeed)
  • Gives up on timeouts immediately (might succeed with retry)
  • Can't explain failures to users
```

### The MCP `isError` Flag Pattern

```json
{
  "isError": true,
  "errorCategory": "transient",
  "isRetryable": true,
  "retryAfterMs": 2000,
  "description": "Database connection timeout. Service typically recovers within 2 seconds."
}
```

### Four Error Categories

| Category | Meaning | Retryable? | Agent Should... |
|---|---|---|---|
| **Transient** | Timeout, service down temporarily | Usually yes | Wait and retry |
| **Validation** | Invalid input format | No (fix input) | Fix the input, retry |
| **Business** | Policy violation (e.g., expired return window) | No | Explain to user, escalate |
| **Permission** | Unauthorized access | No | Escalate to appropriate channel |

### Access Failure vs. Valid Empty Results

```
❌ BOTH return: {"results": []}

  Case 1: Database timeout → Should retry!
  Case 2: No matching records → Successful query, just empty

✅ Distinguish them:

  Case 1: {"isError": true, "errorCategory": "transient", 
           "description": "Database timeout"}
  
  Case 2: {"results": [], "isError": false}  ← Valid empty result
```

> [!CAUTION]
> **Exam Trap**: Returning empty results as success (silently suppressing errors) is an **anti-pattern**. The coordinator thinks the query succeeded with no matches, when the data source was actually unavailable.

---

## 3.6 MCP Server Configuration

### Two Scopes

```
Project-level: .mcp.json (in repo root)
  ├── Version-controlled ✓
  ├── Shared with team ✓
  └── For: production tools everyone needs (Jira, GitHub)

User-level: ~/.claude.json
  ├── NOT version-controlled ✓
  ├── Personal only ✓
  └── For: experimental/personal servers
```

### Environment Variable Expansion

```json
// .mcp.json — committed to repo (safe!)
{
  "mcpServers": {
    "github": {
      "command": "github-mcp-server",
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"  // ← resolved at runtime
      }
    }
  }
}
```

Each developer sets `GITHUB_TOKEN` in their local environment. The `.mcp.json` stays clean.

### MCP Resources vs. MCP Tools

| MCP Feature | Purpose | Example |
|---|---|---|
| **Tools** | Actions the agent performs | `create_issue`, `query_database` |
| **Resources** | Read-only catalogs the agent browses | Database schemas, issue summaries, documentation indexes |

> **Resources reduce exploratory tool calls.** Instead of the agent making 10 tool calls to discover what's available, it can browse a resource catalog directly.

---

## 3.7 Built-in Tools (Grep, Glob, Read, Write, Edit, Bash)

### Quick Reference

| Tool | Purpose | Use For |
|---|---|---|
| **Grep** | Search file **contents** | "Find all callers of `processRefund`" |
| **Glob** | Match file **paths/names** | "Find all `*.test.tsx` files" |
| **Read** | Load file contents | "Show me the contents of `auth.py`" |
| **Write** | Replace entire file | Fallback when Edit fails |
| **Edit** | Targeted text modification | "Change line 42 from X to Y" |
| **Bash** | Run shell commands | "Run the test suite" |

### Grep vs. Glob — The Key Distinction

```
Grep = CONTENT search (what's INSIDE files)
  "Find all files that contain 'processRefund'" → Grep

Glob = PATH search (file NAMES and locations)
  "Find all files named *.test.tsx" → Glob
```

### When Edit Fails → Use Read + Write

```
Edit tool: tries to find unique anchor text to modify
  ├── Anchor text is unique → Edit succeeds ✓
  └── Anchor text appears 4 times → Edit FAILS ✗
      → Fallback: Read the full file, then Write with modifications
```

### Codebase Exploration Pattern

```
Step 1: Grep to find entry points
  → "Search for 'main(' or 'app.listen'" 

Step 2: Read to follow imports
  → Read the entry file, find import statements

Step 3: Grep to trace function usage
  → "Search for 'processPayment' across codebase"

Step 4: Read specific files for deep understanding

❌ DON'T: Read all files upfront (wasteful)
✅ DO: Build understanding incrementally
```

---

# Chapter 4: Domain 3 — Claude Code Configuration & Workflows

## 4.1 The CLAUDE.md Hierarchy

CLAUDE.md files provide instructions that Claude Code follows automatically. They exist at three levels:

```
Level 1: User-level (~/.claude/CLAUDE.md)
  ├── Applies only to YOU
  ├── NOT shared via version control
  └── For: personal preferences, styles

Level 2: Project-level (.claude/CLAUDE.md or root CLAUDE.md)
  ├── Applies to EVERYONE on the project
  ├── Version-controlled ✓
  └── For: team coding standards, testing conventions

Level 3: Directory-level (subdirectory CLAUDE.md)
  ├── Applies when editing files in that directory
  ├── Version-controlled ✓
  └── For: package-specific conventions
```

### Common Exam Scenario

```
❌ New team member doesn't receive coding standards
   → Standards are in ~/.claude/CLAUDE.md (user-level)
   → Only the original developer has them!

✅ Move to .claude/CLAUDE.md (project-level)
   → Version-controlled → available to everyone who clones the repo
```

### Modular Organization

For large projects, avoid monolithic CLAUDE.md files:

```
Option A: @import syntax
  CLAUDE.md:
    @import ./standards/testing.md
    @import ./standards/api-conventions.md

Option B: .claude/rules/ directory
  .claude/rules/
    ├── testing.md
    ├── api-conventions.md
    ├── deployment.md
    └── terraform.md
```

---

## 4.2 Path-Specific Rules with Glob Patterns

Rules in `.claude/rules/` can have **YAML frontmatter** with path patterns:

```yaml
# .claude/rules/terraform.md
---
paths:
  - "terraform/**/*"
  - "infra/**/*.tf"
---

## Terraform Conventions
- Always use variables for region and environment
- Tag all resources with 'environment' and 'team'
- Use remote state with S3 backend
```

**These rules load ONLY when editing matching files.** This means:
- Terraform rules don't load when editing React components
- Test rules don't load when editing infrastructure code
- Saves tokens and reduces irrelevant context

### Why Glob Patterns > Directory CLAUDE.md

```
Problem: Test files are spread everywhere
  src/
    components/
      Button.tsx
      Button.test.tsx     ← test file
    utils/
      format.ts
      format.test.ts      ← test file
    api/
      orders.ts
      orders.test.ts      ← test file

Directory CLAUDE.md approach:
  ❌ Need a CLAUDE.md in EVERY directory → impractical

Glob pattern approach:
  ✅ .claude/rules/testing.md with paths: ["**/*.test.*"]
     → Matches ALL test files regardless of location
```

---

## 4.3 Custom Slash Commands and Skills

### Slash Commands

```
Project-scoped: .claude/commands/    → shared with team via git
User-scoped:    ~/.claude/commands/  → personal, not shared

Example: .claude/commands/review.md
  "Run the team's standard code review checklist:
   1. Check for security vulnerabilities
   2. Verify error handling patterns
   3. Review test coverage"
```

### Skills (`.claude/skills/`)

Skills are more advanced than commands. They support **frontmatter configuration**:

```yaml
# .claude/skills/analyze-codebase/SKILL.md
---
context: fork           # Run in isolated context
allowed-tools:          # Restrict tool access
  - Read
  - Grep
  - Glob
argument-hint: "path/to/analyze"  # Prompt for args
---

## Codebase Analysis Skill
Analyze the provided codebase for architecture patterns,
dependencies, and code quality metrics.
```

### Frontmatter Options

| Option | Effect | When to Use |
|---|---|---|
| `context: fork` | Runs in isolated sub-agent context | Verbose output that would pollute main conversation |
| `allowed-tools` | Restricts which tools the skill can use | Prevent destructive actions (e.g., no Write/Bash) |
| `argument-hint` | Prompts user for required parameters | Skills that need a file path or component name |

### Skills vs. CLAUDE.md — When to Use Each

```
CLAUDE.md:
  ├── Always loaded automatically
  ├── Universal standards that apply to all work
  └── Example: "Always use TypeScript strict mode"

Skills:
  ├── Invoked on-demand by the developer
  ├── Task-specific workflows
  └── Example: "Analyze codebase architecture"
```

---

## 4.4 Plan Mode vs. Direct Execution

### Decision Matrix

```
Is the task...

Simple, single-file, clear fix?
  → DIRECT EXECUTION
  Examples:
  • Fix a null check (stack trace shows exactly where)
  • Add a date validation to one function
  • Fix a typo

Complex, multi-file, architectural?
  → PLAN MODE
  Examples:
  • Restructure monolith → microservices (dozens of files)
  • Library migration affecting 45+ files
  • New feature with multiple valid approaches
```

### The Explore Subagent

During plan mode, verbose discovery can exhaust the context window. The **Explore subagent** isolates this:

```
Without Explore:
  Main context fills with: file listings, import traces,
  function signatures, test results → CONTEXT EXHAUSTION

With Explore subagent:
  Explore agent does verbose investigation → returns SUMMARY
  Main context stays clean for high-level coordination
```

### Combining Modes

```
Phase 1: PLAN MODE
  → Explore codebase
  → Understand dependencies
  → Design migration approach
  → Choose between Strategy A and Strategy B

Phase 2: DIRECT EXECUTION
  → Implement the chosen approach
  → Apply the planned changes
```

---

## 4.5 Iterative Refinement Techniques

### Technique 1: Input/Output Examples

```
❌ Prose: "Convert dates to ISO format and normalize names to uppercase"
   → Inconsistent interpretation across runs

✅ Examples:
   Input:  {"name": "john doe", "date": "3/15/2024"}
   Output: {"name": "JOHN DOE", "date": "2024-03-15"}
   
   Input:  {"name": "jane smith", "date": "March 15, 2024"}
   Output: {"name": "JANE SMITH", "date": "2024-03-15"}
```

### Technique 2: Test-Driven Iteration

```
Step 1: Write test suite first
  → Expected behavior tests
  → Edge case tests
  → Performance tests

Step 2: Have Claude implement

Step 3: Run tests → share failures with Claude
  "Test 3 failed: test_null_input
   Expected: None
   Got: ValueError('cannot process null')
   
   Please fix the null handling."

Step 4: Claude fixes → re-run tests → iterate
```

### Technique 3: The Interview Pattern

```
You: "I need to add a caching layer to our API"

Claude asks:
  "Before implementing, let me ask a few questions:
   1. What's your cache invalidation strategy?
   2. Should the cache be shared across instances?
   3. What's the expected cache hit ratio?
   4. How should cache failures be handled?
   5. Do you need time-based TTL or event-based invalidation?"

→ Surfaces considerations you might not have anticipated
```

### Technique 4: Interacting vs. Independent Issues

```
Interacting issues (fix together):
  "The retry backoff interacts with the timeout,
   which affects the circuit breaker threshold"
  → Report ALL THREE in one message

Independent issues (fix sequentially):
  "Formatting is wrong AND performance is slow"
  → Fix formatting first, then performance separately
```

---

## 4.6 CI/CD Integration

### Running Claude Code in CI

```bash
# ❌ WRONG: Hangs waiting for interactive input
claude "Review this PR for security issues"

# ✅ CORRECT: Non-interactive mode with -p flag
claude -p "Review this PR for security issues"

# ✅ STRUCTURED OUTPUT for automated processing
claude -p --output-format json --json-schema '{
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "file": {"type": "string"},
      "line": {"type": "integer"},
      "severity": {"type": "string"},
      "description": {"type": "string"}
    }
  }
}' "Review this PR for security issues"
```

### Key CI/CD Concepts

| Concept | Detail |
|---|---|
| `-p` / `--print` flag | Non-interactive mode — essential for CI |
| `--output-format json` | Machine-parseable output |
| `--json-schema` | Enforce specific output structure |
| **Session isolation** | Don't review with the same session that generated code |
| **Prior findings** | Include previous review results to avoid duplicate comments |
| **CLAUDE.md in CI** | Provides testing standards and fixtures to improve output |

### Self-Review Limitation

```
❌ Same session generates AND reviews code:
   → Model retains reasoning context
   → Less likely to question its own decisions
   → Blind spots for subtle issues

✅ Independent review instance:
   → Fresh context, no prior reasoning
   → More effective at finding issues
   → Like getting a code review from a different person
```

---

## 4.7 Domain 2 & 3 — Key Exam Tips

> [!CAUTION]
> ### Must-Know Items
> 1. **Tool descriptions are #1** for selection — not names, not prompts
> 2. **4-5 tools per agent** is optimal; 18+ degrades reliability
> 3. **`tool_choice: "any"` guarantees a tool call**; `"auto"` may return text
> 4. **MCP errors need categories** — transient, validation, business, permission
> 5. **Empty results ≠ errors** — distinguish access failures from valid empty results
> 6. **Project `.mcp.json`** for team; **user `~/.claude.json`** for personal
> 7. **`${ENV_VAR}`** syntax in `.mcp.json` for secrets
> 8. **Grep = content search**; **Glob = path/name search**
> 9. **User-level CLAUDE.md is NOT shared** — use project-level for team standards
> 10. **`context: fork`** prevents verbose skill output from polluting main conversation
> 11. **Plan mode** for complex/architectural; **direct execution** for simple/clear fixes
> 12. **`-p` flag** is essential for running Claude Code in CI/CD pipelines
> 13. **Path-specific rules** with glob patterns > directory-level CLAUDE.md for scattered files

---
