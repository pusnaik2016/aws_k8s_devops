# Claude Certified Architect – Foundations: Exam Question Bank

## Part 6: Practice Test Questions (Actual Exam Scenarios) — Q311–Q350

> [!IMPORTANT]
> These questions are sourced from **actual practice test scenarios**. They represent the real difficulty level and question style you will encounter on exam day. Each has been formatted as a proper 4-option MCQ.

---

## 📌 Section A: Agent Architecture & Multi-Agent Orchestration

---

**Q311.** Your agentic loop currently ends when Claude's text response contains a closing phrase such as "Let me know if there's anything else." Occasionally the loop exits before a pending refund tool call has executed. Which loop control mechanism should replace this?

A) Add more closing phrases to the detection list to catch edge cases  
B) Inspect the tool invocation state and `stop_reason` — only exit when there are no unresolved or pending tool execution frames and `stop_reason` is `"end_turn"`  
C) Set a fixed timer that waits 10 seconds after each response before checking for completion  
D) Parse the assistant's full response for any tool-related keywords before deciding to exit  

**Correct Answer: B**  
Relying on closing phrases ("Let me know if there's anything else") is brittle string matching — an explicit anti-pattern. The orchestration loop must inspect `stop_reason` and the tool invocation state. Only exit when `stop_reason` is `"end_turn"` and no tool calls are pending. This provides deterministic, state-based control rather than fragile text parsing.

---

**Q312.** `get_customer` returns Unix timestamps, `lookup_order` returns ISO 8601 strings, and `process_refund` returns numeric status codes. The agent miscalculates return windows when reasoning across these results. What is the most reliable fix?

A) Add format parsing instructions to the system prompt so the agent handles each format  
B) Implement a PostToolUse hook or middleware layer that normalizes all tool outputs to standardized formats (e.g., ISO 8601 for all dates) before the agent processes them  
C) Train the agent on diverse date formats using few-shot examples  
D) Replace all tools with a single unified tool that returns consistent formats  

**Correct Answer: B**  
Forcing an LLM to dynamically parse disparate data formats during multi-turn reasoning introduces fragility. The architectural fix is a PostToolUse hook or middleware layer that normalizes heterogeneous formats (Unix timestamps, ISO 8601, numeric codes) into standardized representations before the agent sees them. This is deterministic and doesn't rely on the model's parsing ability.

---

**Q313.** A customer's first message is "I want to speak to a human right now." The agent's lookup shows a straightforward, in-policy damaged-item replacement that it could complete itself. What should it do?

A) Resolve the straightforward issue first since it will be faster, then offer to connect to a human  
B) Acknowledge the request and ask if the customer would like the agent to try solving it first before escalating  
C) Honor the explicit human-escalation request immediately without attempting investigation  
D) Run a sentiment analysis to determine if the customer truly needs a human or is just frustrated  

**Correct Answer: C**  
Explicit human-escalation intent must immediately short-circuit the automated workflow. Even if an automated solution is completely viable and within policy, the customer's explicit demand for a human agent must be honored without delay. This preserves user trust and is a non-negotiable escalation trigger per the exam guide.

---

**Q314.** A customer sends one message covering a late delivery, a duplicate charge, and a promo code that did not apply. The agent responds only about the promo code. What is the best design change?

A) Increase the agent's context window to hold all three issues simultaneously  
B) Implement a compound intent extraction step that breaks the message into an explicit list of sub-issues, ensuring the agent systematically addresses each one before completing its turn  
C) Add instructions to the system prompt saying "always address all customer concerns"  
D) Have the agent ask the customer to submit each issue as a separate message  

**Correct Answer: B**  
When dealing with multi-intent messages, the orchestrator should first use a dedicated classification/decomposition step to break the message into an explicit list of sub-issues. The agent then systematically ticks off each item before completing the turn. Simply adding prompt instructions (C) is unreliable, and asking for separate messages (D) creates poor customer experience.

---

**Q315.** Each `lookup_order` call returns more than 40 fields, but a return request needs about five of them. Long sessions exhaust the context window. What should you change?

A) Increase the model's `max_tokens` to accommodate larger context  
B) Trim tool outputs to return only the specific fields necessary for the task — use projection filtering in the tool definition or a PostToolUse hook  
C) Summarize the full 40-field response into a single paragraph before adding to context  
D) Instruct the agent via system prompt to ignore irrelevant fields  

