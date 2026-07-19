# Claude Certified Architect – Foundations: Exam Question Bank

## Part 5: Domain 5 — Context Management & Reliability (15% of Exam)

---

### Task Statement 5.1: Context Preservation

**Q256.** Your customer support agent handles a long conversation. After multiple exchanges, it summarizes early details as "the customer mentioned some concerns about their order." What critical information was lost?

A) Sentiment information  
B) Transactional facts — order numbers, amounts, dates, and specific customer-stated expectations are condensed into vague summaries during progressive summarization  
C) The customer's name  
D) The conversation length  

**Correct Answer: B**  
Progressive summarization risks condensing numerical values, percentages, dates, and customer-stated expectations into vague summaries. Specific transactional facts must be preserved to avoid information loss.

---

**Q257.** How should you preserve critical transactional facts across long conversations?

A) Repeat them in every message  
B) Extract transactional facts (amounts, dates, order numbers, statuses) into a persistent "case facts" block included in each prompt, outside summarized history  
C) Store them in a database  
D) Include them in the system prompt  

**Correct Answer: B**  
The exam guide recommends extracting transactional facts into a persistent "case facts" block included in each prompt. This keeps critical data separate from summarized history where it might be lost.

---

**Q258.** You have a 50-page research document and ask Claude to extract findings. The model provides detailed findings from the beginning and end but seems to miss content from the middle sections. What phenomenon explains this?

A) Context window overflow  
B) The "lost in the middle" effect — models reliably process information at the beginning and end of long inputs but may omit findings from middle sections  
C) The document is too long  
D) The middle sections are less important  

**Correct Answer: B**  
The "lost in the middle" effect means models process information at the beginning and end of long inputs more reliably but may omit findings from middle sections. This is a known limitation of attention mechanisms.

---

**Q259.** How should you mitigate the "lost in the middle" effect when aggregating inputs from multiple sources?

A) Shorten the input  
B) Place key findings summaries at the beginning and organize detailed results with explicit section headers to mitigate position effects  
C) Process one source at a time  
D) Use a model with a larger context window  

**Correct Answer: B**  
Placing key findings at the beginning and organizing results with explicit section headers mitigates position effects. This ensures critical information is in the positions where the model processes it most reliably.

---

**Q260.** Your agent calls `lookup_order` which returns 40+ fields per order (shipping carrier, package dimensions, warehouse location, etc.). Only 5 fields are relevant to the customer's return request. What should you do?

A) Include all fields for completeness  
B) Trim verbose tool outputs to only relevant fields before they accumulate in context  
C) Let the model filter out irrelevant fields  
D) Compress the fields  

**Correct Answer: B**  
Tool results with 40+ fields consume tokens disproportionately to their relevance. Trimming to only the 5 relevant fields before they enter the context prevents unnecessary token consumption and reduces noise.

---

**Q261.** A multi-issue support session handles return, billing, and shipping questions. By the third issue, the agent confuses order details from the first issue with the third. What should you implement?

A) Handle issues in separate sessions  
B) Extract and persist structured issue data (order IDs, amounts, statuses) into a separate context layer for multi-issue sessions  
C) Limit sessions to one issue  
D) Add more context window  

**Correct Answer: B**  
The exam guide recommends extracting and persisting structured issue data into a separate context layer for multi-issue sessions. This prevents cross-contamination of details between different issues.

---

**Q262.** When downstream agents have limited context budgets, what should upstream agents return?

A) Full verbose content  
B) Structured data (key facts, citations, relevance scores) instead of verbose content and reasoning chains  
C) Summarized text  
D) Compressed data  

**Correct Answer: B**  
Upstream agents should return structured data (key facts, citations, relevance scores) instead of verbose content and reasoning chains when downstream agents have limited context budgets. This maximizes information density.

---

**Q263.** Why must complete conversation history be passed in subsequent API requests?

A) For billing purposes  
B) To maintain conversational coherence — the API is stateless and needs the full history to understand context  
C) For audit logging  
D) It's optional  

**Correct Answer: B**  
The Claude API is stateless. Passing complete conversation history in subsequent requests is essential for maintaining conversational coherence. Without it, the model loses context from previous turns.

---

**Q264.** Subagents in your research pipeline return 2000-word essays with embedded findings. The synthesis agent struggles with the volume. What should you require?

