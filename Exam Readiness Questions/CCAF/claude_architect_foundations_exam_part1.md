# Claude Certified Architect – Foundations: Exam Question Bank

## Part 1: Domain 1 — Agentic Architecture & Orchestration (27% of Exam)

> [!NOTE]
> **Format**: 4 options per question, single correct answer. Questions are scenario-based, mirroring the actual exam structure.
> **Passing Score**: 720/1000 | **Time**: 120 minutes | **Questions on Exam**: 60

---

### Task Statement 1.1: Design and Implement Agentic Loops

**Q1.** You are building an agentic loop for a customer support agent. After sending a request to Claude, the API returns a response with `stop_reason: "tool_use"`. What should your loop do next?

A) Terminate the loop and present the response to the user  
B) Execute the requested tool, append the result to the conversation, and send a new request to Claude  
C) Parse the assistant's text content for tool-calling instructions  
D) Increment a counter and check if the maximum iteration limit has been reached before continuing  

**Correct Answer: B**  
When `stop_reason` is `"tool_use"`, it means Claude has requested a tool to be executed. The correct behavior is to execute the tool, append the result to the conversation history, and send a new request so Claude can reason about the tool result. Option A terminates prematurely. Option C uses an anti-pattern (parsing natural language). Option D focuses on iteration caps as the primary mechanism, which is an anti-pattern.

---

**Q2.** Your agentic loop currently terminates when the model's response contains assistant text content. During testing, you notice the agent sometimes stops mid-task with an explanation of what it plans to do next instead of actually doing it. What is the root cause?

A) The model's context window is full, forcing early termination  
B) Checking for assistant text content as a completion indicator is an anti-pattern; the loop should check `stop_reason` instead  
C) The system prompt does not explicitly instruct the model to use tools  
D) The temperature setting is too high, causing unpredictable behavior  

**Correct Answer: B**  
Checking for assistant text content as a completion indicator is explicitly listed as an anti-pattern. The model may include text alongside tool_use blocks or provide reasoning text before continuing. The correct approach is to check `stop_reason` — the loop should continue when it's `"tool_use"` and terminate when it's `"end_turn"`.

---

**Q3.** An engineer on your team implemented an agentic loop that sets a maximum of 5 iterations before forcefully terminating. In production, you notice that complex customer requests often fail because the agent is cut off mid-investigation. What is the primary issue with this approach?

A) The iteration cap should be increased to 10 iterations  
B) Setting arbitrary iteration caps as the primary stopping mechanism is an anti-pattern; the loop should rely on `stop_reason: "end_turn"` to determine completion  
C) The agent needs more powerful tools to complete tasks in fewer iterations  
D) The system prompt should instruct the agent to complete tasks within 5 iterations  

**Correct Answer: B**  
Setting arbitrary iteration caps as the primary stopping mechanism is explicitly an anti-pattern. The model should naturally terminate when it has completed the task (indicated by `stop_reason: "end_turn"`). While safety guardrails (very high iteration caps) may be acceptable, using a low cap as the primary stopping mechanism prevents task completion.

---

**Q4.** In your agentic loop, after executing a tool, how should the tool result be handled before the next iteration?

A) Store the tool result in an external database for later retrieval  
B) Summarize the tool result and include only the summary in the next request  
C) Append the tool result to the conversation history so the model can reason about it in the next iteration  
D) Parse the tool result and include only relevant fields based on predetermined criteria  

**Correct Answer: C**  
Tool results must be appended to conversation context between iterations so the model can incorporate new information into its reasoning. The model needs the full context to decide its next action. Options A and D lose context. Option B risks losing important details through premature summarization.

---

**Q5.** Which of the following correctly describes model-driven decision-making in an agentic loop?

A) The developer pre-configures a decision tree that determines which tool to call based on input patterns  
B) Claude reasons about which tool to call next based on the current context, conversation history, and tool results  
C) A routing classifier selects tools before Claude processes the request  
D) Tool sequences are hard-coded in the system prompt for deterministic execution  

**Correct Answer: B**  
Model-driven decision-making means Claude reasons about which tool to call next based on context. This is distinct from pre-configured decision trees or tool sequences (A, D) or external routing classifiers (C). The model uses its understanding of the task and available tools to make decisions.

---

**Q6.** You are debugging an agentic loop and notice that the model sometimes returns a response with both text content and a `stop_reason` of `"tool_use"`. Your current implementation checks for text content first and terminates the loop. What should you change?

A) Strip the text content and only process the tool_use block  
B) Check `stop_reason` instead of text content; if it's `"tool_use"`, execute the tool regardless of whether text is present  
C) Only process responses that contain either text or tool_use, never both  
D) Log the text content as an error since tool_use responses should not contain text  

**Correct Answer: B**  
The authoritative signal for loop continuation is `stop_reason`, not the presence or absence of text content. Claude may include reasoning text alongside tool use blocks. The loop should always check `stop_reason: "tool_use"` to continue or `stop_reason: "end_turn"` to terminate.

---

**Q7.** You're implementing an agentic loop and want to add a natural-language parsing step that looks for phrases like "I've completed the task" to determine when to stop looping. Why is this approach problematic?

A) It adds latency to each loop iteration  
B) Parsing natural language signals to determine loop termination is an anti-pattern; the API provides a definitive `stop_reason` field for this purpose  
C) The model might never produce such phrases  
D) It requires a separate NLP model for reliable detection  

**Correct Answer: B**  
Parsing natural language signals to determine loop termination is explicitly an anti-pattern in the exam guide. The `stop_reason` field provides a definitive, machine-readable signal that is reliable and does not depend on the model's phrasing choices.

---

### Task Statement 1.2: Multi-Agent Orchestration

**Q8.** In a multi-agent research system, you implement a hub-and-spoke architecture. Which component manages all inter-subagent communication and error handling?