**Correct Answer: B**  
Context window hygiene requires projection filtering — modifying the tool definition or using a PostToolUse hook to return only the fields relevant to the task. Returning 40 fields when 5 are needed wastes tokens disproportionately. Summarization (C) loses precision on the relevant fields. System prompt instructions (D) don't actually reduce token consumption.

---

**Q316.** Your coordinator agent describes which subagents it intends to call but never actually spawns any of them, answering from its own knowledge instead. What is the most likely cause?

A) The subagents are configured incorrectly and fail silently on invocation  
B) The coordinator's `allowedTools` does not include the `Task` tool, or the system prompt fails to explicitly require tool calls for delegated tasks  
C) The coordinator's context window is too small to hold subagent definitions  
D) The subagent definitions have overly restrictive `allowed-tools` settings  

**Correct Answer: B**  
If the LLM defaults to generating text instead of executing tool calls, either the Task tool is missing from the coordinator's `allowedTools` array, or the system prompt doesn't explicitly require tool calls for external tasks. Without the Task tool in its allowed set, the coordinator literally cannot spawn subagents.

---

**Q317.** Your synthesis subagent produces vague reports that ignore what the search and document analysis subagents found, even though both completed successfully. Why?

A) The synthesis subagent needs a more detailed system prompt about report quality  
B) The outputs from search and analysis subagents were not explicitly passed into the synthesis subagent's prompt — subagents have isolated context and don't inherit prior results automatically  
C) The synthesis subagent's temperature is too high, causing it to generate creative content  
D) The search and analysis subagents returned data in an incompatible format  

**Correct Answer: B**  
Subagents operate with isolated context — they do NOT inherit the coordinator's conversation history or other subagents' outputs automatically. The search and analysis results must be explicitly included in the synthesis subagent's prompt. Without this, the synthesis agent is "blind" to prior findings and generates from its own knowledge.

---

**Q318.** Synthesis output regularly contains thin sections where evidence is missing, but the coordinator always runs search → analysis → synthesis → reporting exactly once in a rigid linear pipeline. What should you add?

A) More subagents to cover additional topics  
B) An iterative verification loop after synthesis that checks for coverage gaps and dynamically re-triggers search/analysis before generating the final report  
C) A larger context window for the synthesis subagent  
D) Quality scoring in the final reporting step to flag thin sections  

**Correct Answer: B**  
A rigid, linear pipeline prevents error correction. Adding an iterative refinement loop — where the coordinator evaluates synthesis output for gaps, re-delegates to search/analysis with targeted queries, and re-invokes synthesis until coverage is sufficient — is the recommended pattern from the exam guide.

---

**Q319.** Every subagent has been given all 18 tools "for flexibility." Tool selection accuracy has dropped, and the synthesis subagent has begun running its own web searches instead of synthesizing results. What should you do?

A) Add instructions to each subagent's prompt saying "only use tools relevant to your role"  
B) Restrict each subagent's `allowedTools` to only the precise tools required for its specific role — applying the Principle of Least Privilege  
C) Reduce the total number of tools in the system to 5  
D) Add a tool validation layer that blocks unauthorized tool calls after execution  

**Correct Answer: B**  
Massive tool catalogs increase decision complexity and cause tool confusion. The exam guide explicitly states that giving an agent 18 tools instead of 4-5 degrades tool selection reliability. Each subagent should only have tools relevant to its role. Prompt-based restrictions (A) are unreliable compared to programmatic `allowedTools` restrictions.

---

**Q320.** Synthesis needs quick fact checks (dates, names, figures) in about 85% of cases, but every check currently round-trips through the coordinator to the web search agent. This adds 40% latency. The remaining 15% need deeper investigation. What is the best design?

A) Give the synthesis agent full access to all web search tools to eliminate round trips  
B) Provide the synthesis agent a scoped `verify_fact` tool for simple lookups (85% case), while complex verifications continue routing through the coordinator to the dedicated search agent (15% case)  
C) Have the synthesis agent batch all fact-check needs and send them to the coordinator at the end  
D) Cache all potential facts before synthesis begins so no verification is needed  

**Correct Answer: B**  
Asymmetric routing optimizes for the common case. A lightweight, scoped `verify_fact` tool handles the 85% of simple checks directly within the synthesis agent, while complex investigations (15%) still route through the coordinator. This applies the principle of least privilege — giving just enough cross-role capability for the high-frequency need without over-provisioning.

---