A) Shorter essays  
B) Require subagents to include metadata (dates, source locations, methodological context) in structured outputs to support accurate downstream synthesis  
C) Use a bigger model for synthesis  
D) Skip synthesis and combine essays  

**Correct Answer: B**  
Subagents should return structured outputs with metadata rather than verbose prose. Structured data with key facts, citations, and relevance scores is much more efficient for downstream synthesis than long-form text.

---

### Task Statement 5.2: Escalation and Ambiguity Resolution

**Q265.** A customer says "I want to speak to a human agent." Your agent has identified a straightforward issue it could resolve in one step. What should the agent do?

A) Resolve the issue first, then offer to connect to a human  
B) Honor the explicit customer request for a human agent immediately without first attempting investigation  
C) Ask the customer why they want a human  
D) Convince the customer to let the agent try first  

**Correct Answer: B**  
The exam guide states that explicit customer requests for human agents should be honored immediately without first attempting investigation. This is a non-negotiable escalation trigger.

---

**Q266.** A frustrated customer describes a simple return request. Their tone is angry but the issue is straightforward. Should the agent escalate based on the negative sentiment?

A) Yes, always escalate for frustrated customers  
B) No — acknowledge the frustration while offering resolution. Sentiment-based escalation is unreliable because negative sentiment doesn't correlate with case complexity  
C) Escalate only if sentiment exceeds a threshold  
D) Ask the customer if they want to escalate  

**Correct Answer: B**  
Sentiment-based escalation is unreliable. The exam guide notes that the agent should acknowledge frustration while offering resolution when the issue is within capability. Escalate only if the customer reiterates their preference for a human.

---

**Q267.** A customer asks "Can you match the price I found at a competitor?" Your company policy addresses price adjustments for items on your own site but is silent on competitor matching. What should the agent do?

A) Deny the request because it's not in the policy  
B) Escalate when policy is ambiguous or silent on the customer's specific request  
C) Match the competitor price to satisfy the customer  
D) Ask the customer to contact the competitor  

**Correct Answer: B**  
The exam guide states that agents should escalate when policy is ambiguous or silent on the customer's specific request. If policy only addresses own-site adjustments and doesn't mention competitor matching, this is a policy gap requiring human judgment.

---

**Q268.** The `get_customer` tool returns three matching customer records for "John Smith." The agent picks the one with the most recent activity. Is this approach correct?

A) Yes, most recent activity is a good heuristic  
B) No — when multiple matches occur, the agent should ask for additional identifiers rather than selecting based on heuristics  
C) Yes, if the confidence is high  
D) No, it should pick the first result  

**Correct Answer: B**  
Multiple customer matches require clarification (requesting additional identifiers like email, phone, or account number) rather than heuristic selection. Any automated selection risks choosing the wrong customer.

---

**Q269.** What are appropriate escalation triggers? (Select the best answer)

A) High sentiment negativity and low confidence scores  
B) Customer requests for a human, policy exceptions/gaps, and inability to make meaningful progress  
C) Complex cases and large refund amounts  
D) Long conversation length and multiple tool calls  

**Correct Answer: B**  
The exam guide identifies appropriate escalation triggers: customer requests for a human, policy exceptions/gaps (not just complex cases), and inability to make meaningful progress. Sentiment and confidence are explicitly noted as unreliable proxies.

---

**Q270.** An agent's self-reported confidence score shows 9/10 for a case it handles incorrectly. Why are self-reported confidence scores unreliable?

A) The scoring system is not calibrated  
B) LLM self-reported confidence is poorly calibrated — the model may be incorrectly confident on hard cases and uncertain on straightforward ones  
C) The model is overconfident by design  
D) Confidence scores need training data  

**Correct Answer: B**  
The exam guide explicitly states that self-reported confidence scores are unreliable proxies for actual case complexity. The model may express high confidence on cases it handles incorrectly.

---

**Q271.** A customer is frustrated about a delayed shipment. The agent can check the tracking status and provide an update. Should it escalate?

A) Yes, the customer is frustrated  
B) Acknowledge the frustration while offering to check the tracking status and provide an update. Escalate only if the customer explicitly asks for a human or the issue is beyond the agent's capability  
C) Ignore the frustration and provide facts  
D) Offer a refund  

