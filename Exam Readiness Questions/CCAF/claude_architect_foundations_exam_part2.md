# Claude Certified Architect – Foundations: Exam Question Bank

## Part 2: Domain 2 — Tool Design & MCP Integration (18% of Exam)

---

### Task Statement 2.1: Tool Interface Design

**Q76.** Your agent has two tools: `analyze_content` (description: "Analyzes content") and `analyze_document` (description: "Analyzes a document"). In production, the agent frequently selects the wrong tool. What is the root cause?

A) The tools should have different return types  
B) The tool descriptions are too similar and don't clearly differentiate purpose, inputs, outputs, or when to use each  
C) The agent needs more training data  
D) The system prompt should specify which tool to use  

**Correct Answer: B**  
Ambiguous or overlapping tool descriptions cause misrouting. Tool descriptions are the primary mechanism LLMs use for tool selection. When descriptions are nearly identical, the model cannot reliably distinguish between them.

---

**Q77.** You have a tool called `analyze_content` that is being incorrectly invoked for document-related queries. What is the most effective fix?

A) Add logic to reject document-related queries in the tool's implementation  
B) Rename it to `extract_web_results` with a web-specific description that clearly differentiates it from the document analysis tool  
C) Remove the tool entirely  
D) Add a pre-processing step to classify queries  

**Correct Answer: B**  
The exam guide specifically recommends renaming tools and updating descriptions to eliminate functional overlap. Renaming `analyze_content` to `extract_web_results` with a web-specific description makes the purpose unambiguous.

---

**Q78.** What should a well-written tool description include?

A) Just the tool name and return type  
B) Input formats, example queries, edge cases, and boundary explanations for when to use it versus similar alternatives  
C) The tool's implementation details  
D) Performance benchmarks  

**Correct Answer: B**  
The exam guide states that tool descriptions should include input formats, example queries, edge cases, and boundary explanations. These details help the model make reliable tool selection decisions.

---

**Q79.** You have a generic `analyze_document` tool that handles data extraction, summarization, and claim verification. Users report inconsistent results. What tool design improvement would you make?

A) Add more parameters to the single tool  
B) Split it into purpose-specific tools: `extract_data_points`, `summarize_content`, and `verify_claim_against_source` with defined input/output contracts  
C) Add a mode parameter (extract/summarize/verify)  
D) Create a wrapper tool that routes to the correct function  

**Correct Answer: B**  
The exam guide recommends splitting generic tools into purpose-specific tools with defined input/output contracts. This eliminates ambiguity in tool selection and improves reliability.

---

**Q80.** Your system prompt says "When the user mentions 'search', always use the web_search tool." However, when a user says "search the document for errors," the agent uses `web_search` instead of `analyze_document`. What caused this?

A) The web_search tool is broken  
B) Keyword-sensitive instructions in the system prompt created unintended tool associations, overriding the tool descriptions  
C) The document analysis tool is not available  
D) The user should have said "analyze" instead of "search"  

**Correct Answer: B**  
The exam guide warns about the impact of system prompt wording on tool selection. Keyword-sensitive instructions (like "when the user mentions 'search'") can create unintended tool associations that override well-written tool descriptions.

---

**Q81.** What is the primary mechanism LLMs use for tool selection?

A) The tool name  
B) Tool descriptions  
C) The system prompt  
D) Historical tool usage patterns  

**Correct Answer: B**  
Tool descriptions are the primary mechanism LLMs use for tool selection. Minimal descriptions lead to unreliable selection among similar tools. This is why writing detailed, differentiated descriptions is critical.

---

**Q82.** You notice that adding more tools to an agent (from 5 to 18) significantly degrades tool selection reliability. Why?

A) The API has a tool limit  
B) Too many tools increase decision complexity for the model, degrading selection reliability  
C) The tools conflict with each other  
D) The context window can't hold all tool definitions  

**Correct Answer: B**  
The exam guide states that giving an agent access to too many tools (e.g., 18 instead of 4-5) degrades tool selection reliability by increasing decision complexity. Each subagent should have only the tools relevant to its role.

---

**Q83.** Your system prompt includes "Review the tool descriptions carefully before selecting a tool." Does this improve tool selection?