## 📌 Section B: Claude Code Steering (CLAUDE.md & SKILL.md)

---

**Q321.** Your root `CLAUDE.md` has grown to cover standards for eight packages, and Claude increasingly applies the wrong package's conventions. Each package has a maintainer who knows its rules well. What is the best restructuring?

A) Split the root `CLAUDE.md` into eight sections with clear headers for each package  
B) Use `@import` in each package's local CLAUDE.md to selectively include only that package's relevant standards, or create `.claude/rules/` files with path-scoped YAML frontmatter  
C) Create a single `.claude/rules/conventions.md` file with all eight packages' rules  
D) Move all conventions into the system prompt where they can be conditionally loaded  

**Correct Answer: B**  
Directory-scoped configuration partitioning prevents rule cross-contamination. Instead of a monolithic root file, use localized `.claude/rules/` files with YAML frontmatter path scoping (e.g., `paths: ["packages/auth/**/*"]`) or `@import` in per-package CLAUDE.md files. This ensures conventions are injected into context only when working in that specific scope.

---

**Q322.** Test files sit beside the code they test throughout the repository (`Button.test.tsx` next to `Button.tsx`), and every test must follow one shared set of conventions. What approach applies them most reliably?

A) Place a CLAUDE.md with test conventions in every directory that contains test files  
B) Create a `.claude/rules/testing.md` file with YAML frontmatter `paths: ["**/*.test.tsx", "**/*.spec.tsx"]` to match test files by glob pattern regardless of directory  
C) Add test conventions to the root CLAUDE.md and rely on Claude to infer when they apply  
D) Create a testing skill in `.claude/skills/` that developers invoke manually before writing tests  

**Correct Answer: B**  
Because test files are distributed ubiquitously across directories, directory-level CLAUDE.md files are impractical. Glob-pattern-based rules in `.claude/rules/` with `paths: ["**/*.test.tsx"]` bind uniformly to the file extension regardless of location. This is automatic (unlike skills that need invocation) and precise (unlike root CLAUDE.md that loads for all files).

---

**Q323.** You describe a data transformation in prose across three attempts, and Claude produces a different interpretation of the rules each time. What is most likely to resolve the ambiguity?

A) Write more detailed prose with additional clarifying sentences  
B) Provide 2-3 concrete input/output examples showing the exact expected transformation  
C) Lower the temperature to make responses more deterministic  
D) Add a validation step that rejects incorrect transformations  

**Correct Answer: B**  
Prose instructions are inherently prone to semantic drift and interpretation variance. Concrete input/output examples establish absolute structural expectations. The exam guide explicitly states that few-shot examples are the most effective way to communicate expected transformations when prose descriptions are interpreted inconsistently.

---

**Q324.** Claude's generated module has three defects: the retry backoff interacts with the timeout setting, which in turn changes when the circuit breaker opens. How should you report them?

A) Report each bug in a separate message for isolated fixes  
B) Report all three interacting defects together in a single detailed message, since their fixes affect each other  
C) Prioritize the most critical bug and fix it first, then address the others  
D) Write unit tests for each bug separately and share the failures one at a time  

**Correct Answer: B**  
The exam guide distinguishes between interacting and independent problems. When fixes interact (retry ↔ timeout ↔ circuit breaker), they should be reported together in a single message. Separate sequential reporting (A) risks each fix breaking the others. Independent bugs should be fixed sequentially; interacting bugs should be addressed atomically.

---

## 📌 Section C: Tool Execution & MCP Environments

---

**Q325.** A production stack trace points to a single missing null check in one function, and the fix is obvious from the trace itself. Which approach fits this task?

A) Enter plan mode to analyze the codebase structure and dependencies before making the fix  
B) Use direct execution to apply the targeted fix immediately — the location and solution are deterministic  
C) Create a skill that automates null-check fixes across the codebase  
D) Run a full codebase scan to identify all potential null-check issues before fixing this one  

**Correct Answer: B**  
Direct execution is appropriate for simple, well-scoped changes with clear scope. A single-file bug fix with a clear stack trace does not warrant plan mode, codebase scanning, or skill creation. These would be over-engineered responses to a deterministic, localized fix.

---

**Q326.** You want to list every test file in the repository using the convention `**/*.test.tsx`. Which built-in tool fits this task?

A) Grep — it searches file contents for patterns  
B) Bash — run a `find` command  
C) Glob — it matches file paths using naming and extension patterns  
D) Read — read directory contents sequentially  