**Correct Answer: B**  
The exam guide recommends acknowledging frustration while offering resolution when the issue is within capability. Escalation should only happen if the customer explicitly demands a human or the issue requires human judgment.

---

### Task Statement 5.3: Error Propagation

**Q272.** A subagent fails with a timeout and returns `{"status": "error", "message": "search unavailable"}` to the coordinator. Why is this insufficient?

A) It needs a status code  
B) Generic error statuses hide valuable context — the coordinator needs structured error context (failure type, attempted query, partial results, alternative approaches) to make intelligent recovery decisions  
C) It should include a stack trace  
D) The message is too short  

**Correct Answer: B**  
Generic error statuses prevent intelligent recovery. The coordinator needs structured context: what failed, what was attempted, any partial results, and potential alternatives. Without this, it can't decide whether to retry, try alternatives, or proceed with partial results.

---

**Q273.** A subagent catches a timeout exception and returns an empty result set marked as successful. What is wrong with this approach?

A) Nothing, empty results are valid  
B) Silently suppressing errors (returning empty results as success) is an anti-pattern — it prevents recovery by hiding that a failure occurred  
C) Empty results should be null, not empty  
D) The timeout should be logged  

**Correct Answer: B**  
Silently suppressing errors is explicitly called an anti-pattern. It hides the failure from the coordinator, preventing any recovery action. The coordinator believes the query succeeded with no matches when the data source was actually unavailable.

---

**Q274.** A subagent encounters an error it cannot resolve locally. What should it include in its error report to the coordinator?

A) Just the error message  
B) Structured error context including failure type, what was attempted, partial results, and potential alternatives  
C) The full stack trace  
D) A retry request  

**Correct Answer: B**  
Errors propagated to the coordinator should include structured context: failure type, what was attempted, any partial results, and potential alternatives. This enables the coordinator to make intelligent recovery decisions.

---

**Q275.** When should a subagent implement local error recovery versus propagating to the coordinator?

A) Always propagate to the coordinator  
B) Implement local recovery for transient failures; only propagate errors that cannot be resolved locally, including what was attempted and partial results  
C) Always handle locally  
D) Based on error severity  

**Correct Answer: B**  
Local recovery for transient failures (timeouts, temporary unavailability) reduces coordinator overhead. Only errors that cannot be resolved locally should propagate, with full context about what was attempted.

---

**Q276.** Why is terminating the entire workflow on a single subagent failure an anti-pattern?

A) It wastes resources  
B) Recovery strategies may succeed — other subagents may have useful results, and partial findings can still be valuable for the final output  
C) It's too aggressive  
D) The coordinator can't restart  

**Correct Answer: B**  
Terminating the entire workflow on a single failure is an anti-pattern because recovery strategies often exist. Other subagents may have succeeded, and partial results can still be valuable. The coordinator should assess options before terminating.

---

**Q277.** Your synthesis output lacks information about which topics have reliable data versus which have gaps due to unavailable sources. How should you improve this?

A) Add a disclaimer  
B) Structure synthesis output with coverage annotations indicating which findings are well-supported versus which topic areas have gaps due to unavailable sources  
C) Only include well-supported findings  
D) Mark all findings as tentative  

**Correct Answer: B**  
The exam guide recommends structuring synthesis output with coverage annotations. This distinguishes well-supported findings from areas with gaps, giving the reader accurate expectations about data quality.

---

### Task Statement 5.4: Large Codebase Exploration

**Q278.** During a long code exploration session, the agent starts giving vague answers like "based on typical patterns..." instead of referencing specific classes it discovered earlier. What is happening?

A) The model is lazy  
B) Context degradation — in extended sessions, models start giving inconsistent answers and referencing "typical patterns" rather than specific discoveries  
C) The model forgot the earlier findings  
D) The code hasn't changed  

**Correct Answer: B**  
Context degradation occurs in extended sessions. The model starts losing specificity and falls back to general patterns rather than referencing specific findings from earlier in the session. This is a natural limitation of long context interactions.

---

**Q279.** How can you counteract context degradation in long exploration sessions?

A) Start a new session  
B) Have agents maintain scratchpad files recording key findings, referencing them for subsequent questions  
C) Increase the context window  
D) Use a different model  

