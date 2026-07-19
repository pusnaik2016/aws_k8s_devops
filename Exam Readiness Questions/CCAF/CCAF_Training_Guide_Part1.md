# 📘 Claude Certified Architect – Foundations (CCAF)
# Complete Preparation & Training Guide

---

## PART 1: Foundations & Domain 1 — Agentic Architecture

---

# Chapter 0: Before You Begin

## What Is This Certification?

The **Claude Certified Architect – Foundations (CCAF)** is Anthropic's official certification that validates your ability to design and implement production-grade applications with Claude. It tests practical judgment — not just theory — across five core technology areas:

| Technology | What It Is |
|---|---|
| **Claude API** | The programmatic interface to Claude models |
| **Claude Agent SDK** | Framework for building autonomous AI agents |
| **Claude Code** | Claude-powered coding assistant for developers |
| **Model Context Protocol (MCP)** | Open standard for connecting AI to external tools/data |
| **Prompt Engineering** | Techniques for getting reliable, structured output from Claude |

## Exam at a Glance

```
┌──────────────────────────────────────────────────────┐
│              CCAF EXAM SNAPSHOT                       │
├──────────────────────────────────────────────────────┤
│  Questions:     60 multiple choice                   │
│  Time:          120 minutes (2 min/question)         │
│  Format:        4 scenarios, each with questions     │
│  Passing Score: 720 / 1000                           │
│  Fee:           $125 USD                             │
│  Validity:      12 months                            │
│  Delivery:      Online proctored or test center      │
└──────────────────────────────────────────────────────┘
```

## Domain Weightings — Where to Focus Your Study

```
Domain 1: Agentic Architecture & Orchestration    ████████████████████░░  27%  ← HIGHEST
Domain 2: Tool Design & MCP Integration           ████████████░░░░░░░░░░  18%
Domain 3: Claude Code Configuration & Workflows   █████████████░░░░░░░░░  20%
Domain 4: Prompt Engineering & Structured Output   █████████████░░░░░░░░░  20%
Domain 5: Context Management & Reliability         ██████████░░░░░░░░░░░░  15%
```

> [!TIP]
> **Study Strategy**: Domain 1 is worth 27% — almost a third of the exam. Master it thoroughly. Domains 3 and 4 together are another 40%. These three domains cover 87% of the exam.

## Exam Scenarios

The exam uses **scenario-based questions**. You'll see 4 out of 6 possible scenarios:

| Scenario | What You're Building |
|---|---|
| 1. Customer Support Agent | Handling returns, billing, account issues with escalation |
| 2. Code Generation with Claude Code | Configuring Claude Code for team development |
| 3. Multi-Agent Research System | Coordinator + search/analysis/synthesis subagents |
| 4. Developer Productivity Tools | Codebase exploration, boilerplate generation |
| 5. Claude Code for CI/CD | Automated code reviews, test generation in pipelines |
| 6. Structured Data Extraction | Extracting data from unstructured docs with JSON schemas |

---

# Chapter 1: Core Concepts — The Building Blocks

## 1.1 What Is Claude?

Claude is a large language model (LLM) created by Anthropic. Think of it as an extremely capable AI assistant that can:
- Understand and generate text
- Follow complex instructions
- Use tools when given access
- Reason through multi-step problems

**Key insight for the exam**: Claude is stateless — it doesn't remember previous conversations. Every API request must include the full conversation history.

## 1.2 What Is the Claude API?