A) Yes, it makes the model more deliberate  
B) No — if the tool descriptions themselves are ambiguous, no amount of instructions will fix the selection problem  
C) Yes, but only at higher temperatures  
D) It depends on the model version  

**Correct Answer: B**  
The root cause of tool misselection is typically inadequate descriptions, not insufficient attention. Reviewing system prompts for keyword-sensitive instructions matters, but the primary fix is improving tool descriptions to clearly differentiate purpose, inputs, and outputs.

---

### Task Statement 2.2: Structured Error Responses

**Q84.** An MCP tool encounters a timeout error. It returns the message "Operation failed." The agent retries the same call three more times, all timing out. What error response improvement would prevent unnecessary retries?

A) Include a generic error code  
B) Return structured error metadata including `errorCategory: "transient"`, `isRetryable: true`, and a human-readable description — plus consider if a retry would succeed or if an alternative approach is needed  
C) Return a stack trace  
D) Log the error and return success with empty results  

**Correct Answer: B**  
The exam guide emphasizes returning structured error metadata including errorCategory, isRetryable boolean, and human-readable descriptions. This allows the agent to make appropriate recovery decisions. For transient errors, the retryable flag with context helps the agent decide whether to retry or try alternatives.

---

**Q85.** What is the MCP `isError` flag used for?

A) Indicating that the MCP server is down  
B) Communicating tool failures back to the agent so it can make appropriate recovery decisions  
C) Marking deprecated tools  
D) Flagging security violations  

**Correct Answer: B**  
The MCP `isError` flag pattern communicates tool failures back to the agent. When set, the agent knows the tool call did not succeed and can make recovery decisions based on the accompanying error information.

---

**Q86.** Your tool returns `{"status": "error", "message": "Operation failed"}` for all error types. Why is this problematic?

A) It's fine for most use cases  
B) Uniform error responses prevent the agent from making appropriate recovery decisions — it can't distinguish between retryable transient errors, permanent validation errors, and policy violations  
C) The error message is too short  
D) It should use an error code instead of a message  

**Correct Answer: B**  
Uniform error responses prevent the agent from distinguishing between different error types. The agent needs to know if an error is transient (retry), validation-related (fix input), or a business rule violation (escalate). Without this distinction, recovery is impossible.

---

**Q87.** A customer's refund request is denied because they're outside the return window. How should the MCP tool communicate this to the agent?

A) Return a generic "refund failed" error  
B) Return `isRetryable: false` with a customer-friendly explanation of the policy violation so the agent can communicate appropriately to the customer  
C) Return an HTTP 403 status code  
D) Silently return no results  

**Correct Answer: B**  
For business rule violations, the tool should return `retriable: false` flags and customer-friendly explanations. This lets the agent know not to retry and provides appropriate language for communicating the denial to the customer.

---

**Q88.** What is the difference between an access failure and a valid empty result?

A) There is no meaningful difference  
B) Access failures (timeouts, service unavailability) need retry decisions; valid empty results represent successful queries with no matches  
C) Access failures return HTTP 500; empty results return HTTP 200  
D) Access failures are always retriable  

**Correct Answer: B**  
The exam guide distinguishes between access failures (needing retry decisions) and valid empty results (representing successful queries with no matches). Confusing the two leads to either unnecessary retries or missed recovery opportunities.

---

**Q89.** A subagent encounters a transient database timeout. What is the recommended error handling approach?

A) Immediately propagate the error to the coordinator with "database unavailable"  
B) Implement local error recovery within the subagent; if recovery fails, propagate to the coordinator with structured error context including what was attempted and partial results  
C) Retry indefinitely until the database responds  
D) Return empty results marked as successful  

**Correct Answer: B**  
The exam guide recommends local error recovery within subagents for transient failures. Only propagate to the coordinator errors that cannot be resolved locally, and include what was attempted and partial results.

---

**Q90.** Why is returning empty results as success (silently suppressing errors) an anti-pattern?

A) It wastes API tokens  
B) It prevents any recovery by making the coordinator believe the query succeeded with no matches, when in reality the data source was unavailable  
C) It increases latency  
D) It violates API contracts  