**Correct Answer: B**  
Scratchpad files persist key findings across context boundaries. By recording important discoveries and referencing them when needed, the agent maintains accuracy even as context degrades.

---

**Q280.** You need to investigate specific questions about a large codebase (find all test files, trace refund flow dependencies). How should you organize the investigation?

A) Have the main agent investigate everything  
B) Spawn subagents to investigate specific questions while the main agent preserves high-level coordination  
C) Read all files first  
D) Use grep for everything  

**Correct Answer: B**  
Subagent delegation isolates verbose exploration output while the main agent coordinates at a high level. Each subagent focuses on a specific investigation question, preventing the main agent's context from filling with verbose discovery output.

---

**Q281.** Between exploration phases, how should you transfer knowledge to the next phase?

A) Continue in the same session  
B) Summarize key findings from one phase before spawning subagents for the next, injecting summaries into initial context  
C) Start fresh without prior findings  
D) Share the full conversation history  

**Correct Answer: B**  
Summarizing key findings between phases and injecting them into the next phase's initial context ensures important discoveries carry forward without the overhead of full conversation history.

---

**Q282.** Your multi-agent system needs crash recovery. What approach ensures agents can resume after a system failure?

A) Checkpoint the entire conversation  
B) Design crash recovery using structured agent state exports (manifests) that the coordinator loads on resume and injects into agent prompts  
C) Log all API calls  
D) Save conversation to disk  

**Correct Answer: B**  
Structured state persistence for crash recovery involves each agent exporting state to a known location. The coordinator loads a manifest on resume and injects the state into agent prompts, enabling recovery.

---

**Q283.** When should you use `/compact` during a code exploration session?

A) At the start of every session  
B) When context fills with verbose discovery output during extended exploration sessions  
C) After every tool call  
D) Only when the model errors  

**Correct Answer: B**  
`/compact` reduces context usage during extended exploration sessions. It's used when verbose discovery output has accumulated and the context is becoming unwieldy.

---

**Q284.** You have a subagent that explores a module and produces 5000 tokens of analysis. You only need the key findings (about 200 tokens). How should you handle this?

A) Truncate the output  
B) Have the subagent return structured data (key findings, file paths, dependencies) instead of verbose analysis, or summarize its findings before passing to the coordinator  
C) Increase the context window  
D) Let the coordinator filter the output  

**Correct Answer: B**  
Subagents should return structured data rather than verbose content when downstream consumers have limited context. Key findings, file paths, and dependencies in structured format are more efficient than narrative analysis.

---

### Task Statement 5.5: Human Review Workflows

**Q285.** Your extraction pipeline reports 97% overall accuracy. Your team decides to automate all high-confidence extractions without human review. Is this safe?

A) Yes, 97% is excellent  
B) No — aggregate accuracy metrics may mask poor performance on specific document types or fields that need to be checked independently  
C) Yes, with spot checks  
D) Only for simple documents  

**Correct Answer: B**  
The exam guide warns that aggregate accuracy metrics (e.g., 97% overall) may mask poor performance on specific document types or fields. You need accuracy analysis by document type and field before automating.

---

**Q286.** How should you measure error rates in high-confidence extractions?

A) Compare against overall accuracy  
B) Use stratified random sampling for measuring error rates and detecting novel error patterns  
C) Check a random 1% sample  
D) Only check when users report errors  

**Correct Answer: B**  
Stratified random sampling ensures error rates are measured across different document types, fields, and confidence levels. This detects novel error patterns that random sampling might miss.

---

**Q287.** Your model outputs confidence scores for each extracted field. How should you use these scores for review routing?

A) Set a fixed threshold for all fields  
B) Calibrate field-level confidence scores using labeled validation sets, then route low-confidence extractions to human review  
C) Trust all high-confidence scores  
D) Ignore confidence scores  

**Correct Answer: B**  
Field-level confidence scores should be calibrated using labeled validation sets. This ensures the thresholds are meaningful before using them to route review attention.

---

**Q288.** Before automating high-confidence extractions, what validation should you perform?

A) Check overall accuracy only  
B) Validate accuracy by document type and field segment to verify consistent performance across all segments  
C) Run a single batch test  
D) Check the first 10 documents  