A) Each subagent manages its own communication with other subagents directly  
B) A message queue handles all inter-subagent communication asynchronously  
C) The coordinator agent manages all inter-subagent communication, error handling, and information routing  
D) A shared memory system allows subagents to communicate through a common data store  

**Correct Answer: C**  
In a hub-and-spoke architecture, the coordinator agent manages all inter-subagent communication, error handling, and information routing. Subagents do not communicate directly with each other. All routing flows through the coordinator for observability and consistency.

---

**Q9.** A coordinator agent decomposes the research topic "renewable energy solutions" into subtasks: "solar panel efficiency," "solar farm deployment," and "solar energy storage." The final report covers only solar energy. What is the root cause?

A) The search subagent's queries are too narrow  
B) The coordinator's task decomposition is overly narrow, limiting the scope to only solar energy and missing wind, hydro, geothermal, and other renewable sources  
C) The synthesis subagent filtered out non-solar content  
D) The document analysis subagent only had access to solar-related documents  

**Correct Answer: B**  
This mirrors the sample question from the exam guide. The root cause is the coordinator's narrow task decomposition. Subagents executed their assigned tasks correctly — the problem is what they were assigned. The coordinator should have decomposed "renewable energy" into broader subtasks covering all renewable sources.

---

**Q10.** Your multi-agent system's coordinator always routes every query through all four subagents (web search, document analysis, synthesis, report generation) in sequence, regardless of query complexity. A simple factual query takes 45 seconds. How should you improve this?

A) Add caching to each subagent to speed up repeated queries  
B) Design the coordinator to analyze query requirements and dynamically select which subagents to invoke rather than always routing through the full pipeline  
C) Increase the parallel processing capability of each subagent  
D) Reduce the number of subagents to two  

**Correct Answer: B**  
The coordinator should analyze query requirements and dynamically select which subagents to invoke based on query complexity. Simple factual queries may only need the web search agent, while complex research topics need the full pipeline. This is a key skill listed in the exam guide.

---

**Q11.** In your multi-agent system, subagents automatically inherit the coordinator's full conversation history. You notice subagents produce confused output because they try to respond to the coordinator's internal reasoning. What is the issue?

A) Subagents need larger context windows  
B) Subagents operate with isolated context — they should NOT inherit the coordinator's conversation history automatically; context must be explicitly provided  
C) The coordinator should filter its history before sharing  
D) Subagents need separate system prompts  

**Correct Answer: B**  
Subagents operate with isolated context. They do not inherit the coordinator's conversation history automatically. Context must be explicitly provided in the subagent's prompt. This is a fundamental principle of multi-agent systems with the Claude Agent SDK.

---

**Q12.** Your coordinator assigns research on "AI regulation" to three subagents: (1) "AI regulation in the EU," (2) "AI regulation in Europe," and (3) "AI regulation in GDPR countries." The final report has significant duplication. What should the coordinator do differently?

A) Add a deduplication step after synthesis  
B) Partition research scope across subagents to minimize duplication by assigning distinct subtopics or source types to each agent  
C) Use fewer subagents  
D) Have subagents share their results with each other to avoid duplication  

**Correct Answer: B**  
The coordinator should partition research scope to minimize duplication. In this case, the three subtasks overlap significantly (EU, Europe, GDPR countries are largely the same). Better decomposition would assign distinct subtopics (e.g., EU regulation, US regulation, China regulation) or distinct aspects (e.g., healthcare AI regulation, autonomous vehicles regulation, financial AI regulation).

---

**Q13.** Your multi-agent research system produces a report with gaps — certain subtopics are missing. You want to implement quality improvement. What pattern should you use?

A) Add more subagents to cover additional subtopics  
B) Implement iterative refinement loops where the coordinator evaluates synthesis output for gaps, re-delegates to search and analysis subagents with targeted queries, and re-invokes synthesis until coverage is sufficient  
C) Have the synthesis subagent automatically generate content for missing topics  
D) Increase the research time limit for each subagent  

**Correct Answer: B**  
The exam guide specifically describes iterative refinement loops where the coordinator evaluates output for gaps and re-delegates with targeted queries. This ensures comprehensive coverage without generating unsupported content (C) or simply adding more agents without addressing the coordination issue (A).

---

**Q14.** Why should all subagent communication be routed through the coordinator rather than allowing direct subagent-to-subagent communication?

A) Direct communication is not supported by the Claude API  
B) Routing through the coordinator provides observability, consistent error handling, and controlled information flow  
C) Direct communication would exceed the API rate limits  
D) Subagents cannot understand each other's output formats  

**Correct Answer: B**  
Routing all subagent communication through the coordinator provides observability (you can log and monitor all interactions), consistent error handling (the coordinator applies uniform error handling policies), and controlled information flow (the coordinator decides what context to share with each subagent).

---

### Task Statement 1.3: Subagent Invocation and Context Passing

**Q15.** What is the mechanism for spawning subagents in the Claude Agent SDK?

A) The `spawn()` function in the Agent SDK  
B) The Task tool, which must be included in the coordinator's `allowedTools`  
C) The `createSubAgent()` API method  
D) Direct API calls from within the coordinator's tool execution handler  

**Correct Answer: B**  
The Task tool is the mechanism for spawning subagents. The coordinator's `allowedTools` must include "Task" for it to be able to invoke subagents. This is a fundamental configuration requirement in the Agent SDK.

---

**Q16.** Your coordinator agent attempts to spawn a subagent, but the invocation fails silently. Upon investigation, you find the coordinator's configuration. What is the most likely cause?

A) The subagent's system prompt is too long  
B) The coordinator's `allowedTools` does not include "Task"  
C) The subagent is already running in another session  
D) The coordinator's context window is full  

**Correct Answer: B**  
For a coordinator to invoke subagents, its `allowedTools` must include "Task". Without this permission, the coordinator cannot use the Task tool to spawn subagents.