**Correct Answer: B**  
Silently suppressing errors by returning empty results as success prevents any recovery. The coordinator believes the query succeeded, when the data source may have been unavailable. The coordinator cannot make informed decisions without knowing a failure occurred.

---

**Q91.** Your structured error response includes `errorCategory: "transient"`, `isRetryable: true`, `retryAfterMs: 2000`, and `description: "Database connection pool exhausted, expected recovery within 2 seconds"`. Why is this a good error response?

A) It includes a retry delay  
B) It includes all the information the agent needs to make an intelligent recovery decision: the error type, whether to retry, when to retry, and why the error occurred  
C) It's in JSON format  
D) It includes technical details  

**Correct Answer: B**  
This error response includes everything for intelligent recovery: error category (transient), retryability (true), timing guidance (retry after 2s), and context (connection pool exhausted). The agent can decide to wait and retry rather than escalating or giving up.

---

### Task Statement 2.3: Tool Distribution and tool_choice

**Q92.** Your synthesis subagent has access to 18 tools, including web search, document analysis, database queries, and email sending. It frequently misuses tools outside its specialization. What should you do?

A) Add more detailed system prompt instructions  
B) Restrict each subagent's tool set to only those relevant to its role, preventing cross-specialization misuse  
C) Add a validation layer that checks tool appropriateness  
D) Train the model on correct tool usage patterns  

**Correct Answer: B**  
The exam guide states that agents with tools outside their specialization tend to misuse them. The solution is restricting each subagent's tool set to only those relevant to its role (e.g., synthesis tools only for the synthesis agent).

---

**Q93.** What does `tool_choice: "any"` configure?

A) The model can choose any tool from a predefined list  
B) The model must call a tool but can choose which one — it will not return conversational text  
C) The model chooses the best tool automatically  
D) All tools are called in sequence  

**Correct Answer: B**  
`tool_choice: "any"` guarantees the model calls a tool rather than returning conversational text. The model must select a tool but has freedom to choose which one. This is useful when you need structured output guaranteed.

---

**Q94.** You want to ensure that `extract_metadata` is always called before any enrichment tools. What `tool_choice` configuration should you use?

A) `tool_choice: "auto"`  
B) `tool_choice: {"type": "tool", "name": "extract_metadata"}`  
C) `tool_choice: "any"`  
D) `tool_choice: "sequential"`  

**Correct Answer: B**  
Forced tool selection `tool_choice: {"type": "tool", "name": "extract_metadata"}` ensures a specific tool is called first. After this forced first call, subsequent steps process in follow-up turns where the model can choose other tools.

---

**Q95.** A synthesis agent frequently needs to verify simple facts (dates, names, statistics). Currently, this requires a round trip through the coordinator to the web search agent. What is the recommended optimization?

A) Give the synthesis agent full web search capabilities  
B) Provide a scoped `verify_fact` tool for simple lookups while routing complex verifications through the coordinator  
C) Cache all facts in advance  
D) Remove fact verification requirements  

**Correct Answer: B**  
The exam guide recommends providing scoped cross-role tools for high-frequency needs (e.g., a `verify_fact` tool for the synthesis agent) while routing complex cases through the coordinator. This balances efficiency with proper specialization.

---

**Q96.** What is the risk of setting `tool_choice: "auto"` when you need guaranteed structured output?

A) The model might choose the wrong tool  
B) The model may return conversational text instead of calling a tool — `"auto"` does not guarantee tool usage  
C) It's slower than forced selection  
D) It uses more tokens  

**Correct Answer: B**  
With `tool_choice: "auto"`, the model may return text instead of calling a tool. When structured output is required, use `"any"` (must call some tool) or forced selection (must call a specific tool).

---

**Q97.** Your search subagent has a `fetch_url` tool that can fetch any URL. In practice, it sometimes fetches non-document URLs (social media, ads). What should you do?

A) Add URL filtering in the system prompt  
B) Replace `fetch_url` with a constrained `load_document` tool that validates document URLs  
C) Block non-document URLs at the network level  
D) Add a content filter after fetching  