**Correct Answer: B**  
The exam guide emphasizes validating accuracy by document type and field before automating. Consistent performance across all segments is required — not just high overall accuracy that might mask segment-specific issues.

---

**Q289.** You have limited reviewer capacity. How should you prioritize which extractions to review?

A) Review randomly  
B) Route extractions with low model confidence or ambiguous/contradictory source documents to human review, prioritizing limited capacity  
C) Review the most recent extractions  
D) Review the longest documents  

**Correct Answer: B**  
Limited reviewer capacity should be directed to extractions with low model confidence or ambiguous/contradictory source documents. This focuses human attention where it's most needed.

---

### Task Statement 5.6: Information Provenance

**Q290.** Your synthesis agent combines findings from three research subagents into a report. The report states "revenue grew 15% year-over-year" but doesn't indicate which source this came from. What was lost?

A) The source name  
B) Source attribution — the claim-source mapping was lost during summarization when findings were compressed without preserving which source supported which claim  
C) The data accuracy  
D) The timestamp  

**Correct Answer: B**  
Source attribution is lost during summarization when findings are compressed without preserving claim-source mappings. The exam guide emphasizes requiring structured claim-source mappings that survive through synthesis.

---

**Q291.** Two credible sources report different market sizes: Source A says $50B, Source B says $65B. How should the synthesis handle this?

A) Average the values  
B) Pick the more recent source  
C) Annotate the conflict with source attribution: "Market size ranges from $50B (Source A, 2024) to $65B (Source B, 2025)" rather than arbitrarily selecting one value  
D) Omit the conflicting data  

**Correct Answer: C**  
The exam guide recommends annotating conflicts with source attribution rather than arbitrarily selecting one value. Both values should be presented with their sources, letting the reader assess which is more applicable.

---

**Q292.** Your subagents return findings with dates, but two findings about the same metric use data from different years. The synthesis treats them as contradictory. What's missing?

A) Better fact-checking  
B) Publication or data collection dates in structured outputs — temporal differences are being misinterpreted as contradictions  
C) Source verification  
D) Data normalization  

**Correct Answer: B**  
The exam guide emphasizes requiring publication/collection dates in structured outputs. Without temporal context, legitimate temporal differences (metrics changing over time) are misinterpreted as contradictions.

---

**Q293.** Your synthesis report converts all findings into uniform prose paragraphs. Financial data loses clarity compared to its original tabular format. What should you do differently?

A) Keep all findings as prose  
B) Render different content types appropriately: financial data as tables, news as prose, technical findings as structured lists  
C) Use only bullet points  
D) Standardize on tables  

**Correct Answer: B**  
The exam guide recommends rendering different content types appropriately in synthesis outputs — financial data as tables, news as prose, technical findings as structured lists — rather than converting everything to a uniform format.

---

**Q294.** How should reports distinguish between well-established findings and contested ones?

A) Mark all findings as tentative  
B) Structure reports with explicit sections distinguishing well-established findings from contested ones, preserving original source characterizations  
C) Only include well-established findings  
D) Add confidence scores to every finding  

**Correct Answer: B**  
Reports should have explicit sections distinguishing well-established findings from contested ones. This preserves original source characterizations and methodological context for the reader.

---

**Q295.** A subagent analyzes a document with conflicting internal values (e.g., page 3 says revenue is $10M but page 7 says $12M). What should the subagent do?

A) Pick the value from the later page  
B) Complete the analysis with conflicting values included and explicitly annotated, letting the coordinator decide how to reconcile  
C) Average the values  
D) Report an error  

**Correct Answer: B**  
The exam guide recommends completing analysis with conflicting values explicitly annotated, letting the coordinator decide how to reconcile. The subagent should not make reconciliation decisions unilaterally.

---

**Q296.** What structured output should subagents provide to support provenance tracking?

A) Summary paragraphs  
B) Claim-source mappings including source URLs, document names, relevant excerpts, and publication dates  
C) Simple bullet points  
D) Links to original documents  

**Correct Answer: B**  
Subagents should output structured claim-source mappings (source URLs, document names, relevant excerpts, publication dates) that downstream agents preserve through synthesis. This is the foundation of provenance tracking.

---

### Cross-Domain Scenario Questions