---

**Q17.** You are passing context from the web search subagent to the synthesis subagent. The synthesis subagent produces a report but lacks source attribution. What is the best approach to fix this?

A) Have the synthesis subagent search for sources independently  
B) Use structured data formats to separate content from metadata (source URLs, document names, page numbers) when passing context between agents to preserve attribution  
C) Include the raw HTML from web searches in the context  
D) Add a post-processing step to add citations  

**Correct Answer: B**  
The exam guide emphasizes using structured data formats that separate content from metadata (source URLs, document names, page numbers) when passing context between agents. This preserves attribution throughout the pipeline.

---

**Q18.** How should a coordinator spawn multiple subagents to execute in parallel?

A) Use threading or async/await patterns in the application code  
B) Emit multiple Task tool calls in a single coordinator response rather than across separate turns  
C) Configure the Agent SDK with a concurrency setting  
D) Send each subagent invocation in a separate API request  

**Correct Answer: B**  
Parallel subagent execution is achieved by having the coordinator emit multiple Task tool calls in a single response. This allows the runtime to execute them simultaneously rather than sequentially across separate turns.

---

**Q19.** When designing coordinator prompts for subagent delegation, what approach produces more adaptive subagent behavior?

A) Providing step-by-step procedural instructions detailing exactly how the subagent should complete its task  
B) Specifying research goals and quality criteria rather than step-by-step procedural instructions  
C) Giving the subagent access to all available tools and letting it decide everything  
D) Providing the subagent with the coordinator's full conversation history for maximum context  

**Correct Answer: B**  
The exam guide specifies that coordinator prompts should specify research goals and quality criteria rather than step-by-step procedural instructions. This enables subagent adaptability while still maintaining quality standards.

---

**Q20.** Your coordinator passes a summary of web search results to the synthesis subagent, but the synthesis produces inaccurate claims. What is likely the issue with the context passing?

A) The synthesis subagent needs a better system prompt  
B) Complete findings from prior agents should be included directly in the subagent's prompt, not just summaries  
C) The web search results are inaccurate  
D) The synthesis subagent's temperature is too high  

**Correct Answer: B**  
The exam guide states that complete findings from prior agents should be included directly in the subagent's prompt (e.g., passing web search results and document analysis outputs to the synthesis subagent). Summaries lose critical details needed for accurate synthesis.

---

**Q21.** What is `fork_session` used for in the Agent SDK?

A) Creating backup copies of sessions for disaster recovery  
B) Creating independent branches from a shared analysis baseline to explore divergent approaches  
C) Splitting a session across multiple API instances for load balancing  
D) Creating a child session that inherits and continues the parent's execution  

**Correct Answer: B**  
`fork_session` creates independent branches from a shared analysis baseline. This allows exploring divergent approaches (e.g., comparing two testing strategies or refactoring approaches) from a common starting point without the branches interfering with each other.

---

### Task Statement 1.4: Multi-Step Workflows with Enforcement and Handoff

**Q22.** Your customer support agent must verify customer identity via `get_customer` before processing any refund via `process_refund`. Currently, the system prompt states "Always verify the customer first." Logs show the agent skips verification in 12% of cases. What should you do?

A) Emphasize the instruction in the system prompt with bold formatting and repetition  
B) Implement a programmatic prerequisite that blocks `process_refund` calls until `get_customer` has returned a verified customer ID  
C) Add few-shot examples showing the correct order  
D) Lower the temperature to make the model more deterministic  

**Correct Answer: B**  
When deterministic compliance is required (e.g., identity verification before financial operations), prompt instructions alone have a non-zero failure rate. Programmatic enforcement through hooks or prerequisites provides guaranteed compliance. This is a core principle from the exam guide.

---

**Q23.** A customer contacts support with three issues: a damaged item, a missing item from another order, and a billing question. How should the agent handle this multi-concern request?

A) Ask the customer to submit separate support tickets for each issue  
B) Decompose the request into distinct items, investigate each in parallel using shared context, then synthesize a unified resolution  
C) Handle only the first issue and ask the customer to contact again for the others  
D) Prioritize the most urgent issue and address others only if time permits  

**Correct Answer: B**  
The exam guide specifies that multi-concern customer requests should be decomposed into distinct items, each investigated in parallel using shared context, before synthesizing a unified resolution.

---

**Q24.** Your agent needs to escalate a case to a human agent. The human agent does not have access to the conversation transcript. What should the agent provide?

A) A summary saying "customer is unhappy, please help"  
B) A structured handoff summary including customer ID, root cause, refund amount, and recommended action  
C) The full conversation transcript  
D) Only the customer's latest message  

**Correct Answer: B**  
The exam guide specifies compiling structured handoff summaries (customer ID, root cause, refund amount, recommended action) when escalating to human agents who lack access to the conversation transcript. This gives the human agent all the context they need.

---

**Q25.** What is the key difference between programmatic enforcement and prompt-based guidance for workflow ordering?

A) Programmatic enforcement is more expensive to implement  
B) Programmatic enforcement provides deterministic guarantees while prompt-based guidance has a non-zero failure rate  
C) Prompt-based guidance is always preferred for flexibility  
D) Programmatic enforcement only works with simple workflows  

**Correct Answer: B**  
The exam guide explicitly distinguishes between programmatic enforcement (hooks, prerequisite gates) which provides deterministic guarantees, and prompt-based guidance which has a non-zero failure rate. For critical business logic, programmatic enforcement is required.

---

### Task Statement 1.5: Agent SDK Hooks

**Q26.** Your agent receives data from multiple MCP tools — one returns Unix timestamps, another returns ISO 8601 dates, and a third returns numeric status codes. The model inconsistently interprets these formats. What is the best solution?