**Correct Answer: B**  
The exam guide recommends replacing generic tools with constrained alternatives. Replacing `fetch_url` with `load_document` that validates document URLs prevents misuse by design, not by instruction.

---

**Q98.** How many tools should a well-designed subagent typically have access to?

A) As many as possible for flexibility  
B) 4-5 tools relevant to its role — too many (e.g., 18) degrades selection reliability  
C) Exactly 1 tool per subagent  
D) 10-15 tools for comprehensive coverage  

**Correct Answer: B**  
The exam guide states that 4-5 tools is an appropriate number. Giving an agent 18 tools degrades reliability by increasing decision complexity. Each subagent should have only tools relevant to its specific role.

---

### Task Statement 2.4: MCP Server Integration

**Q99.** Where should you configure MCP servers that the entire team needs to use?

A) In each developer's `~/.claude.json`  
B) In the project-level `.mcp.json` file, which is version-controlled and shared  
C) In the system prompt  
D) In environment variables  

**Correct Answer: B**  
Project-level MCP server configuration goes in `.mcp.json`, which is version-controlled and available to all team members. User-level `~/.claude.json` is for personal/experimental servers.

---

**Q100.** Your `.mcp.json` file needs a GitHub token for authentication. How should you handle the credential without committing secrets?

A) Hard-code the token in `.mcp.json`  
B) Use environment variable expansion: `${GITHUB_TOKEN}` in `.mcp.json`  
C) Store the token in a separate `secrets.json` file  
D) Pass the token as a command-line argument  

**Correct Answer: B**  
Environment variable expansion in `.mcp.json` (e.g., `${GITHUB_TOKEN}`) allows credential management without committing secrets to version control. This is the documented approach for MCP server authentication.

---

**Q101.** Where should you configure a personal, experimental MCP server that only you use?

A) In the project-level `.mcp.json`  
B) In user-scoped `~/.claude.json`  
C) In `CLAUDE.md`  
D) In the system prompt  

**Correct Answer: B**  
Personal/experimental MCP servers should be configured in user-scoped `~/.claude.json`. This keeps them separate from the team's shared configuration and prevents experimental servers from affecting teammates.

---

**Q102.** Your agent ignores a powerful MCP tool and instead uses the built-in `Grep` tool for code analysis, even though the MCP tool provides richer results. What should you do?

A) Remove the Grep tool  
B) Enhance the MCP tool's description to explain its capabilities and outputs in detail, preventing the agent from preferring built-in tools over the more capable MCP tool  
C) Force the agent to always use the MCP tool  
D) Add a rule that prohibits using Grep  

**Correct Answer: B**  
The exam guide recommends enhancing MCP tool descriptions to explain capabilities and outputs in detail. When built-in tools have clearer descriptions, agents naturally prefer them. Better MCP tool descriptions level the playing field.

---

**Q103.** You need to integrate with Jira for issue tracking. Should you build a custom MCP server or use a community one?

A) Always build custom for security  
B) Choose existing community MCP servers for standard integrations like Jira; reserve custom servers for team-specific workflows  
C) Always use community servers to save time  
D) Build a custom server and publish it as a community server  

**Correct Answer: B**  
The exam guide recommends choosing existing community MCP servers for standard integrations (like Jira), reserving custom servers for team-specific workflows that aren't covered by existing solutions.

---

**Q104.** Your agent makes many exploratory tool calls to discover what data is available in a database. How can you reduce these exploratory calls?

A) Cache all database data in memory  
B) Expose content catalogs as MCP resources, giving agents visibility into available data without requiring exploratory tool calls  
C) Pre-populate the system prompt with all database schema information  
D) Limit the agent's tool calls per session  

**Correct Answer: B**  
MCP resources expose content catalogs (issue summaries, documentation hierarchies, database schemas) to reduce exploratory tool calls. The agent can browse available data through resources before making targeted tool calls.

---

**Q105.** When are tools from configured MCP servers available to the agent?

A) They must be manually imported at each session start  
B) They are discovered at connection time and available simultaneously from all configured servers  
C) They are available only after explicit activation  
D) They load lazily when first referenced  

**Correct Answer: B**  
Tools from all configured MCP servers are discovered at connection time and available simultaneously to the agent. No manual import or activation is needed.