**Correct Answer: C**  
Glob is purpose-built for file path pattern matching. `**/*.test.tsx` is a glob pattern matching files by name/extension. Grep searches file *contents*, not paths. While Bash `find` could work, Glob is the optimized built-in tool for this specific task, minimizing context overhead.

---

**Q327.** The whole team needs the same Jira MCP server, while you also want to trial a personal experimental server that teammates should not see. Where should each be configured?

A) Both in the project-level `.mcp.json` with access controls  
B) Shared Jira server in project-level `.mcp.json` (version-controlled); personal experimental server in user-level `~/.claude.json`  
C) Both in `~/.claude.json` with a "shared" flag for the Jira server  
D) Shared Jira server in CLAUDE.md; personal server in `.mcp.json`  

**Correct Answer: B**  
Configuration isolation hierarchy: shared team tooling goes in project-level `.mcp.json` (committed to version control, available to all), while personal/experimental servers go in user-level `~/.claude.json` (local only, invisible to teammates). This is the documented MCP scoping pattern.

---

**Q328.** Your `.mcp.json` needs a GitHub token, but that file is committed to the shared repository. What is the right approach?

A) Add the token directly to `.mcp.json` and add it to `.gitignore`  
B) Use environment variable expansion `${GITHUB_TOKEN}` in `.mcp.json` so the token is resolved at runtime from each developer's local environment  
C) Store the token in a separate `secrets.json` file referenced by `.mcp.json`  
D) Create a personal copy of `.mcp.json` in `~/.claude.json` with the token hardcoded  

**Correct Answer: B**  
Environment variable expansion (`${GITHUB_TOKEN}`) in `.mcp.json` is the documented approach. The base `.mcp.json` stays clean and committed to version control, while each developer sets the token in their local environment. Option A doesn't work because `.mcp.json` needs to be committed. Option C introduces an undocumented mechanism.

---

**Q329.** Agents burn many turns discovering which database schemas and issue queues exist before they can do any useful work. What best reduces this exploration overhead?

A) Pre-populate the system prompt with all schema information  
B) Expose content catalogs as MCP resources, giving agents visibility into available schemas and data structures without requiring exploratory tool calls  
C) Cache the agent's exploration results between sessions  
D) Add a `list_schemas` tool that the agent calls at the start of each session  

**Correct Answer: B**  
MCP resources expose content catalogs (database schemas, issue summaries, documentation hierarchies) that agents can browse without making exploratory tool calls. This is purpose-built for the discovery problem. A `list_schemas` tool (D) still requires a tool call each session, while resources are passively available.

---

**Q330.** Your codebase-analysis skill emits thousands of lines of intermediate output, which crowds out the main conversation context. Which `SKILL.md` frontmatter option addresses this?

A) `max-output: 500` to truncate the output  
B) `context: fork` to run the skill in an isolated sub-agent context, preventing output from polluting the main conversation  
C) `quiet: true` to suppress all output  
D) `redirect: file` to save output to a file  

**Correct Answer: B**  
`context: fork` in SKILL.md frontmatter runs the skill in an isolated sub-agent context. This prevents massive intermediate output from crowding the main dialogue stream. The skill completes, its results are available, but the verbose intermediate output doesn't consume main conversation context.

---

## 📌 Section D: CI/CD Pipelines & Production Workflows

---

**Q331.** Your CI job invoking Claude Code hangs until the runner times out, and the logs show it waiting for interactive input. What is the correct fix?

A) Set the environment variable `CLAUDE_HEADLESS=true` before running the command  
B) Use the `-p` (or `--print`) flag to run Claude Code in non-interactive mode  
C) Redirect stdin from `/dev/null`: `claude "prompt" < /dev/null`  
D) Add the `--batch` flag: `claude --batch "prompt"`  

**Correct Answer: B**  
The `-p` (or `--print`) flag is the documented way to run Claude Code in non-interactive mode. It processes the prompt, outputs to stdout, and exits without waiting for user input. The other options reference non-existent features (`CLAUDE_HEADLESS`, `--batch`) or use Unix workarounds that don't properly address Claude Code's command syntax.

---

**Q332.** You need review findings posted as inline pull request comments, but Claude returns unstructured prose that your parser mishandles. What should the CI command use?

A) Pipe the output through `jq` to parse it: `claude -p "review" | jq`  
B) Use `--output-format json` with `--json-schema` to produce machine-parseable, schema-compliant structured output  
C) Add "output as JSON" to the end of the prompt  
D) Use a regex-based parser to extract findings from the prose  