**Q297.** You're building a customer support agent. A customer says "I ordered two items, one arrived damaged and the other hasn't arrived yet." The agent calls `lookup_order` and gets 40 fields. It then summarizes: "Customer has an order issue." After three more exchanges, the agent can't remember the specific order numbers. What two improvements would fix this?

A) Increase context window and add memory  
B) (1) Trim `lookup_order` results to only relevant fields before entering context. (2) Extract transactional facts (order numbers, items, statuses) into a persistent "case facts" block  
C) Start a new session and use a bigger model  
D) Add more tools and better prompts  

**Correct Answer: B**  
Two context management principles: trim verbose tool outputs to relevant fields, and extract transactional facts into a persistent block. Together, these prevent both token waste and information loss.

---

**Q298.** A multi-agent system processes 500 documents nightly. The pipeline uses synchronous API calls, costing $100/night. Your team suggests switching to the Message Batches API. What is the expected outcome?

A) Same cost, better performance  
B) 50% cost savings ($50/night), but processing may take up to 24 hours with no latency SLA — acceptable for an overnight batch job  
C) No change in cost or performance  
D) 50% cost savings with guaranteed completion within 1 hour  

**Correct Answer: B**  
The Message Batches API provides 50% cost savings with processing times up to 24 hours. For an overnight batch job (non-blocking, latency-tolerant), this tradeoff is acceptable.

---

**Q299.** Your CI pipeline runs code review and test generation. The code review is a pre-merge blocker; test generation runs nightly. A developer proposes using the Message Batches API for both. What is the correct approach?

A) Use batch for both  
B) Keep synchronous API for the pre-merge blocker (needs immediate results); use batch API for nightly test generation (latency-tolerant, saves 50%)  
C) Keep synchronous for both  
D) Use batch for both with a fallback  

**Correct Answer: B**  
Match the API to the workflow requirements: synchronous for blocking pre-merge checks (needs immediate results), batch for overnight/nightly test generation (latency-tolerant, benefits from 50% cost savings).

---

**Q300.** In a multi-agent research system, the coordinator delegates to a web search subagent, a document analysis subagent, and a synthesis subagent. The synthesis subagent receives results but produces a report with no citations. What change should be made?

A) Add citation instructions to the synthesis prompt  
B) Require all subagents to output structured claim-source mappings that the synthesis subagent must preserve and merge when combining findings  
C) Add a citation subagent  
D) Post-process citations after synthesis  

**Correct Answer: B**  
The exam guide emphasizes structured claim-source mappings that the synthesis agent must preserve. This is an upstream change — all subagents must provide structured attribution, and the synthesis agent must maintain it through the synthesis process.

---

**Q301.** Your agent uses a PostToolUse hook to normalize dates. It also has a tool call interception hook to block refunds over $500. Additionally, the system prompt says "always verify identity first." A $600 refund request comes in. The agent skips identity verification and calls `process_refund`. What happens?

A) The refund processes because the prompt was ignored  
B) The tool call interception hook blocks the $600 refund and redirects to escalation — even though the agent skipped verification (prompt-based), the hook provides deterministic enforcement for the refund limit  
C) Nothing — the system prompt is always followed  
D) The PostToolUse hook catches the issue  

**Correct Answer: B**  
This demonstrates the difference between prompt-based guidance (identity verification, which was skipped) and programmatic enforcement (refund hook, which cannot be bypassed). The hook deterministically blocks the $600 refund regardless of the model's behavior.

---

**Q302.** You're building a structured data extraction system. Documents come in three types: invoices, contracts, and reports. Each has a different schema. The document type is unknown in advance. What is the complete technical approach?

A) Use one schema with all possible fields  
B) Define separate extraction tools with JSON schemas for each type. Set `tool_choice: "any"` to guarantee structured output while letting the model choose the appropriate schema. Make fields that may be absent nullable to prevent fabrication.  
C) Classify first, then extract  
D) Use a single flexible schema  

**Correct Answer: B**  
This combines several exam concepts: multiple extraction tools with specific schemas, `tool_choice: "any"` for guaranteed structured output with model-selected schema, and nullable fields to prevent hallucination for absent information.

---

**Q303.** An agent handles 100 customer interactions daily. It achieves 55% first-contact resolution (target: 80%). Analysis shows it escalates straightforward cases but attempts complex ones autonomously. What is the most effective first improvement?