---

### Task Statement 2.5: Built-in Tools

**Q106.** You need to find all files in the codebase that call a specific function `processRefund`. Which built-in tool should you use?

A) Glob — it finds files by pattern  
B) Grep — it searches file contents for patterns like function names  
C) Read — it reads file contents  
D) Bash — run a find command  

**Correct Answer: B**  
Grep is for content search — searching file contents for patterns like function names, error messages, or import statements. Finding all callers of `processRefund` requires searching code content, not file names.

---

**Q107.** You need to find all test files in the codebase (files matching `**/*.test.tsx`). Which built-in tool should you use?

A) Grep — it searches for content  
B) Glob — it finds files by name or extension patterns  
C) Read — it reads file contents  
D) Bash — run an ls command  

**Correct Answer: B**  
Glob is for file path pattern matching — finding files by name or extension patterns. `**/*.test.tsx` is a glob pattern that matches test files, making Glob the appropriate tool.

---

**Q108.** You try to use the Edit tool to modify a file, but it fails because the target text appears multiple times. What should you do?

A) Try Edit with a longer target string  
B) Use Read to load the full file contents, then use Write to replace the entire file with modifications  
C) Use Bash to run a sed command  
D) Give up and ask the user to make the change  

**Correct Answer: B**  
When Edit fails due to non-unique text matches, using Read + Write as a fallback is the documented approach. Read loads the full file, and Write replaces it with the modified version.

---

**Q109.** You're exploring an unfamiliar codebase and want to understand the architecture. What is the recommended approach using built-in tools?

A) Read all files in the repository upfront  
B) Start with Grep to find entry points, then use Read to follow imports and trace flows incrementally  
C) Use Glob to list all files and read them alphabetically  
D) Run the application and observe behavior  

**Correct Answer: B**  
Building codebase understanding incrementally is recommended: start with Grep to find entry points, then use Read to follow imports and trace flows. This is more efficient than reading all files upfront.

---

**Q110.** You need to trace how a function is used across wrapper modules. What is the recommended approach?

A) Search for the function name in all files  
B) First identify all exported names, then search for each name across the codebase  
C) Read each file and manually trace the imports  
D) Use a static analysis tool  

**Correct Answer: B**  
The exam guide describes tracing function usage across wrapper modules by first identifying all exported names, then searching for each name across the codebase. This catches indirect usage through re-exports.

---

**Q111.** When should you use Read versus Edit for file modifications?

A) Always use Edit for modifications  
B) Use Edit for targeted modifications using unique text matching; use Read + Write as a fallback when Edit fails due to non-unique matches  
C) Always use Read + Write for safety  
D) Use Edit only for small files  

**Correct Answer: B**  
Edit is for targeted modifications using unique text matching. Read/Write is the fallback when Edit cannot find unique anchor text. Edit is preferred when possible because it's more efficient, but Read + Write provides reliability.

---

**Q112.** What is the difference between Grep and Glob?

A) They serve the same purpose  
B) Grep searches file **contents** for patterns; Glob finds **file paths** matching naming patterns  
C) Grep is faster; Glob is more accurate  
D) Grep works on text files; Glob works on binary files  

**Correct Answer: B**  
This is a fundamental distinction. Grep searches file contents (code, text), while Glob matches file paths (names, extensions). Use Grep to find "where is this function called?" and Glob to find "where are the test files?"

---

**Q113.** You want to find all error messages in the codebase that contain "connection refused." Which tool is appropriate?

A) Glob  
B) Grep — it searches file contents for specific patterns like error messages  
C) Read  
D) Edit  

**Correct Answer: B**  
Grep is the appropriate tool for searching file contents for specific patterns like error messages. "Connection refused" is a text pattern to find within file contents.

---

**Q114.** An agent is given access to Grep, Glob, Read, Write, Edit, Bash, and 12 additional MCP tools. Tool selection reliability has degraded. What is the most likely cause?

A) The built-in tools are conflicting with MCP tools  
B) The agent has too many tools (18+), increasing decision complexity and degrading selection reliability  
C) The Bash tool is interfering with other tools  
D) The agent needs a larger context window for all tool descriptions  