**Correct Answer: B**  
`--output-format json` combined with `--json-schema` enforces structured output in CI contexts. This guarantees the output conforms to your expected schema, eliminating parsing failures. Prompt-based JSON requests (C) are unreliable. Post-processing with jq (A) fails if the output isn't valid JSON to begin with.

---

**Q333.** Every new commit triggers a fresh review, and the bot re-posts findings the author has already fixed or explicitly dismissed. What is the best fix?

A) Only review files changed in the latest commit  
B) Include prior review findings in context when re-running reviews, instructing Claude to report only new or still-unaddressed issues  
C) Delete all previous comments before posting new ones  
D) Run reviews only on the final commit before merge  

**Correct Answer: B**  
Including prior review findings in context and instructing Claude to report only new or still-unaddressed issues prevents duplicate alerts. This maintains review continuity without creating alert fatigue from re-flagging resolved issues.

---

**Q334.** Your review prompt says "check that comments are accurate," and the bot flags every comment that is merely terse or stylistically brief. How do you improve precision?

A) Add "be more conservative" to the prompt  
B) Replace the vague instruction with explicit criteria: "Flag comments only when the described behavior directly contradicts actual code logic. Skip stylistic brevity, naming preferences, and documentation length."  
C) Lower the temperature for less creative output  
D) Add a confidence threshold that filters low-confidence findings  

**Correct Answer: B**  
"Accurate" is semantically vague to an LLM — it conflates factual correctness with stylistic completeness. Explicit criteria defining exactly what constitutes a violation (behavioral contradiction vs. stylistic choice) eliminates false positives. The exam guide emphasizes that vague instructions like "be conservative" (A) don't improve precision.

---

**Q335.** Severity labels vary from run to run: the same unhandled promise rejection is "critical" in one pull request and "minor" in another. What produces consistent classification?

A) Add "be consistent with severity ratings" to the prompt  
B) Define explicit severity criteria with concrete code examples for each level — a rubric mapping specific conditions to severity classifications  
C) Use a separate classification model for severity  
D) Remove severity labels and flag all issues equally  

**Correct Answer: B**  
Without predefined rubric anchoring, LLM labeling drifts across runs. Providing an explicit rubric with concrete code examples for each severity level (e.g., "Critical: unhandled exceptions that crash the process; Minor: stylistic preferences") ensures deterministic classification. Vague consistency instructions (A) don't solve the calibration problem.

---

**Q336.** About 6% of extractions fail to parse because the model returns JSON with trailing commas or surrounding prose. What eliminates these failures?

A) Add "output valid JSON only, no surrounding text" to the prompt  
B) Use `tool_use` with JSON schemas — this provides structured output guarantees that eliminate JSON syntax errors entirely  
C) Post-process the output with a JSON repair library  
D) Increase the temperature to encourage more precise formatting  

**Correct Answer: B**  
Tool use with JSON schemas provides native structured output guarantees. The model's output is forced into schema-compliant JSON, eliminating trailing commas, surrounding prose, and other syntax anomalies. Prompt-based instructions (A) reduce but don't eliminate syntax errors. Post-processing (C) is a workaround, not a fix.

---

**Q337.** Your schema marks `purchase_order_number` as required. For documents that do not have one, the model invents plausible-looking values like "PO-2024-00001." What is the correct fix?

A) Add validation to detect fabricated PO numbers  
B) Make the field optional (nullable) — allowing `null` when the information doesn't exist in the source document prevents the model from hallucinating values  
C) Add "do not fabricate values" to the system prompt  
D) Remove the field from the schema entirely  

**Correct Answer: B**  
Forcing a field to be required when it may physically not exist in the source forces hallucination. The schema must allow `null` or make the field optional. This is a core schema design principle from the exam guide: design fields as optional/nullable when source documents may not contain the information.

---

**Q338.** Your pipeline must always run `extract_metadata` before any enrichment tool, but the model sometimes enriches first. What guarantees the ordering on the first turn?

A) Add "always run extract_metadata first" to the system prompt  
B) Use `tool_choice: {"type": "tool", "name": "extract_metadata"}` on the first API call to force the specific tool, then switch to `"auto"` for subsequent turns  
C) Create a pre-processing hook that calls `extract_metadata` automatically  
D) Remove enrichment tools from the first turn's available tools  