A) Include format documentation in the system prompt  
B) Implement a PostToolUse hook to normalize heterogeneous data formats before the model processes them  
C) Standardize all MCP tool output formats  
D) Add format parsing instructions to each tool description  

**Correct Answer: B**  
PostToolUse hooks intercept tool results for transformation before the model processes them. This is the ideal mechanism for normalizing heterogeneous data formats from different MCP tools. While standardizing tools (C) would also work, it may not be feasible when using third-party MCP tools.

---

**Q27.** Your business policy states that refunds exceeding $500 must be approved by a human supervisor. Currently, this rule is in the system prompt, but the agent occasionally processes high-value refunds automatically. What should you implement?

A) Add the rule in bold to the system prompt  
B) Implement a tool call interception hook that blocks refunds exceeding $500 and redirects to a human escalation workflow  
C) Add a confirmation step where the agent asks the customer to verify the amount  
D) Reduce the agent's refund limit to $100 for safety  

**Correct Answer: B**  
Tool call interception hooks enforce compliance rules deterministically. For business rules requiring guaranteed compliance (like refund thresholds), hooks are preferred over prompt-based enforcement because they cannot be bypassed by the model.

---

**Q28.** When should you choose hooks over prompt-based enforcement?

A) When the rules are complex and require judgment  
B) When business rules require guaranteed compliance and errors have financial or safety consequences  
C) When you want to reduce token usage  
D) When the model version might change  

**Correct Answer: B**  
Hooks should be chosen over prompt-based enforcement when business rules require guaranteed compliance. Prompt-based instructions are probabilistic — the model may not always follow them. For rules where violations have financial or safety consequences, deterministic enforcement via hooks is essential.

---

**Q29.** What does a PostToolUse hook do in the Agent SDK?

A) Validates tool input parameters before the tool executes  
B) Intercepts tool results for transformation before the model processes them  
C) Logs tool usage for monitoring  
D) Retries failed tool calls automatically  

**Correct Answer: B**  
PostToolUse hooks intercept tool results after the tool executes but before the model processes them. They are used for data transformation, normalization, and enrichment of tool outputs.

---

**Q30.** You implement a hook that intercepts outgoing `process_refund` tool calls. For refunds over $500, the hook blocks the call and returns a structured message directing to human escalation. What type of hook pattern is this?

A) PostToolUse hook for data normalization  
B) Tool call interception hook for compliance enforcement  
C) PreExecution validation hook  
D) Error handling hook  

**Correct Answer: B**  
This is a tool call interception hook that intercepts outgoing tool calls to enforce compliance rules. It blocks policy-violating actions (refunds exceeding a threshold) and redirects to alternative workflows (human escalation).

---

### Task Statement 1.6: Task Decomposition Strategies

**Q31.** You need to review a pull request that modifies 14 files across a stock tracking module. What task decomposition strategy is most appropriate?

A) Review all files simultaneously in a single pass  
B) Use prompt chaining — analyze each file individually, then run a separate cross-file integration pass  
C) Review files in random order  
D) Only review the files with the most changes  

**Correct Answer: B**  
The exam guide specifies prompt chaining patterns that break reviews into sequential steps: analyze each file individually for local issues, then run a cross-file integration pass to catch data flow issues and contradictions. This avoids attention dilution.

---

**Q32.** Your task is to "add comprehensive tests to a legacy codebase." You have no prior knowledge of the codebase structure. Which decomposition approach is most appropriate?

A) Use a fixed sequential pipeline: generate unit tests for all files, then integration tests, then end-to-end tests  
B) Use dynamic adaptive decomposition: first map the structure, identify high-impact areas, then create a prioritized plan that adapts as dependencies are discovered  
C) Generate tests for all files alphabetically  
D) Only test files that have been modified recently  

**Correct Answer: B**  
For open-ended investigation tasks, dynamic adaptive decomposition is appropriate. The exam guide describes decomposing open-ended tasks by first mapping structure, identifying high-impact areas, then creating a prioritized plan that adapts as dependencies are discovered.

---

**Q33.** When should you use prompt chaining (fixed sequential pipeline) versus dynamic adaptive decomposition?

A) Prompt chaining for all tasks because it's more predictable  
B) Prompt chaining for predictable multi-aspect reviews; dynamic decomposition for open-ended investigation tasks  
C) Dynamic decomposition for all tasks because it's more flexible  
D) The choice depends on the model version being used  

**Correct Answer: B**  
The exam guide specifies selecting task decomposition patterns appropriate to the workflow: prompt chaining for predictable multi-aspect reviews (like code reviews with known aspects to check), and dynamic decomposition for open-ended investigation tasks (like adding tests to unknown codebases).

---

**Q34.** Why is splitting a large code review into per-file passes plus a separate cross-file integration pass better than reviewing all files in a single pass?

A) It reduces API costs  
B) It avoids attention dilution — the model can give consistent depth to each file individually, and a separate pass catches cross-file issues  
C) It allows parallel processing  
D) It makes the review faster  

**Correct Answer: B**  
Splitting reviews avoids attention dilution. When processing many files at once, models give detailed feedback to some files but superficial comments to others, miss obvious bugs, and produce contradictory feedback. Per-file passes ensure consistent depth, while the integration pass catches cross-file data flow issues.

---

**Q35.** You are tasked with generating an investigation plan for a complex debugging scenario. Your initial plan has 15 steps, but after step 3, you discover the bug is in a completely different module than expected. What should happen?

A) Continue with the original plan for consistency  
B) The plan should adapt based on intermediate findings — this is the value of adaptive investigation plans that generate subtasks based on what is discovered at each step  
C) Restart the investigation from scratch  
D) Skip to the last step and check the final output  

**Correct Answer: B**  
The exam guide emphasizes the value of adaptive investigation plans that generate subtasks based on what is discovered at each step. When intermediate findings reveal unexpected information, the plan should adapt accordingly.

---