**Correct Answer: B**  
Having 18+ tools degrades tool selection reliability. The exam guide recommends 4-5 tools per subagent. Consider distributing tools across specialized subagents.

---

### Additional Tool Design & MCP Questions

**Q115.** Your MCP tool returns `{"results": []}` both when no results are found and when the database is unreachable. Why is this a problem?

A) Empty arrays waste memory  
B) The agent cannot distinguish between valid empty results (no matching records) and access failures (database unreachable), preventing appropriate recovery  
C) The response format is non-standard  
D) Empty results should never be returned  

**Correct Answer: B**  
This is a critical distinction from the exam guide. Access failures need retry decisions, while valid empty results represent successful queries with no matches. Returning the same response for both prevents the agent from making appropriate recovery decisions.

---

**Q116.** You have both project-level `.mcp.json` and user-level `~/.claude.json` MCP configurations. How do they interact?

A) Only one can be active at a time  
B) Tools from both are discovered at connection time and available simultaneously  
C) User-level settings override project-level settings  
D) Project-level settings override user-level settings  

**Correct Answer: B**  
Tools from all configured MCP servers (both project and user scope) are discovered at connection time and available simultaneously to the agent. They coexist without overriding each other.

---

**Q117.** Your team debates whether to add a `search_jira` tool to the synthesis agent, which currently has 4 analysis-focused tools. The synthesis agent occasionally needs to look up Jira tickets. What is the recommended approach?

A) Add the full Jira search tool to the synthesis agent  
B) Don't add it — the synthesis agent shouldn't have cross-role tools  
C) Provide a scoped, read-only Jira lookup tool for the synthesis agent for this high-frequency need, while routing complex Jira operations through the coordinator  
D) Have the synthesis agent ask the coordinator for every Jira lookup  

**Correct Answer: C**  
The exam guide recommends providing scoped cross-role tools for high-frequency needs while routing complex cases through the coordinator. A limited, read-only lookup addresses the common case without giving the synthesis agent full Jira capabilities.

---

**Q118.** You configure a new MCP server in `.mcp.json` but the agent never uses it, preferring built-in tools. The MCP tool description says "Queries the database." What should you improve?

A) Force the agent to use the MCP tool via `tool_choice`  
B) Enhance the description to explain the tool's specific capabilities, data it accesses, output format, and advantages over built-in alternatives  
C) Remove competing built-in tools  
D) Add more MCP tools to increase their presence  

**Correct Answer: B**  
The exam guide emphasizes enhancing MCP tool descriptions to explain capabilities and outputs in detail. "Queries the database" is too vague. The description should explain what data is available, what queries are supported, output format, and when to use it versus built-in tools.

---

**Q119.** What are MCP resources used for?

A) Storing tool configurations  
B) Exposing content catalogs (issue summaries, documentation hierarchies, database schemas) to reduce exploratory tool calls  
C) Managing user sessions  
D) Authenticating API requests  

**Correct Answer: B**  
MCP resources expose content catalogs to give agents visibility into available data without requiring exploratory tool calls. They serve as browsable directories of information the agent can reference.

---

**Q120.** An error response from your MCP tool includes: `{"isError": true, "errorCategory": "validation", "isRetryable": false, "description": "Order ID format must be ORD-XXXXX. Received: 12345"}`. Why is this a well-designed error response?

A) It uses the isError flag  
B) It includes all information the agent needs: the error category (validation, not transient), retryability (false — fixing the input, not retrying), and a specific description of what's wrong and the expected format  
C) It's in JSON format  
D) It includes the original input  

**Correct Answer: B**  
This response follows all best practices from the exam guide: uses the MCP isError flag, categorizes the error (validation), indicates non-retryability, and provides a human-readable description with the expected format. The agent can now fix the input rather than retrying.

---

**Q121.** Your MCP tool handles a "customer not eligible for promotion" business rule. The tool returns `{"isError": true, "message": "Ineligible"}`. How should you improve this?