**Correct Answer: B**  
Forced tool selection (`tool_choice: {"type": "tool", "name": "extract_metadata"}`) deterministically ensures the metadata extraction runs first. Prompt instructions (A) have a non-zero failure rate. After the forced first call, subsequent turns can use `"auto"` for flexible tool selection.

---

**Q339.** Pydantic validation rejects roughly 8% of extractions for structural problems such as a date landing in the wrong field. What is the most effective recovery?

A) Retry the extraction with the same prompt  
B) Implement a retry-with-error-feedback loop: catch the validation error, include the original document, failed extraction, AND the specific Pydantic error in a follow-up prompt for model self-correction  
C) Manually correct the 8% of failures  
D) Relax the Pydantic schema to accept dates in any field  

**Correct Answer: B**  
Programmatic self-correction loops catch validation errors and feed them back into a correction prompt. Including the original document, the failed extraction, AND the specific validation error (e.g., "date '2024-03-15' was placed in 'customer_name' field instead of 'order_date'") gives the model precise guidance for correction. Generic retries (A) without error context are far less effective.

---

**Q340.** Of 100 documents submitted to the Message Batches API, six fail because they exceed the context limit. What is the appropriate response?

A) Resubmit the entire batch of 100 documents  
B) Identify the 6 failed documents by `custom_id`, chunk them into smaller segments, and resubmit only those 6  
C) Increase the API context limit  
D) Skip the 6 failed documents and report 94% success  

**Correct Answer: B**  
Failed documents are identified by their `custom_id`. The appropriate response is to resubmit only the failed documents with modifications — in this case, chunking oversized documents that exceeded context limits. Reprocessing the entire batch wastes resources. Skipping failures loses data.

---

## 📌 Section E: Hard Guardrails & Advanced Architecture

---

**Q341.** Company policy caps agent-issued refunds at $500, and anything larger requires a human. The system prompt states this clearly, yet audits still find occasional $700 refunds. Which change guarantees compliance?

A) Emphasize the $500 limit in the system prompt with bold text and repetition  
B) Implement programmatic validation in the `process_refund` tool's backend that throws a hard error if `amount > 500`, independent of the LLM's decision-making  
C) Add few-shot examples showing the agent declining refunds over $500  
D) Lower the temperature to 0 for deterministic compliance  

**Correct Answer: B**  
Prompts are soft constraints subject to model drift. To *guarantee* compliance, the constraint must be enforced programmatically — either via a tool call interception hook or backend validation that physically blocks execution when `amount > 500`. This is deterministic and cannot be bypassed by the model.

---

**Q342.** Human agents receiving escalations do not have access to the conversation transcript, and they report spending several minutes re-collecting information from the customer. What should the `escalate_to_human` payload contain?

A) The full raw conversation transcript  
B) A structured handoff summary containing: customer ID, issue summary, root cause analysis, steps already attempted, refund amount (if applicable), and the specific reason for escalation  
C) Just the customer's original message  
D) A sentiment score and the last 3 messages  

**Correct Answer: B**  
The exam guide specifies compiling structured handoff summaries (customer ID, root cause, refund amount, recommended action) for human agents who lack access to the transcript. Raw transcripts (A) cause cognitive overhead; minimal context (C, D) forces the human agent to re-collect information from the customer.

---

**Q343.** All four of your MCP tools return "Operation failed" on any error. The agent retries policy rejections endlessly and gives up immediately on service timeouts. What should the tools return instead?

A) HTTP-style status codes (400, 500, 503)  
B) Structured error payloads with `errorCategory` (transient/validation/business/permission), `isRetryable` boolean, and human-readable descriptions  
C) A simple `success: false` flag with an error code number  
D) Detailed stack traces for debugging  

**Correct Answer: B**  
Semantic error classification is essential. Generic "Operation failed" masks the root cause and prevents intelligent recovery. Structured payloads distinguishing transient errors (retry) from business violations (stop and pivot) let the agent make appropriate decisions. Without `isRetryable`, the agent can't distinguish between "try again" and "this will never work."

---

**Q344.** You are adding a caching layer in a domain you don't know well, and you are unsure what edge cases you might be overlooking. Which technique best surfaces considerations before implementation?

A) Start coding and fix issues as they emerge  
B) Use the interview pattern — have Claude ask probing questions about cache invalidation strategies, race conditions, TTL policies, and failure modes before implementing  
C) Read documentation about caching best practices first  
D) Implement the simplest cache and optimize later  