### Task Statement 1.7: Session State and Resumption

**Q36.** You spent an hour investigating a bug with Claude Code. You want to continue the investigation tomorrow. What is the recommended way to resume?

A) Start a new session and re-describe the problem  
B) Use `--resume <session-name>` to continue the specific prior conversation  
C) Copy the conversation history into a new prompt  
D) Use `fork_session` to create a branch  

**Correct Answer: B**  
Named session resumption using `--resume <session-name>` allows continuing a specific prior conversation across work sessions. This preserves the investigation context without needing to re-describe everything.

---

**Q37.** After resuming a session, you've made significant code changes since the last session. What should you do?

A) Nothing — the session will automatically detect file changes  
B) Inform the agent about changes to previously analyzed files for targeted re-analysis rather than requiring full re-exploration  
C) Start a new session instead  
D) Clear the session cache  

**Correct Answer: B**  
The exam guide emphasizes the importance of informing the agent about changes to previously analyzed files when resuming sessions after code modifications. This enables targeted re-analysis rather than requiring full re-exploration.

---

**Q38.** You want to compare two different testing strategies for a codebase without either approach affecting the other. Both strategies start from the same codebase analysis. What should you use?

A) Two separate sessions  
B) `fork_session` to create parallel exploration branches from the shared codebase analysis  
C) Two different system prompts in the same session  
D) A/B testing with different API keys  

**Correct Answer: B**  
`fork_session` creates independent branches from a shared analysis baseline to explore divergent approaches. This is ideal for comparing strategies (e.g., two testing strategies or refactoring approaches) from a common starting point.

---

**Q39.** Your session has accumulated extensive tool results from a 2-hour exploration, and many of those tool results are now stale because files have been modified. What is the most reliable approach?

A) Resume the session and instruct the agent to ignore stale results  
B) Start a new session with a structured summary of key findings — this is more reliable than resuming with stale tool results  
C) Delete the stale tool results from the conversation  
D) Increase the context window to accommodate old and new results  

**Correct Answer: B**  
The exam guide states that starting a new session with a structured summary is more reliable than resuming with stale tool results. When prior tool results are stale, fresh context with injected summaries ensures accuracy.

---

**Q40.** When should you choose session resumption over starting fresh with injected summaries?

A) Always use session resumption for continuity  
B) Use session resumption when prior context is mostly valid; start fresh when prior tool results are stale  
C) Always start fresh for reliability  
D) Use session resumption only for short sessions  

**Correct Answer: B**  
The exam guide specifies choosing between session resumption (when prior context is mostly valid) and starting fresh with injected summaries (when prior tool results are stale). This is a key judgment call architects need to make.

---

### Additional Agentic Architecture Questions

**Q41.** A coordinator agent receives a user query: "What's the capital of France?" It routes this through all four subagents: web search, document analysis, synthesis, and report generation. Each takes 10 seconds. What architectural improvement would you make?

A) Add caching at the coordinator level  
B) The coordinator should dynamically select subagents based on query complexity — a simple factual query should go directly to web search, not through the full pipeline  
C) Increase timeout limits for each subagent  
D) Pre-compute answers for common queries  

**Correct Answer: B**  
The coordinator should analyze query requirements and dynamically select which subagents to invoke. Simple queries don't need the full pipeline. This reduces latency and unnecessary processing.

---

**Q42.** Your multi-agent system has a coordinator and three subagents: Researcher, Analyzer, and Writer. The Analyzer subagent keeps trying to search the web even though that's the Researcher's role. What is the likely cause?

A) The Analyzer has too many tools in its `allowedTools`  
B) The Analyzer's system prompt is too vague  
C) Both A and B — the Analyzer likely has access to search tools outside its specialization, and its system prompt doesn't clearly define its role  
D) The coordinator is sending web-related queries to the Analyzer  

**Correct Answer: C**  
Agents with tools outside their specialization tend to misuse them. The Analyzer should only have analysis-related tools (not search tools) in its `allowedTools`, and its system prompt should clearly define its role. Both tool restriction and clear prompting are needed.

---

**Q43.** When should a coordinator implement an iterative refinement loop?

A) For every research query to maximize quality  
B) When the coordinator evaluates synthesis output and finds gaps in coverage that need additional research  
C) Only when the user explicitly requests more detail  
D) When the system has unused API capacity  

**Correct Answer: B**  
Iterative refinement loops are triggered when the coordinator evaluates synthesis output and identifies gaps. The coordinator re-delegates to search and analysis subagents with targeted queries and re-invokes synthesis until coverage is sufficient.

---

**Q44.** In a hub-and-spoke architecture, Subagent A discovers information critical to Subagent B's task. How should this information reach Subagent B?

A) Subagent A sends the information directly to Subagent B  
B) The coordinator receives Subagent A's results and includes the relevant information in Subagent B's prompt  
C) Both subagents access a shared database  
D) Subagent A writes to a message queue that Subagent B reads  

**Correct Answer: B**  
In a hub-and-spoke architecture, all communication flows through the coordinator. The coordinator receives Subagent A's results and explicitly passes relevant information to Subagent B in its prompt. Direct subagent-to-subagent communication is not used.

---

**Q45.** You're designing an `AgentDefinition` for a synthesis subagent. Which of the following should be included?

A) Access to all tools in the system for maximum flexibility  
B) A description, system prompt, and tool restrictions specific to the synthesis role  
C) The coordinator's conversation history as default context  
D) A timer that automatically terminates after 30 seconds  

**Correct Answer: B**  
The `AgentDefinition` configuration should include descriptions, system prompts, and tool restrictions for each subagent type. This follows the principle of least privilege — each subagent gets only what it needs for its specific role.

---

**Q46.** Your agentic loop processes a customer query. After calling `get_customer`, the model returns `stop_reason: "end_turn"` with a message saying "Customer verified. I'll now look up the order." But no tool call was made. What happened?