A) Return a more detailed error code  
B) Include `isRetryable: false` and a customer-friendly explanation so the agent can communicate appropriately: e.g., `"description": "This customer's account type (Basic) is not eligible for the Premium promotion. Eligibility requires a Premium or Business account."`  
C) Return HTTP 403  
D) Silently apply an alternative promotion  

**Correct Answer: B**  
For business rule violations, include `retriable: false` and customer-friendly explanations so the agent can communicate appropriately. The description should explain why the action was denied in terms that can be shared with the customer.

---

**Q122.** You are building a coordinator that delegates to subagents. Subagent A (web search) has 5 tools, Subagent B (analysis) has 4 tools, and Subagent C (synthesis) has 3 tools. Should the coordinator have access to all 12 tools?

A) Yes, for maximum flexibility  
B) No — the coordinator should primarily have the Task tool for delegating to subagents, plus any coordinator-specific tools. Giving it all 12 tools would degrade selection reliability  
C) The coordinator should have all tools but with higher priority for delegation  
D) The coordinator should have read-only versions of all tools  

**Correct Answer: B**  
The coordinator's role is orchestration, not direct tool execution. It primarily needs the Task tool to delegate work to specialized subagents. Adding all 12 tools would increase decision complexity and lead to the coordinator attempting tasks that should be delegated.

---

**Q123.** When should you use `tool_choice: "any"` versus forced tool selection?

A) They are interchangeable  
B) Use `"any"` when the model must call a tool but the specific tool can be chosen by the model; use forced selection when a specific tool must be called first  
C) Use `"any"` for simple tasks and forced selection for complex tasks  
D) Use `"any"` in production and forced selection in testing  

**Correct Answer: B**  
`tool_choice: "any"` guarantees a tool call but lets the model choose which tool. Forced selection (`{"type": "tool", "name": "..."}`) ensures a specific tool is called. Use "any" when you need structured output from any of several tools; use forced selection when a specific tool must execute first.

---

**Q124.** A tool returns 50 fields per customer lookup, but only 5 fields are relevant to the agent's task. What should you do?

A) Return all 50 fields for completeness  
B) Use hooks or tool configuration to trim verbose outputs to only relevant fields before they accumulate in context  
C) Let the model filter out irrelevant fields  
D) Return only a summary  

**Correct Answer: B**  
The exam guide emphasizes trimming verbose tool outputs to only relevant fields before they accumulate in context. Returning 50 fields when only 5 are needed wastes context tokens and can confuse the model.

---

**Q125.** When designing error responses for MCP tools, what four error categories should you distinguish between?

A) Client, server, network, timeout  
B) Transient errors, validation errors, business errors, and permission errors  
C) Fatal, warning, info, debug  
D) Input, output, processing, storage  

**Correct Answer: B**  
The exam guide identifies four error categories: transient errors (timeouts, service unavailability), validation errors (invalid input), business errors (policy violations), and permission errors. Each requires different recovery approaches.

---

**Q126.** Your agent needs to process a batch of 100 documents. You use the Message Batches API but include tool calls within each request that need mid-request execution. Will this work?

A) Yes, batch API supports tool calling  
B) No — the batch API does not support multi-turn tool calling within a single request; you cannot execute tools mid-request and return results  
C) Yes, but only with synchronous tool calls  
D) It depends on the tool type  

**Correct Answer: B**  
The Message Batches API does not support multi-turn tool calling within a single request. It cannot execute tools mid-request and return results. This is a key limitation to understand when designing batch processing workflows.

---

**Q127.** You have a `fetch_url` tool available to a synthesis agent. The agent starts fetching random URLs during synthesis, breaking the research pipeline. What principle does this violate?

A) Least privilege — the synthesis agent shouldn't have URL fetching capabilities that are outside its specialization  
B) Performance — URL fetching is slow  
C) Security — external URLs may be malicious  
D) Consistency — URL content changes over time  

**Correct Answer: A**  
Agents with tools outside their specialization tend to misuse them. The synthesis agent's role is to synthesize information from research results, not to fetch URLs. This tool should be restricted to the research/search subagent only.

---

**Q128.** When configuring environment variables in `.mcp.json`, what is the correct syntax for referencing a GitHub token?