A) Deploy a classifier model  
B) Add explicit escalation criteria with few-shot examples to the system prompt demonstrating when to escalate versus resolve autonomously  
C) Implement sentiment analysis  
D) Add more tools  

**Correct Answer: B**  
This mirrors the exam's sample question. Adding explicit escalation criteria with few-shot examples is the proportionate first response. It directly addresses unclear decision boundaries before adding infrastructure.

---

**Q304.** Your multi-agent research system produces a report. Upon review, you find that one section says "The market grew 20% (Source: Industry Report 2024)" while another section says "Growth was approximately 20%." What happened?

A) Different rounding  
B) Source attribution was lost in one section — the synthesis agent dropped the claim-source mapping during summarization  
C) Different sources  
D) Editing error  

**Correct Answer: B**  
Source attribution loss during synthesis is a common issue. The first section preserved the mapping; the second section lost it. Structured claim-source mappings must be preserved throughout the synthesis process.

---

**Q305.** Your CI pipeline generates test suggestions. A developer notices that 30% of suggestions duplicate existing tests. What is the fix?

A) Deduplicate after generation  
B) Provide existing test files in context so the generation avoids suggesting duplicate scenarios already covered by the test suite  
C) Generate fewer tests  
D) Only test new files  

**Correct Answer: B**  
Providing existing test files in context lets Claude Code see what's already tested and avoid duplicating those scenarios. This addresses the root cause rather than post-processing duplicates.

---

**Q306.** You need to design a crash recovery system for your multi-agent pipeline. The pipeline has 5 agents, each performing different tasks. How should you implement recovery?

A) Re-run the entire pipeline from scratch  
B) Each agent exports its state to a known location (manifest). The coordinator loads the manifest on resume and injects state into agent prompts to continue from where they left off  
C) Checkpoint the conversation every 5 minutes  
D) Use database transactions  

**Correct Answer: B**  
Structured state persistence for crash recovery uses manifests. Each agent exports state to a known location, and the coordinator loads the manifest on resume, injecting state into agent prompts for continuation.

---

**Q307.** Your agent processes a long multi-turn conversation. You notice the API responses become less coherent after turn 15. What is happening?

A) API timeout  
B) Context degradation from accumulating verbose tool results and conversation history — the model has difficulty maintaining focus across very long contexts  
C) Model quality degradation  
D) Rate limiting  

**Correct Answer: B**  
Context degradation from accumulating tool results and conversation history affects model coherence. Techniques like scratchpad files, context trimming, and structured fact extraction help maintain quality.

---

**Q308.** A synthesis agent receives findings from multiple sources. Some findings have dates, others don't. Statistics from 2020 and 2024 reports appear contradictory. How should the synthesis handle this?

A) Use the most recent data  
B) Include temporal data (publication/collection dates) and annotate that the differences may reflect temporal changes rather than contradictions  
C) Average the values  
D) Flag as unreliable  

**Correct Answer: B**  
The exam guide emphasizes requiring publication/collection dates to prevent temporal differences from being misinterpreted as contradictions. The synthesis should present both values with temporal context.

---

**Q309.** In a long exploration session, you've investigated 20 files and discovered key architecture patterns. You need to explore 10 more files. The context is getting full. What combination of techniques should you use?

A) Start a new session  
B) Use scratchpad files to persist key findings, `/compact` to reduce context, and subagent delegation for the next phase of exploration  
C) Continue in the same session  
D) Summarize and email findings  

**Correct Answer: B**  
Combining scratchpad files (persist findings), `/compact` (reduce context), and subagent delegation (isolate verbose exploration) addresses context limitations while preserving knowledge.

---

**Q310.** Your extraction pipeline has 98% accuracy on invoices but only 85% on contracts. The overall accuracy is 94%. Should you automate all high-confidence extractions?

A) Yes, 94% overall is excellent  
B) No — validate accuracy by document type to verify consistent performance. Contracts need improvement before automating that segment  
C) Yes, with a 2% error margin  
D) Only automate invoices  

**Correct Answer: B**  
Aggregate metrics mask segment-specific issues. The 85% accuracy on contracts is below acceptable thresholds and should be improved before automating. Analysis by document type is required before reducing human review.

---