A) The model decided the task was complete  
B) The model produced text output instead of making a tool call; `stop_reason: "end_turn"` means it finished its turn without requesting a tool  
C) There was an API error  
D) The `lookup_order` tool is unavailable  

**Correct Answer: B**  
When `stop_reason` is `"end_turn"`, the model has finished its turn without requesting a tool. Even though the text says it will look up the order, the model returned text instead of a tool_use block. This could indicate a prompting issue — the model should be making a tool call, not just talking about making one.

---

**Q47.** You have a coordinator that needs to handle both quick customer queries (single tool call) and complex complaints (5-10 tool calls). How should you design the coordinator's delegation logic?

A) Always delegate to the full pipeline of subagents for consistency  
B) Analyze query requirements and dynamically select which subagents to invoke based on complexity  
C) Create separate coordinators for simple and complex queries  
D) Always delegate to a single subagent first and escalate if needed  

**Correct Answer: B**  
The coordinator should dynamically select subagents based on query complexity. This is explicitly stated in the exam guide as a key skill for orchestration.

---

**Q48.** When spawning parallel subagents, what is the correct way to emit multiple Task tool calls?

A) Send separate API requests for each subagent  
B) Emit multiple Task tool calls in a single coordinator response  
C) Use a parallel execution framework outside the Agent SDK  
D) Configure the coordinator's concurrency setting  

**Correct Answer: B**  
Parallel subagent execution is achieved by emitting multiple Task tool calls in a single coordinator response rather than across separate turns. This is the documented approach in the Agent SDK.

---

**Q49.** A coordinator agent's task decomposition strategy results in three subagents all searching for the same information from different angles. What improvement should you make?

A) Add a deduplication layer after the subagents complete  
B) Partition the research scope across subagents to minimize duplication by assigning distinct subtopics or source types  
C) Reduce the number of subagents  
D) Have each subagent check if another subagent already found the information  

**Correct Answer: B**  
The exam guide emphasizes partitioning research scope across subagents to minimize duplication. This is done by assigning distinct subtopics or source types to each agent, not by deduplication after the fact.

---

**Q50.** In a multi-agent system, the coordinator receives an error from a subagent. The error message says "search unavailable." What is the problem with this error message?

A) It should include an error code  
B) Generic error statuses hide valuable context from the coordinator, preventing it from making informed recovery decisions  
C) The error should be logged instead of returned  
D) The coordinator should retry automatically  

**Correct Answer: B**  
Generic error statuses like "search unavailable" hide valuable context. Errors should include structured context (failure type, attempted query, partial results, alternative approaches) to enable intelligent coordinator recovery decisions.

---

**Q51.** How should subagent context be provided when spawning a subagent?

A) Subagents automatically inherit the coordinator's context  
B) Context must be explicitly provided in the subagent's prompt — subagents do not inherit parent context  
C) Context is shared through a global state object  
D) The coordinator's system prompt is automatically forwarded  

**Correct Answer: B**  
The exam guide explicitly states that subagent context must be explicitly provided in the prompt — subagents do not automatically inherit parent context or share memory between invocations. This is a fundamental design principle.

---

**Q52.** You're implementing a customer support agent that must verify identity, look up orders, and process refunds in that specific order. The system prompt says "always verify first." Production logs show 15% of cases skip verification. What is the most critical improvement?

A) Add more emphasis in the system prompt  
B) Implement programmatic prerequisites — a hook that blocks `lookup_order` and `process_refund` until `get_customer` returns a verified customer ID  
C) Add few-shot examples of the correct sequence  
D) Use a lower temperature for more deterministic behavior  

**Correct Answer: B**  
This mirrors the exam's sample question. When a specific tool sequence is required for critical business logic, programmatic enforcement provides deterministic guarantees that prompt-based approaches cannot. The non-zero failure rate of prompt-based instructions is unacceptable for identity verification.

---

**Q53.** During escalation to a human agent, your AI agent includes the following in its handoff: "The customer seemed frustrated." What is wrong with this handoff?

A) Nothing — sentiment information is valuable  
B) The handoff should include structured information (customer ID, root cause, refund amount, recommended action) rather than vague sentiment assessments  
C) The sentiment analysis might be inaccurate  
D) Sentiment information should be in a separate field  

**Correct Answer: B**  
The exam guide specifies compiling structured handoff summaries including customer ID, root cause, refund amount, and recommended action. A vague sentiment assessment provides no actionable information for the human agent who lacks the conversation transcript.

---

**Q54.** Your agent receives a customer request: "My order #45678 arrived damaged, I also want to update my shipping address, and I was overcharged on my last bill." What is the recommended approach?

A) Handle each issue sequentially in separate conversation turns  
B) Decompose into distinct items, investigate each in parallel using shared context, then synthesize a unified resolution  
C) Ask the customer to prioritize which issue they want resolved first  
D) Create separate support tickets for each issue  

**Correct Answer: B**  
The exam guide describes decomposing multi-concern customer requests into distinct items, then investigating each in parallel using shared context before synthesizing a unified resolution.

---

**Q55.** An agent processes a $750 refund despite a $500 policy limit stated in the system prompt. What enforcement mechanism should be added?

A) A confirmation dialog  
B) A tool call interception hook that blocks refunds exceeding $500 and redirects to human escalation  
C) A warning message in the response  
D) Logging the violation for later review  

**Correct Answer: B**  
Tool call interception hooks that block policy-violating actions and redirect to alternative workflows provide guaranteed compliance. When violations have financial consequences, hooks are required rather than prompt-based enforcement.

---

**Q56.** When implementing a PostToolUse hook to normalize data, which of the following is an appropriate use case?

A) Changing the tool's behavior to return different data  
B) Converting Unix timestamps to ISO 8601 format, translating numeric status codes to human-readable strings  
C) Filtering out all data that doesn't match a predetermined schema  
D) Replacing tool results with cached data  