A) `%GITHUB_TOKEN%`  
B) `${GITHUB_TOKEN}`  
C) `$GITHUB_TOKEN`  
D) `{{GITHUB_TOKEN}}`  

**Correct Answer: B**  
The documented syntax for environment variable expansion in `.mcp.json` is `${GITHUB_TOKEN}`. This allows credential management without committing secrets to version control.

---

**Q129.** Your agent has access to both a built-in Grep tool and a custom MCP `code_search` tool. The `code_search` tool provides semantic code search with richer results. The agent consistently prefers Grep. What is the most likely reason?

A) Grep is faster  
B) The built-in Grep tool has a well-known description while the `code_search` MCP tool likely has a vague or insufficient description that doesn't explain its advantages  
C) The agent is hardcoded to prefer built-in tools  
D) MCP tools have lower priority  

**Correct Answer: B**  
The exam guide notes that agents may prefer built-in tools over more capable MCP tools when the MCP tool descriptions don't adequately explain capabilities. Enhancing MCP tool descriptions to detail their advantages is the fix.

---

**Q130.** What role do MCP resources play in reducing agent costs?

A) They cache tool results  
B) They expose content catalogs so agents can browse available data without making exploratory tool calls, reducing unnecessary API interactions  
C) They compress tool inputs  
D) They batch tool calls  

**Correct Answer: B**  
MCP resources give agents visibility into available data (issue summaries, documentation hierarchies, database schemas) without requiring exploratory tool calls. This reduces unnecessary interactions and associated costs.

---

**Q131.** A developer configures an MCP server in `~/.claude.json` with a custom authentication tool. Their teammate cannot access it. Why?

A) The server is down  
B) User-level `~/.claude.json` configurations are personal and not shared with teammates via version control; it should be in project-level `.mcp.json` if the team needs it  
C) The authentication token expired  
D) Both developers need to be on the same network  

**Correct Answer: B**  
User-level configurations in `~/.claude.json` are personal and not shared via version control. If the team needs access, the MCP server should be configured in project-level `.mcp.json`.

---

**Q132.** Your tool has these parameters: `order_id` (required), `include_history` (optional, boolean), `date_range` (optional, string). How should you document these in the tool description?

A) List only the required parameter  
B) Document all parameters with their types, whether they're required or optional, expected formats, default values, and examples of valid inputs  
C) Refer to external documentation  
D) List parameter names only  

**Correct Answer: B**  
Tool descriptions should include input formats, example queries, and edge cases. All parameters should be documented with types, required/optional status, formats, and examples to enable reliable tool usage.

---

**Q133.** What is the principle of least privilege as applied to agent tool access?

A) Give agents the minimum tools needed; restrict each subagent's toolkit to tools relevant to its role  
B) Give all agents access to all tools but restrict usage via prompts  
C) Create one tool per agent  
D) Allow agents to request tools dynamically  

**Correct Answer: A**  
The principle of least privilege in the context of agent tool access means restricting each subagent's tool set to those relevant to its role. This prevents cross-specialization misuse and improves tool selection reliability.

---

**Q134.** You need to force the agent to call `validate_input` before any other tool. After validation, the agent should choose tools freely. How do you configure this?

A) Add "always call validate_input first" to the system prompt  
B) Use `tool_choice: {"type": "tool", "name": "validate_input"}` on the first turn, then switch to `tool_choice: "auto"` for subsequent turns  
C) Create a pre-processing hook  
D) Make validate_input the only tool in the first turn  

**Correct Answer: B**  
Forced tool selection on the first turn ensures `validate_input` runs first. Subsequent turns use `"auto"` for flexible tool selection. This is the documented approach for ensuring tool ordering without permanent restrictions.

---

**Q135.** Why should you review system prompts when debugging tool selection issues?

A) System prompts don't affect tool selection  
B) Keyword-sensitive instructions in system prompts can create unintended tool associations that override well-written tool descriptions  
C) System prompts might contain tool definitions  
D) System prompts affect model temperature  

**Correct Answer: B**  
The exam guide warns that system prompt wording can impact tool selection. Keyword-sensitive instructions (e.g., "always use X when the user says Y") can create unintended tool associations that override the natural tool selection based on descriptions.

---