The Claude API is how you programmatically interact with Claude. Instead of chatting in a web interface, you send HTTP requests with:
- A **system prompt** (instructions for Claude's behavior)
- **Messages** (the conversation history)
- **Tools** (functions Claude can call)
- **Configuration** (model, max_tokens, temperature, tool_choice)

### Basic API Request Structure

```json
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 1024,
  "system": "You are a helpful customer support agent.",
  "messages": [
    {"role": "user", "content": "I need to return my order #12345"}
  ],
  "tools": [
    {
      "name": "lookup_order",
      "description": "Look up order details by order ID",
      "input_schema": {
        "type": "object",
        "properties": {
          "order_id": {"type": "string"}
        },
        "required": ["order_id"]
      }
    }
  ]
}
```

### API Response — The Critical `stop_reason` Field

Every API response includes a `stop_reason`:

| `stop_reason` | Meaning | What Your Code Should Do |
|---|---|---|
| `"end_turn"` | Claude is done responding | **Stop the loop** — present response to user |
| `"tool_use"` | Claude wants to call a tool | **Continue the loop** — execute the tool, send results back |
| `"max_tokens"` | Response was cut off | Handle truncation |

> [!IMPORTANT]
> **EXAM CRITICAL**: `stop_reason` is THE definitive signal for controlling agentic loops. This is tested heavily.

## 1.3 What Is an Agent?

An **agent** is an AI system that can take actions autonomously. Unlike a simple chatbot that just responds to questions, an agent:

1. **Receives a task** from the user
2. **Reasons** about what to do
3. **Takes actions** (calls tools, reads files, queries databases)
4. **Observes results** from those actions
5. **Decides next steps** based on results
6. **Repeats** until the task is complete

This cycle is called the **agentic loop**.

## 1.4 What Is the Claude Agent SDK?

The Claude Agent SDK is a framework for building agents with Claude. It provides:

- **AgentDefinition**: Configuration for defining agents (name, system prompt, tools)
- **Task tool**: Mechanism for spawning subagents
- **Hooks**: Interceptors for tool calls and results (PostToolUse, tool call interception)
- **Session management**: Resume, fork, named sessions

## 1.5 What Is MCP (Model Context Protocol)?

MCP is an open standard for connecting AI models to external data sources and tools. Think of it as a "USB port" for AI — a standardized way to plug in capabilities.

```
┌─────────┐     MCP Protocol     ┌─────────────┐
│  Claude  │◄───────────────────►│  MCP Server  │
│  Agent   │   (standardized)    │  (Jira, DB,  │
│          │                     │   GitHub...) │
└─────────┘                     └─────────────┘
```

MCP provides:
- **Tools**: Actions the agent can perform (query database, create ticket)
- **Resources**: Read-only data catalogs (database schemas, documentation)

## 1.6 What Is Claude Code?

Claude Code is an AI-powered coding assistant that works in your terminal. It can:
- Read, write, and edit files
- Run shell commands
- Navigate codebases using built-in tools (Grep, Glob, Read, Write, Edit, Bash)
- Be configured with CLAUDE.md files for project-specific conventions

---

# Chapter 2: Domain 1 — Agentic Architecture & Orchestration (27%)

This is the **highest-weighted domain** on the exam. Master it.

## 2.1 The Agentic Loop — How Agents Work

### The Basic Loop

```
                    ┌──────────────────────────┐
                    │    Send request to Claude │
                    │    (with conversation     │
                    │     history + tools)       │
                    └──────────┬───────────────┘
                               │
                               ▼
                    ┌──────────────────────────┐
                    │  Claude responds with:    │
                    │  - Text content           │
                    │  - Tool use requests      │
                    │  - stop_reason            │
                    └──────────┬───────────────┘
                               │
                    ┌──────────┴───────────────┐
                    │                          │
              ┌─────▼─────┐            ┌──────▼──────┐
              │stop_reason│            │ stop_reason  │
              │"end_turn" │            │ "tool_use"   │
              └─────┬─────┘            └──────┬──────┘
                    │                          │
                    ▼                          ▼
              ┌───────────┐          ┌──────────────────┐
              │  DONE!    │          │ Execute the tool  │
              │  Present  │          │ Append result to  │
              │  response │          │ conversation      │
              └───────────┘          └────────┬─────────┘
                                              │
                                              │ Loop back ↑
                                              └──────────────┘
```

### Pseudocode for an Agentic Loop

```python
def run_agent(user_message, tools, system_prompt):
    messages = [{"role": "user", "content": user_message}]
    
    while True:
        # Send request to Claude
        response = claude_api.create_message(
            system=system_prompt,
            messages=messages,
            tools=tools
        )
        
        # Check stop_reason — THE definitive signal
        if response.stop_reason == "end_turn":
            # Claude is done — return the response
            return response.content
        
        elif response.stop_reason == "tool_use":
            # Claude wants to call a tool
            # 1. Add Claude's response to messages
            messages.append({"role": "assistant", "content": response.content})
            
            # 2. Execute each tool call
            for tool_call in response.tool_use_blocks:
                result = execute_tool(tool_call.name, tool_call.input)
                
                # 3. Add tool result to messages
                messages.append({
                    "role": "user",
                    "content": [{
                        "type": "tool_result",
                        "tool_use_id": tool_call.id,
                        "content": result
                    }]
                })
            
            # 4. Loop continues — send updated messages back to Claude
```

### ❌ Anti-Patterns — What NOT To Do

The exam heavily tests anti-patterns. Memorize these:

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| **Parsing text for "I'm done" phrases** | Brittle string matching; model may say "I'm done" with pending tool calls | Check `stop_reason` field |
| **Arbitrary iteration caps (e.g., max 5 loops)** | Kills complex tasks mid-execution | Use `stop_reason: "end_turn"` as primary termination |
| **Checking for assistant text as completion** | Model may include text alongside tool_use blocks | Check `stop_reason`, not text presence |

> [!CAUTION]
> **Exam Trap**: Questions will present plausible-sounding alternatives like "add more closing phrases to the detection list" or "increase the iteration cap to 10." These are still anti-patterns. The ONLY correct primary termination mechanism is `stop_reason`.

---

## 2.2 Multi-Agent Systems — The Hub-and-Spoke Model

### What Is Multi-Agent Architecture?

Instead of one agent doing everything, you split work across specialized agents:

```
                        ┌──────────────┐
                        │  COORDINATOR │
                        │    Agent     │
                        │              │
                        │ • Decomposes │
                        │   tasks      │
                        │ • Delegates  │
                        │ • Aggregates │
                        │   results    │
                        └──┬───┬───┬──┘
                           │   │   │
              ┌────────────┘   │   └────────────┐
              │                │                │
        ┌─────▼──────┐  ┌─────▼──────┐  ┌──────▼─────┐
        │  SEARCH    │  │  ANALYSIS  │  │ SYNTHESIS  │
        │  Subagent  │  │  Subagent  │  │ Subagent   │
        │            │  │            │  │            │
        │ Tools:     │  │ Tools:     │  │ Tools:     │
        │ • web_search│  │ • read_doc │  │ • verify   │
        │ • fetch_url│  │ • extract  │  │ • format   │
        └────────────┘  └────────────┘  └────────────┘
```

### Key Principles

#### 1. Isolated Context
> **Subagents do NOT inherit the coordinator's conversation history.**

This is one of the most tested concepts. Each subagent starts with a blank slate. The coordinator must explicitly pass all needed context in the subagent's prompt.

```
❌ WRONG assumption:
   Coordinator conversation → automatically available to subagent

✅ CORRECT:
   Coordinator must explicitly include findings in subagent's prompt:
   "Here are the search results from the web search agent: [results].
    Please synthesize these into a report."
```

#### 2. The Task Tool
The **Task tool** is how coordinators spawn subagents. The coordinator's `allowedTools` must include `"Task"`.

```
❌ If allowedTools doesn't include "Task":
   → Coordinator CANNOT spawn subagents
   → It will describe what it wants to do but never actually do it

✅ Coordinator's allowedTools: ["Task", ...]
   → Can emit Task tool calls to spawn subagents
```

#### 3. Parallel Subagent Execution
To run subagents in parallel, emit **multiple Task tool calls in a single response**:

```
❌ Sequential (slow):
   Turn 1: Spawn search agent    → wait for result
   Turn 2: Spawn analysis agent  → wait for result

✅ Parallel (fast):
   Turn 1: Spawn search agent AND analysis agent simultaneously
   (Multiple Task tool calls in one response)
```

#### 4. Dynamic Subagent Selection
The coordinator should **analyze query requirements** and select appropriate subagents:

```
Simple query: "What's the capital of France?"
→ Only invoke search agent (skip analysis, synthesis)

Complex query: "Compare AI regulation across EU, US, and China"
→ Invoke search + analysis + synthesis (full pipeline)
```

#### 5. Task Decomposition
The coordinator decomposes user queries into subtasks. **Narrow decomposition** is a common failure:

```
❌ User: "Impact of AI on creative industries"
   Coordinator decomposes into:
   1. "AI in digital art"
   2. "AI in graphic design"
   3. "AI in photography"
   → Missing: music, writing, film, gaming, fashion...

✅ Better decomposition:
   1. "AI in visual arts (digital art, graphic design, photography)"
   2. "AI in music and audio production"
   3. "AI in writing and publishing"
   4. "AI in film and video production"
   5. "AI in gaming and interactive media"
```

#### 6. Iterative Refinement Loops

```
   ┌──────────────────────────────────────────────┐
   │                                              │
   │   Coordinator evaluates synthesis output     │
   │                                              │
   │   Coverage sufficient?                       │
   │   ├── YES → Generate final report            │
   │   └── NO  → Identify gaps                    │
   │            → Re-delegate to search/analysis  │
   │            → Re-invoke synthesis              │
   │            → Loop back to evaluation ↑        │
   │                                              │
   └──────────────────────────────────────────────┘
```

---

## 2.3 AgentDefinition — Configuring Agents

Each agent is configured with an `AgentDefinition`:

```python
agent_definition = {
    "name": "search_agent",
    "description": "Searches the web for information on assigned topics",
    "system_prompt": "You are a research agent specializing in web search...",
    "allowed_tools": ["web_search", "fetch_url"],  # ONLY search tools
}
```

### Key Configuration Points

| Setting | Purpose | Exam Tip |
|---|---|---|
| `description` | What the agent does | Used by coordinator for delegation decisions |
| `system_prompt` | Behavior instructions | Should specify goals, not step-by-step procedures |
| `allowed_tools` | Tools the agent can use | Apply Principle of Least Privilege (4-5 tools max) |

---

## 2.4 Context Passing Between Agents

### The Problem
Subagents have isolated context. If you don't pass information explicitly, the subagent works blind.

### The Solution — Structured Data Passing

```
Coordinator receives search results:
{
  "claim": "AI market valued at $150B",
  "source_url": "https://example.com/report",
  "source_name": "Industry Report 2024",
  "publication_date": "2024-03-15",
  "excerpt": "The global AI market reached $150 billion..."
}

Coordinator passes to synthesis subagent:
"Synthesize these findings into a report. Preserve all
 source attribution:
 
 Finding 1:
 - Claim: AI market valued at $150B
 - Source: Industry Report 2024 (https://example.com/report)
 - Date: 2024-03-15
 - Evidence: 'The global AI market reached $150 billion...'"
```

> [!IMPORTANT]
> **Always separate content from metadata** (source URLs, document names, page numbers). This preserves attribution through the pipeline.

---

## 2.5 Programmatic Enforcement vs. Prompt-Based Guidance

This is one of the **most critical distinctions** on the exam.

### When to Use Each

| Approach | Guarantee Level | Use When |
|---|---|---|
| **Prompt instructions** | Probabilistic (~88-95%) | Nice-to-have behaviors, stylistic preferences |
| **Programmatic hooks** | Deterministic (100%) | Critical business rules, financial operations, compliance |

### Example: Refund Authorization

```
❌ System prompt: "Always verify customer identity before processing refunds"
   → Works 88% of the time. The other 12%? Incorrect refunds.

✅ Programmatic hook: Block process_refund unless get_customer returned verified ID
   → Works 100% of the time. Physically impossible to skip.
```

### Types of Hooks

| Hook Type | What It Does | Example |
|---|---|---|
| **PostToolUse** | Transforms tool results AFTER execution, BEFORE model sees them | Normalize dates from Unix → ISO 8601 |
| **Tool Call Interception** | Intercepts outgoing tool calls BEFORE execution | Block refunds > $500 → redirect to human |

```
Hook Execution Flow:

┌────────┐    ┌──────────────────┐    ┌────────┐    ┌────────────────┐    ┌───────┐
│ Claude │───►│ Interception Hook│───►│  Tool  │───►│ PostToolUse    │───►│Claude │
│ wants  │    │ (blocks/allows)  │    │executes│    │ Hook (normalize│    │ sees  │
│ tool   │    └──────────────────┘    └────────┘    │ result)        │    │result │
└────────┘                                          └────────────────┘    └───────┘
```

---

## 2.6 Multi-Step Workflows with Enforcement

### Prerequisite Gates

For critical workflows (identity verification → order lookup → refund processing):

```python
# Prerequisite enforcement
verified_customer_id = None

def handle_tool_call(tool_name, args):
    if tool_name == "get_customer":
        result = get_customer(args)
        verified_customer_id = result["customer_id"]
        return result
    
    elif tool_name in ["lookup_order", "process_refund"]:
        if verified_customer_id is None:
            # BLOCK: prerequisite not met
            return {
                "isError": True,
                "errorCategory": "prerequisite",
                "description": "Customer must be verified first. Call get_customer."
            }
        return execute_tool(tool_name, args)
```

### Structured Handoff Summaries

When escalating to a human agent who **doesn't have the conversation transcript**:

```json
{
  "customer_id": "CUST-12345",
  "customer_name": "Jane Smith",
  "root_cause": "Order #67890 arrived with damaged packaging; product non-functional",
  "investigation_summary": "Verified customer identity. Order confirmed delivered 2024-03-10. Photo evidence of damage reviewed. Item within 30-day return window.",
  "refund_amount": "$89.99",
  "recommended_action": "Full refund + replacement shipment",
  "escalation_reason": "Customer explicitly requested human agent"
}
```

---

## 2.7 Task Decomposition Strategies

### Two Approaches

| Strategy | When to Use | Example |
|---|---|---|
| **Prompt Chaining** (fixed sequential) | Predictable multi-aspect reviews | Code review: analyze each file → cross-file integration pass |
| **Dynamic Adaptive** | Open-ended investigation | "Add tests to legacy codebase": map structure → identify priorities → adapt plan |

### Prompt Chaining Example (Code Review)

```
Pass 1: File-by-file analysis (local issues)
  ├── auth.py → 3 findings
  ├── orders.py → 2 findings
  ├── payments.py → 1 finding
  └── utils.py → 0 findings

Pass 2: Cross-file integration analysis
  ├── Data flow: auth → orders → payments
  ├── Inconsistency: auth validates email format differently than orders
  └── Finding: Missing error propagation from payments to orders
```

### Dynamic Decomposition Example

```
Step 1: Map codebase structure
  → Discovered: 3 modules, 47 files, 12 test files

Step 2: Identify high-impact areas
  → payments module has 0% test coverage
  → auth module has critical untested paths

Step 3: Create prioritized plan
  → Priority 1: Payment processing tests
  → Priority 2: Auth edge cases

Step 4: Adapt as dependencies discovered
  → payments depends on a shared utility → test that first
  → [Plan adapts dynamically]
```

---

## 2.8 Session Management

### Session Resumption

```bash
# Start a named session
claude --session "bug-investigation"

# Resume later
claude --resume "bug-investigation"
```

### When to Resume vs. Start Fresh

| Scenario | Approach |
|---|---|
| Prior context is mostly valid, minor changes | `--resume <session-name>` |
| Major file restructuring, stale tool results | Start fresh with structured summary of key findings |
| Want to compare two approaches from same baseline | `fork_session` |

### Fork Session

```
                ┌──────────────┐
                │ Shared Base  │
                │ Analysis     │
                └──────┬───────┘
                       │
              ┌────────┴────────┐
              │                 │
        ┌─────▼──────┐   ┌─────▼──────┐
        │  Fork A:   │   │  Fork B:   │
        │  Strategy  │   │  Strategy  │
        │  "Redux"   │   │  "Context" │
        └────────────┘   └────────────┘
        
        Independent branches — changes in A don't affect B
```

---

## 2.9 Domain 1 — Key Exam Tips

> [!CAUTION]
> ### Must-Know Items for Domain 1
> 1. **`stop_reason` is everything** — it's the only reliable loop termination signal
> 2. **Subagents have isolated context** — they NEVER inherit parent history
> 3. **Task tool must be in `allowedTools`** — or coordinator can't spawn subagents
> 4. **Programmatic enforcement > prompts** for critical business rules
> 5. **PostToolUse hooks normalize data** — tool call interception hooks enforce policy
> 6. **Parallel subagents** = multiple Task calls in ONE response
> 7. **Dynamic decomposition** for open-ended tasks; **prompt chaining** for predictable reviews
> 8. **Narrow task decomposition** is a common coordinator failure (missing entire categories)
> 9. **Iterative refinement loops** let the coordinator re-delegate when gaps are found
> 10. **Structured handoff summaries** are required when humans lack transcript access

---