**Correct Answer: B**  
PostToolUse hooks normalize heterogeneous data formats. Converting timestamps and translating status codes are the exact examples given in the exam guide. The hook transforms data presentation, not data content.

---

**Q57.** Your agentic loop has a maximum iteration limit of 100 as a safety guardrail, but it primarily relies on `stop_reason: "end_turn"` for termination. Is this acceptable?

A) No — any iteration cap is an anti-pattern  
B) Yes — using a high safety cap while relying on `stop_reason` as the primary termination mechanism is acceptable; the anti-pattern is using low iteration caps as the primary stopping mechanism  
C) No — the cap should be removed entirely  
D) No — the cap should be lowered to 10 for efficiency  

**Correct Answer: B**  
The anti-pattern is "setting arbitrary iteration caps as the **primary** stopping mechanism." A high safety guardrail combined with `stop_reason`-based primary termination is acceptable. The key distinction is primary mechanism vs. safety fallback.

---

**Q58.** Your multi-agent research pipeline takes 5 minutes for simple queries because it always runs all four subagents sequentially. Which architectural change would most improve latency?

A) Use faster hardware  
B) Have the coordinator dynamically skip unnecessary subagents and emit parallel Task tool calls for subagents that can run simultaneously  
C) Reduce the context window for each subagent  
D) Cache all previous results  

**Correct Answer: B**  
Two improvements: dynamic subagent selection (skip unnecessary agents) and parallel execution (emit multiple Task tool calls in a single response). Combined, these address both unnecessary processing and sequential bottlenecks.

---

**Q59.** Which of the following is NOT a responsibility of the coordinator in a hub-and-spoke multi-agent system?

A) Task decomposition and delegation to subagents  
B) Error handling and recovery orchestration  
C) Executing tool calls directly against backend systems on behalf of subagents  
D) Result aggregation and quality evaluation  

**Correct Answer: C**  
The coordinator is responsible for task decomposition, delegation, result aggregation, error handling, and information routing. However, it does not execute tool calls on behalf of subagents — each subagent executes its own tools within its scope. The coordinator orchestrates, not executes.

---

**Q60.** You want to use `fork_session` to explore two refactoring approaches. How do the forked sessions relate to each other?

A) They share a common memory pool that updates in real-time  
B) They are independent branches from the shared analysis baseline — changes in one do not affect the other  
C) The first fork is the "main" branch and the second is experimental  
D) They merge automatically when both complete  

**Correct Answer: B**  
Forked sessions are independent branches from a shared analysis baseline. They explore divergent approaches without affecting each other. There is no automatic merging or shared state after the fork point.

---

**Q61.** Your coordinator's system prompt says "Decompose the research topic into 3 subtasks." For the topic "global climate change mitigation strategies," it produces: (1) solar energy, (2) wind energy, (3) hydroelectric power. What is the problem?

A) It should produce 5 subtasks instead of 3  
B) The hard-coded number (3) leads to overly narrow decomposition, missing categories like carbon capture, policy approaches, transportation electrification, etc.  
C) The subtasks are too broad  
D) The subtasks should be numbered differently  

**Correct Answer: B**  
The coordinator's fixed decomposition into exactly 3 subtasks is too narrow and misses major categories. The decomposition should be adaptive based on the topic's actual scope, not constrained to a predetermined number.

---

**Q62.** When a coordinator evaluates the synthesis output and finds that "transportation" is not covered in a report about "sustainable urban development," what should it do?

A) Add a generic paragraph about transportation  
B) Re-delegate to the search subagent with a targeted query about sustainable urban transportation, then re-invoke synthesis with the new findings  
C) Note the gap in the report and present it as-is  
D) Ask the user if they want transportation included  

**Correct Answer: B**  
This is the iterative refinement loop: the coordinator evaluates output for gaps, re-delegates to search and analysis subagents with targeted queries, and re-invokes synthesis until coverage is sufficient.

---

**Q63.** What is the significance of the `stop_reason` field in the Claude API response for agentic loops?

A) It indicates the quality of the response  
B) It indicates whether the model wants to call a tool (`"tool_use"`) or has completed its response (`"end_turn"`), serving as the primary control flow signal  
C) It indicates whether the response was truncated  
D) It indicates the confidence level of the response  

**Correct Answer: B**  
The `stop_reason` field is the definitive control flow signal for agentic loops. `"tool_use"` means the model wants to execute a tool, and `"end_turn"` means the model has completed its response. This is the primary mechanism for determining loop behavior.

---

**Q64.** In a multi-agent system, a subagent encounters a transient network error while fetching data. What is the recommended error handling approach?

A) Immediately propagate the error to the coordinator  
B) Implement local recovery within the subagent for transient failures; only propagate errors that cannot be resolved locally, including what was attempted and partial results  
C) Retry indefinitely until the error resolves  
D) Silently return empty results  

**Correct Answer: B**  
The exam guide specifies that subagents should implement local error recovery for transient failures. Only errors that cannot be resolved locally should propagate to the coordinator, and they should include what was attempted and any partial results.

---

**Q65.** An engineer suggests adding a "pre-flight check" tool that validates all inputs before any tool is called. What potential issue does this introduce?

A) It adds an extra tool to the agent's toolkit, increasing decision complexity  
B) It creates a bottleneck in the pipeline  
C) Both A and B, plus it may create a false sense of validation security  
D) It violates the Agent SDK's design principles  

**Correct Answer: A**  
Adding tools increases the agent's decision complexity. The exam guide notes that giving an agent access to too many tools (e.g., 18 instead of 4-5) degrades tool selection reliability. Pre-flight validation is better handled through hooks, which operate outside the model's tool selection process.

---

**Q66.** When passing context between agents in a multi-agent system, what format should be used to preserve attribution?