**Correct Answer: B**  
The interview pattern has Claude ask questions to surface considerations the developer may not have anticipated — especially valuable in unfamiliar domains. For caching, this surfaces edge cases like invalidation storms, race conditions, cold-start behavior, and TTL strategies before any code is committed.

---

**Q345.** You analyzed a service yesterday, then merged a large refactor that renamed and moved many files Claude examined. You want to continue the work today. What is most reliable?

A) Resume the session with `--resume` and continue as if nothing changed  
B) Start a new session with a structured summary of yesterday's key findings — this is more reliable than resuming with stale file references  
C) Resume and instruct Claude to "update your understanding of the codebase"  
D) Fork the session and work in the forked branch  

**Correct Answer: B**  
After a sweeping structural refactor, prior tool results contain stale file paths. The exam guide states that starting a new session with a structured summary is more reliable than resuming with stale tool results. The summary preserves architectural understanding while avoiding references to files that no longer exist at their old paths.

---

**Q346.** Edit fails on a configuration file because the anchor text you supplied appears in four different places. What is the reliable way to make the change?

A) Use a regex-based search-and-replace  
B) Use Read to load the full file contents, then use Write to replace the entire file with the modification applied — the documented fallback when Edit cannot find unique anchor text  
C) Add more context to the anchor text and retry Edit  
D) Use Bash with `sed` to perform the replacement  

**Correct Answer: B**  
When Edit fails due to non-unique text matches, using Read + Write as a fallback is the documented approach. Read loads the full file, and Write replaces it with the modified version. While adding more context to the anchor (C) might work, Read + Write is the guaranteed reliable fallback per the exam guide.

---

**Q347.** You need standard Jira integration plus a tool for your team's bespoke deployment approval flow. How should you allocate build effort?

A) Build both from scratch as custom MCP servers  
B) Use an existing community MCP server for standard Jira integration; build a custom MCP server only for the proprietary deployment approval workflow  
C) Build one unified MCP server that handles both Jira and deployment approvals  
D) Use the Jira REST API directly without an MCP server  

**Correct Answer: B**  
The exam guide recommends choosing existing community MCP servers for standard integrations (like Jira), reserving custom server development for team-specific workflows. Building Jira integration from scratch wastes effort on a solved problem. The bespoke deployment approval flow justifies custom development.

---

**Q348.** Your `document_type` enum covers six known types, but new types appear monthly and the model forces them into the closest existing value (e.g., classifying a "warranty claim" as "invoice"). What schema change helps?

A) Add every possible document type to the enum proactively  
B) Add an `"other"` enum value with a companion `document_type_detail` string field for open-ended categorization of unseen types  
C) Remove the enum and use a free-text field  
D) Add a confidence score field for the classification  

**Correct Answer: B**  
Rigid enums force models to make arbitrary classifications for unseen types. The `"other"` + detail string pattern allows extensible categorization: unknown types are classified as "other" with a descriptive detail field (e.g., `"other"`, `"warranty_claim"`). This prevents data corruption without requiring monthly schema updates.

---

**Q349.** A model generates code and then reviews its own output in the same session. The review finds zero issues. A separate team member manually finds three bugs. What explains the discrepancy?

A) The model's review prompt was too lenient  
B) Self-review is inherently limited — the model retains its reasoning context from generation, making it less likely to question its own decisions. An independent review instance without prior reasoning context is more effective  
C) The model's context window was exhausted  
D) The bugs were in areas the model didn't write  

**Correct Answer: B**  
This is the self-review limitation. The model retains reasoning context from generation, creating a blind spot for its own decisions. An independent Claude instance — without the generator's reasoning context — is significantly more effective at catching subtle issues.

---

**Q350.** Your multi-agent pipeline processes overnight. Agent 3 crashes after completing 80% of its work. On restart, the entire pipeline re-runs from Agent 1. How should you design crash recovery?

A) Add checkpoints after each agent completes  
B) Each agent exports its state to a structured manifest. The coordinator loads the manifest on resume and injects state into agent prompts, continuing from where the pipeline left off  
C) Run each agent in a separate container for isolation  
D) Log all API calls for replay on failure  

**Correct Answer: B**  
Structured state persistence using manifests enables crash recovery. Each agent exports its state to a known location, and the coordinator loads the manifest on resume. This avoids re-running completed work and allows the pipeline to continue from the point of failure.

---