A) Plain text summaries  
B) Structured data formats that separate content from metadata (source URLs, document names, page numbers)  
C) JSON with a flat key-value structure  
D) Markdown-formatted reports  

**Correct Answer: B**  
The exam guide specifies using structured data formats to separate content from metadata (source URLs, document names, page numbers) when passing context between agents. This preserves attribution throughout the pipeline.

---

**Q67.** Your coordinator receives results from three subagents. Two produced useful results, but the third returned partial results due to a timeout. How should the coordinator proceed?

A) Discard the partial results and only use the complete results  
B) Terminate the entire workflow and report the timeout  
C) Proceed with the complete results and partial results, annotating the final output with coverage gaps where the timeout affected data availability  
D) Retry the failed subagent before proceeding  

**Correct Answer: C**  
The coordinator should proceed with available results (both complete and partial) and annotate the final output with coverage gaps. Terminating the entire workflow on a single failure is an anti-pattern, and discarding partial results wastes useful information.

---

**Q68.** Which of the following is an anti-pattern for determining agentic loop termination?

A) Checking `stop_reason: "end_turn"`  
B) Checking if the response contains assistant text content as a completion indicator  
C) Executing the tool when `stop_reason` is `"tool_use"`  
D) Appending tool results to conversation history  

**Correct Answer: B**  
Checking for assistant text content as a completion indicator is explicitly listed as an anti-pattern. The model may include text alongside tool_use blocks, so text presence alone is not a reliable termination signal.

---

**Q69.** You need to implement a workflow where the agent verifies identity, checks order status, evaluates return eligibility, and processes a return — in that exact order. Some steps depend on prior step results. What enforcement approach ensures reliability?

A) Detailed step-by-step instructions in the system prompt  
B) Programmatic prerequisites that gate each downstream tool call on the completion of prerequisite steps  
C) Few-shot examples showing the correct order  
D) A decision tree in the system prompt  

**Correct Answer: B**  
When a specific sequence of tool calls is required and later steps depend on earlier results, programmatic prerequisites provide deterministic enforcement. The exam guide explicitly recommends blocking downstream tool calls until prerequisite steps have completed.

---

**Q70.** The coordinator spawns a subagent for web search, but the subagent returns raw search results with 50 fields per result. The synthesis subagent struggles with this volume of data. What should change?

A) Give the synthesis subagent a larger context window  
B) Have the coordinator or the search subagent structure results with only relevant fields and metadata before passing to synthesis  
C) Split the search results across multiple synthesis subagents  
D) Summarize the search results using a separate LLM call  

**Correct Answer: B**  
The exam guide emphasizes trimming verbose outputs to only relevant fields. When passing results between agents, the data should be structured to include only relevant information, separating content from metadata for efficient downstream processing.

---

**Q71.** In a multi-agent system, why is it important for the coordinator to specify "research goals and quality criteria" rather than step-by-step procedures when delegating to subagents?

A) Step-by-step procedures are harder to write  
B) Goal-based delegation enables subagent adaptability — subagents can adjust their approach based on what they discover  
C) Step-by-step procedures use more tokens  
D) The Agent SDK doesn't support procedural prompts  

**Correct Answer: B**  
Specifying research goals and quality criteria enables subagent adaptability. Subagents can adjust their approach based on what they discover, rather than being locked into a fixed procedure that may not be optimal for the specific data they encounter.

---

**Q72.** Your agent handles customer support tickets. For routine issues (password reset, order tracking), it should resolve autonomously. For policy exceptions or customer demands for a human, it should escalate. Where should these escalation criteria be defined?

A) In a separate routing classifier  
B) In the system prompt with few-shot examples demonstrating when to escalate versus resolve  
C) In the tool descriptions  
D) In the coordinator's decision tree  

**Correct Answer: B**  
The exam guide specifies adding explicit escalation criteria to the system prompt with few-shot examples demonstrating when to escalate versus resolve autonomously. This is the proportionate first response for improving escalation calibration.

---

**Q73.** An agent self-reports confidence scores before each response and automatically escalates when confidence falls below 5/10. Testing shows it confidently handles hard cases and escalates easy ones. What is the problem?

A) The threshold should be 3/10 instead of 5/10  
B) LLM self-reported confidence scores are poorly calibrated — the agent may be incorrectly confident on hard cases and uncertain on straightforward ones  
C) The confidence scoring system needs training data  
D) The agent needs more tools to handle hard cases  

**Correct Answer: B**  
The exam guide explicitly states that self-reported confidence scores are unreliable proxies for actual case complexity. LLM confidence is poorly calibrated — the agent may be incorrectly confident on difficult cases while expressing uncertainty on straightforward ones.

---

**Q74.** You're using the Claude Agent SDK and want to implement a workflow where identity verification is guaranteed before any financial operation. Which approach provides deterministic compliance?

A) Including "IMPORTANT: Always verify identity first" in the system prompt  
B) Few-shot examples showing the correct sequence  
C) A programmatic hook that intercepts financial tool calls and blocks them until identity verification has completed  
D) Setting temperature to 0 for deterministic behavior  

**Correct Answer: C**  
Programmatic hooks provide deterministic compliance. Even with temperature 0, prompt-based instructions have a non-zero failure rate for critical business logic. Hooks physically block the tool call, making compliance guaranteed.

---

**Q75.** How does the coordinator decide which subagents to invoke for a given query?

A) It always invokes all subagents for completeness  
B) It analyzes query requirements and dynamically selects subagents based on the complexity and nature of the query  
C) It uses a pre-configured mapping of query types to subagents  
D) It invokes subagents randomly and retries if the result is poor  

**Correct Answer: B**  
The coordinator should analyze query requirements and dynamically select which subagents to invoke based on query complexity. This is a key skill — designing coordinators that make intelligent delegation decisions rather than always routing through the full pipeline.

---
