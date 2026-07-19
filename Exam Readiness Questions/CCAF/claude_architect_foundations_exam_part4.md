# Claude Certified Architect – Foundations: Exam Question Bank

## Part 4: Domain 4 — Prompt Engineering & Structured Output (20% of Exam)

---

### Task Statement 4.1: Explicit Criteria for Precision

**Q196.** Your code review agent flags too many false positives, causing developers to ignore its findings. The system prompt says "be conservative and only report high-confidence findings." Why isn't this working?

A) The temperature is too high  
B) General instructions like "be conservative" or "only report high-confidence findings" fail to improve precision compared to specific categorical criteria  
C) The model needs fine-tuning  
D) The context window is too small  

**Correct Answer: B**  
Vague instructions like "be conservative" don't improve precision. The exam guide states that specific categorical criteria (e.g., "flag comments only when claimed behavior contradicts actual code behavior") are needed instead of general confidence-based filtering.

---

**Q197.** Your review agent flags both security vulnerabilities (high value) and minor style issues (low value, high false positive rate). Developers have lost trust in all findings. What should you do?

A) Stop reviewing style issues permanently  
B) Temporarily disable high false-positive categories (style issues) to restore developer trust, while improving prompts for those categories  
C) Lower the priority of style findings  
D) Add "ignore style issues" to the system prompt  

**Correct Answer: B**  
The exam guide recommends temporarily disabling high false-positive categories to restore developer trust while improving prompts for those categories. High false positive rates in any category undermine confidence in accurate categories.

---

**Q198.** Which instruction would most effectively improve code review precision?

A) "Only report high-confidence issues"  
B) "Flag comments only when the claimed behavior contradicts actual code behavior. Skip minor style preferences and local naming patterns."  
C) "Be thorough but conservative"  
D) "Focus on important issues"  

**Correct Answer: B**  
The exam guide emphasizes explicit criteria over vague instructions. Option B provides specific rules: report contradictions between comments and code, skip style and local patterns. This gives the model clear decision boundaries.

---

**Q199.** You want consistent severity classification across code review findings. Currently, the same issue is rated "High" by one run and "Medium" by another. What should you do?

A) Fix the temperature setting  
B) Define explicit severity criteria with concrete code examples for each severity level  
C) Use a separate classification model  
D) Remove severity ratings  

**Correct Answer: B**  
Defining explicit severity criteria with concrete code examples for each level achieves consistent classification. Without concrete examples, the model's judgment varies between runs.

---

**Q200.** Your review prompt says "check that comments are accurate." This produces many false positives because the model flags stylistic preferences as inaccuracies. What is a more precise instruction?

A) "Check that all comments are correct"  
B) "Flag comments only when the described behavior directly contradicts the actual code logic; ignore stylistic choices and naming preferences"  
C) "Be more careful with comment checks"  
D) "Only flag comments that are obviously wrong"  

**Correct Answer: B**  
Specific criteria ("when described behavior contradicts actual code logic") is much more precise than general instructions ("check that comments are accurate"). The explicit exclusion of stylistic choices prevents false positives.

---

### Task Statement 4.2: Few-Shot Prompting

**Q201.** Your extraction pipeline processes documents with varied formats (inline citations vs bibliographies, narrative vs tables). Some format types produce empty fields. What is the most effective fix?

A) Add more validation rules  
B) Add few-shot examples showing correct extraction from documents with varied formats to address empty/null extraction  
C) Restrict to one document format  
D) Increase the context window  

**Correct Answer: B**  
Few-shot examples demonstrating correct handling of varied document structures (inline citations vs bibliographies, methodology sections vs embedded details) are the recommended approach for handling structural variety.

---

**Q202.** How many few-shot examples are typically recommended for ambiguous scenarios?

A) 1 example  
B) 2-4 targeted examples that show reasoning for why one action was chosen over plausible alternatives  
C) 10+ examples for comprehensive coverage  
D) As many as possible  

**Correct Answer: B**  
The exam guide recommends 2-4 targeted few-shot examples for ambiguous scenarios. These should show reasoning for why one action was chosen over plausible alternatives. More examples aren't necessarily better — quality and relevance matter.

---

**Q203.** Your code review consistently produces findings in different formats: some as bullet points, some as paragraphs, some with line numbers, some without. How do you fix this?

A) Post-process the output  
B) Include few-shot examples that demonstrate the specific desired output format (location, issue, severity, suggested fix) to achieve consistency  
C) Add "use consistent formatting" to the prompt  
D) Parse and reformat after generation  

**Correct Answer: B**  
Few-shot examples demonstrating the specific desired output format achieve consistency more effectively than format instructions. The model generalizes from the pattern shown in examples.

---

**Q204.** Your review agent flags certain code patterns as issues, but experienced developers recognize them as acceptable project patterns. How can you reduce these false positives while still catching genuine issues?

A) Remove the flagged patterns from the review  
B) Provide few-shot examples distinguishing acceptable code patterns from genuine issues, enabling the model to generalize the distinction  
C) Add a whitelist of acceptable patterns  
D) Lower the sensitivity  

**Correct Answer: B**  
Few-shot examples that distinguish acceptable patterns from genuine issues help the model generalize. Rather than maintaining a whitelist (which can't cover novel patterns), examples teach the model the reasoning behind the distinction.

---

**Q205.** What is a key advantage of few-shot examples over detailed instructions for improving output quality?

A) They use fewer tokens  
B) They enable the model to generalize judgment to novel patterns rather than only matching pre-specified cases  
C) They're easier to write  
D) They work with any model  

**Correct Answer: B**  
Few-shot examples enable the model to generalize judgment to novel patterns. Detailed instructions can only cover pre-specified cases, while examples teach the model the reasoning pattern that applies to new situations.

---

**Q206.** Your agent needs to select between `search_orders` and `search_products` for ambiguous queries like "find XYZ-1234." Adding tool descriptions helped but some edge cases remain. What should you add?

A) More tool parameters  
B) Few-shot examples for ambiguous scenarios showing reasoning for why one tool was chosen over the other  
C) A pre-classification step  
D) A combined search tool  

**Correct Answer: B**  
Few-shot examples for ambiguous scenarios demonstrate the reasoning for tool selection. They show the model how to handle edge cases by reasoning about identifiers, context clues, and tool capabilities.

---

**Q207.** Your extraction pipeline hallucinates values for fields not present in the source document. What few-shot technique would help?

A) Add more required fields  
B) Include few-shot examples showing correct handling of missing data — returning null/empty instead of fabricating values  
C) Use stricter schemas  
D) Add a "no hallucination" instruction  

**Correct Answer: B**  
Few-shot examples showing correct handling of missing data (returning null instead of fabricating) are effective for reducing hallucination in extraction tasks. The examples demonstrate the expected behavior for absent data.

---

### Task Statement 4.3: Structured Output via Tool Use

**Q208.** You need guaranteed schema-compliant structured output. Which approach is most reliable?

A) Ask the model to "output JSON in this format"  
B) Tool use (`tool_use`) with JSON schemas — this eliminates JSON syntax errors  
C) Regular expression validation on the output  
D) Template-based output generation  

**Correct Answer: B**  
Tool use with JSON schemas is the most reliable approach for guaranteed schema-compliant structured output. It eliminates JSON syntax errors entirely, unlike prompt-based JSON requests.

---

**Q209.** You use `tool_use` with a strict JSON schema and no syntax errors occur. However, a field `total` doesn't match the sum of line items. What type of error is this?

A) A schema validation error  
B) A semantic error — strict JSON schemas eliminate syntax errors but do not prevent semantic errors like values that don't sum correctly  
C) A tool configuration error  
D) A model error  

**Correct Answer: B**  
Strict JSON schemas via tool use eliminate syntax errors but do not prevent semantic errors. Values in wrong fields, totals that don't match sums, or logically inconsistent data are semantic issues that require additional validation.

---

**Q210.** You have multiple extraction schemas (invoice, receipt, contract) and don't know the document type in advance. What `tool_choice` setting should you use?

A) `tool_choice: "auto"` — the model can decide  
B) `tool_choice: "any"` — guarantees the model calls a tool (extraction schema) rather than returning text, while letting it choose the appropriate schema  
C) Force a specific schema  
D) Create a document classifier first  

**Correct Answer: B**  
`tool_choice: "any"` guarantees structured output when multiple extraction schemas exist and the document type is unknown. The model must call a tool but can choose which schema to use. `"auto"` might return text instead.

---

**Q211.** Your schema has a `category` field with values "positive", "negative", "neutral". Some documents contain ambiguous sentiment. What schema design addresses this?

A) Add a "mixed" value  
B) Add an "unclear" enum value for ambiguous cases, plus an "other" value with a detail string field for extensible categorization  
C) Make the field optional  
D) Use free-text instead of enum  

**Correct Answer: B**  
The exam guide recommends adding enum values like "unclear" for ambiguous cases and "other" + detail fields for extensible categorization. This prevents the model from forcing an inaccurate classification.

---

**Q212.** Source documents sometimes lack certain information (e.g., a contract without an expiration date). Your schema requires an `expiration_date` field. What happens?

A) The model returns a parsing error  
B) The model may fabricate an expiration date to satisfy the required field  
C) The field is automatically null  
D) The extraction fails  

**Correct Answer: B**  
When source documents lack information but the schema requires a field, the model may fabricate values to satisfy the requirement. The solution is designing fields as optional (nullable) when information may not exist.

---

**Q213.** How should you design schema fields for information that may not exist in every source document?

A) Make all fields required with default values  
B) Make those fields optional (nullable), preventing the model from fabricating values to satisfy required fields  
C) Use placeholder values  
D) Remove the field entirely  

**Correct Answer: B**  
The exam guide specifically recommends designing schema fields as optional (nullable) when source documents may not contain the information. This prevents hallucination to satisfy required fields.

---

**Q214.** You receive inconsistently formatted dates from source documents (MM/DD/YYYY, DD-MM-YYYY, "March 2024"). How should you handle this?

A) Accept all formats  
B) Include format normalization rules in prompts alongside strict output schemas to handle inconsistent source formatting  
C) Reject non-standard formats  
D) Use regex to parse dates  

**Correct Answer: B**  
Including format normalization rules in prompts alongside strict output schemas handles inconsistent source formatting. The prompt instructs the model on how to normalize, while the schema enforces the output format.

---

**Q215.** What is the difference between `tool_choice: "auto"`, `"any"`, and forced selection?

A) They all produce the same result  
B) `"auto"`: model may return text; `"any"`: model must call a tool but chooses which; forced: model must call a specific named tool  
C) They differ only in speed  
D) `"auto"` is for testing; `"any"` and forced are for production  

**Correct Answer: B**  
`"auto"` allows text or tool calls. `"any"` guarantees a tool call but lets the model choose. Forced selection (`{"type": "tool", "name": "..."}`) requires a specific tool. Each serves different use cases.

---

### Task Statement 4.4: Validation, Retry, and Feedback Loops

**Q216.** Your extraction fails validation: the `total` field is $150 but line items sum to $175. You retry with just "please fix the errors." The retry produces the same wrong total. What should you do differently?

A) Retry more times  
B) Append the specific validation error to the prompt on retry: "Total is $150 but sum of line items is $175. Please re-extract the total from the source document."  
C) Accept the discrepancy  
D) Use a different model  

**Correct Answer: B**  
Retry-with-error-feedback means appending specific validation errors to the prompt on retry to guide the model toward correction. Generic "fix it" instructions don't provide enough guidance. Specific errors help the model identify and correct the issue.

---

**Q217.** Your extraction pipeline retries failed extractions 3 times, but a certain field always fails because the information simply isn't in the source document. What should you conclude?

A) Retry more times  
B) Retries are ineffective when the required information is absent from the source document — the field should be nullable or the document should be flagged for manual review  
C) Use a different extraction approach  
D) Add the information to the document  

**Correct Answer: B**  
Retries are ineffective when information is simply absent from the source (vs. format or structural errors). The exam guide distinguishes between retryable errors (format mismatches, structural issues) and non-retryable ones (missing information).

---

**Q218.** Your code review system adds a `detected_pattern` field to each finding. Why is this useful?

A) For categorization  
B) It enables systematic analysis of dismissal patterns — tracking which code constructs trigger findings helps identify and fix false positive patterns  
C) For deduplication  
D) For severity classification  

**Correct Answer: B**  
The `detected_pattern` field enables analysis of false positive patterns. When developers dismiss findings, you can analyze which patterns triggered those findings and refine the detection criteria to reduce false positives.

---

**Q219.** An extraction produces inconsistent values: `stated_total` is $1,200 but `calculated_total` (sum of items) is $1,150. How should this be handled?

A) Use the stated total  
B) Design self-correction validation: extract both `calculated_total` and `stated_total`, add a `conflict_detected` boolean, and flag discrepancies  
C) Average the two values  
D) Use the calculated total  

**Correct Answer: B**  
The exam guide describes designing self-correction validation flows. Extracting both values (stated vs calculated), adding `conflict_detected` booleans, and flagging discrepancies allows downstream systems to handle conflicts appropriately.

---

**Q220.** When should you retry a failed extraction versus flagging it for manual review?

A) Always retry first  
B) Retry when the error is a format mismatch or structural issue; flag for manual review when the information is absent from the source document or contradictory  
C) Never retry, always review manually  
D) Retry based on error count  

**Correct Answer: B**  
Retry when errors are resolvable (format mismatches, structural output errors). Flag for manual review when information is absent or contradictory — retrying won't produce correct results in these cases.

---

**Q221.** Your follow-up retry request includes only the validation error message. The retry still fails. What additional context should you include?

A) Just the error message is sufficient  
B) Include the original document, the failed extraction, and the specific validation error for model self-correction  
C) Include only the original document  
D) Include only the failed extraction  

**Correct Answer: B**  
Follow-up requests should include the original document, the failed extraction, AND specific validation errors. All three are needed for the model to understand what went wrong and produce a corrected extraction.

---

### Task Statement 4.5: Batch Processing

**Q222.** What cost savings does the Message Batches API provide?

A) 25% savings  
B) 50% cost savings with processing times up to 24 hours  
C) 75% savings  
D) No cost savings, only throughput benefits  

**Correct Answer: B**  
The Message Batches API provides 50% cost savings with a processing window of up to 24 hours and no guaranteed latency SLA.

---

**Q223.** Your team proposes using the Message Batches API for a pre-merge check that blocks developer merges. Is this appropriate?

A) Yes, the 50% savings justify it  
B) No — batch processing is inappropriate for blocking workflows because it has no guaranteed latency SLA (up to 24 hours). Pre-merge checks need real-time API calls  
C) Yes, if you add a timeout fallback  
D) Only during off-peak hours  

**Correct Answer: B**  
Batch processing is inappropriate for blocking workflows like pre-merge checks. The up to 24-hour processing window with no latency SLA makes it unsuitable for workflows where developers wait for results.

---

**Q224.** Which workloads are appropriate for the Message Batches API?

A) Pre-merge checks and interactive reviews  
B) Non-blocking, latency-tolerant workloads: overnight reports, weekly audits, nightly test generation  
C) Real-time customer support  
D) Interactive code reviews  

**Correct Answer: B**  
Batch processing is appropriate for non-blocking, latency-tolerant workloads like overnight reports, weekly audits, and nightly test generation. These don't require real-time results and benefit from the 50% cost savings.

---

**Q225.** Some documents in your batch of 100 fail processing. How should you identify and resubmit them?

A) Resubmit the entire batch  
B) Use `custom_id` fields to identify failed documents and resubmit only those with appropriate modifications (e.g., chunking documents that exceeded context limits)  
C) Ignore failed documents  
D) Process failed documents manually  

**Correct Answer: B**  
`custom_id` fields correlate batch request/response pairs. Failed documents are identified by their `custom_id` and can be resubmitted individually with modifications (like chunking oversized documents).

---

**Q226.** You need a 30-hour SLA for document processing using the Message Batches API. The batch API takes up to 24 hours. How often should you submit batches?

A) Once every 24 hours  
B) Every 4-6 hours to guarantee the 30-hour SLA even with 24-hour batch processing time  
C) Once a week  
D) Continuously  

**Correct Answer: B**  
The exam guide describes calculating batch submission frequency based on SLA constraints. With a 24-hour processing window and a 30-hour SLA, submitting every 4-6 hours ensures that even with maximum processing time, the SLA is met.

---

**Q227.** Before batch-processing 10,000 documents, what should you do to maximize first-pass success rates?

A) Process all 10,000 immediately  
B) Use prompt refinement on a sample set before batch-processing the full volume to maximize first-pass success and reduce resubmission costs  
C) Process 1,000 at a time  
D) Validate schemas only  

**Correct Answer: B**  
The exam guide recommends prompt refinement on a sample set before batch-processing large volumes. This maximizes first-pass success rates and reduces iterative resubmission costs.

---

**Q228.** Can the Message Batches API execute tools mid-request and return results within the same batch request?

A) Yes, it supports full tool calling  
B) No — the batch API does not support multi-turn tool calling within a single request  
C) Yes, but only for built-in tools  
D) Yes, with additional configuration  

**Correct Answer: B**  
The batch API does not support multi-turn tool calling within a single request. It cannot execute tools mid-request and return results. Workflows requiring tool execution need the synchronous API.

---

### Task Statement 4.6: Multi-Pass Review Architectures

**Q229.** A model generates code and then reviews it in the same session. The review finds no issues. Is this reliable?

A) Yes, self-review is effective  
B) No — a model retains reasoning context from generation, making it less likely to question its own decisions in the same session  
C) Yes, if the review prompt is detailed  
D) It depends on the code complexity  

**Correct Answer: B**  
Self-review is limited because the model retains reasoning context from generation. It's less likely to question decisions it just made. An independent review instance without prior reasoning is more effective.

---

**Q230.** How can you get more effective code review from Claude?

A) Use the same session with a stronger review prompt  
B) Use a second independent Claude instance without the generator's reasoning context  
C) Add "review critically" to the prompt  
D) Use extended thinking  

**Correct Answer: B**  
Using a second independent instance ensures the reviewer doesn't retain the generator's reasoning context. This independence makes it more effective at catching subtle issues and questioning design decisions.

---

**Q231.** A single-pass review of a 14-file PR produces contradictory findings — flagging a pattern as problematic in one file while approving identical code elsewhere. What should you do?

A) Accept the inconsistency  
B) Split into per-file local analysis passes plus a separate cross-file integration pass to avoid attention dilution  
C) Review fewer files at a time  
D) Use a larger context window  

**Correct Answer: B**  
Splitting reviews into focused passes addresses attention dilution. Per-file analysis ensures consistent depth, while a cross-file integration pass catches data flow and consistency issues.

---

**Q232.** What is "attention dilution" in the context of code reviews?

A) When the reviewer is distracted  
B) When processing many files simultaneously, the model gives detailed feedback to some files but superficial or contradictory feedback to others  
C) When the context window is too small  
D) When the prompt is too vague  

**Correct Answer: B**  
Attention dilution occurs when processing many files simultaneously — the model provides detailed feedback for some files but superficial comments, missed bugs, or contradictory feedback for others. This is why splitting reviews into focused passes is important.

---

**Q233.** Running verification passes where the model self-reports confidence alongside each finding serves what purpose?

A) It replaces human review  
B) It enables calibrated review routing — high-confidence findings can be auto-processed while low-confidence findings get human attention  
C) It's purely for documentation  
D) It improves accuracy  

**Correct Answer: B**  
Self-reported confidence alongside findings enables calibrated review routing. This helps prioritize limited reviewer capacity by directing attention to findings where the model is less certain.

---

### Additional Prompt Engineering Questions

**Q234.** Your extraction tool has these schema options for a `status` field: `["active", "inactive", "pending"]`. A document describes a status as "on hold." What happens?

A) The extraction fails  
B) The model may force-fit "on hold" into one of the existing values, potentially misclassifying it  
C) The model returns null  
D) The model adds "on hold" to the enum  

**Correct Answer: B**  
Without an "other" option, the model must fit every status into the predefined values, potentially misclassifying unusual statuses. Adding an "other" + detail string pattern allows extensible categorization.

---

**Q235.** When should you use `tool_choice: "auto"` versus `tool_choice: "any"` for extraction tasks?

A) They're interchangeable  
B) Use `"any"` when you need guaranteed structured extraction (no text responses). Use `"auto"` when the model should decide whether extraction is appropriate (e.g., some inputs may not be extractable documents)  
C) `"auto"` is faster  
D) `"any"` is more accurate  

**Correct Answer: B**  
`"any"` guarantees tool usage (structured output). `"auto"` allows the model to decide — useful when some inputs might not be extractable. The choice depends on whether you always want extraction or want the model to determine applicability.

---

**Q236.** You've designed an extraction schema with all required fields. Testing reveals the model fabricates data for fields not present in every document. What is the fix?

A) Add validation rules  
B) Make fields that may not exist in every document optional (nullable), preventing fabrication  
C) Add more training examples  
D) Use a different extraction approach  

**Correct Answer: B**  
Making fields optional (nullable) when information may not exist in every document prevents the model from fabricating values to satisfy required fields. This is a core schema design principle.

---

**Q237.** Your batch processing job processes 1,000 documents overnight. 50 fail with "context limit exceeded." How should you handle the failures?

A) Increase the context limit  
B) Identify failed documents by `custom_id` and resubmit with modifications — chunk the documents that exceeded context limits  
C) Process them manually  
D) Skip the failed documents  

**Correct Answer: B**  
Failed documents are identified by `custom_id`. The recommended approach is resubmitting only failed documents with appropriate modifications (chunking oversized documents, simplifying prompts) rather than reprocessing the entire batch.

---

**Q238.** Your code review prompt produces findings in varying formats. Adding "use this format: [location, issue, severity, fix]" helps but isn't consistent. What would improve consistency further?

A) Repeat the format instruction multiple times  
B) Provide 2-3 few-shot examples showing the exact desired format with realistic code issues  
C) Post-process with regex  
D) Use a template engine  

**Correct Answer: B**  
Few-shot examples demonstrating the exact desired format are more effective than format instructions alone. Examples show the model the expected pattern concretely, leading to consistent output.

---

**Q239.** An extraction pipeline produces accurate results for 95% of documents but completely fails on medical documents with specialized terminology. What approach addresses this?

A) Use a specialized medical model  
B) Add few-shot examples from medical documents showing correct extraction of specialized terminology and document structures  
C) Create a separate pipeline  
D) Pre-process medical documents  

**Correct Answer: B**  
Few-shot examples from the problematic document type (medical documents) demonstrate correct handling of specialized terminology and structures. This helps the model generalize to medical document patterns.

---

**Q240.** Your review system produces a finding with `detected_pattern: "nested_callback"`. Developers dismiss this finding 80% of the time because nested callbacks are an accepted pattern in the codebase. How should you use this data?

A) Ignore the dismissal rate  
B) Analyze the `detected_pattern` dismissal rate to identify false positive patterns, then either exclude "nested_callback" from findings or refine the detection criteria to distinguish problematic from acceptable uses  
C) Remove all callback-related checks  
D) Force developers to accept all findings  

**Correct Answer: B**  
The `detected_pattern` field enables systematic analysis of dismissal patterns. An 80% dismissal rate indicates a false positive pattern that should be either excluded or refined with better criteria that distinguishes problematic from acceptable nested callbacks.

---

**Q241.** What is the benefit of extracting both `stated_total` and `calculated_total` in a financial document extraction?

A) Redundancy  
B) Self-correction validation — comparing stated versus calculated totals flags discrepancies and inconsistencies in the source data  
C) It's required by the schema  
D) Better accuracy  

**Correct Answer: B**  
Extracting both enables self-correction validation. If the stated total doesn't match the calculated total, a `conflict_detected` flag alerts downstream systems to inconsistencies that need resolution.

---

**Q242.** You need to extract metadata from documents before running enrichment. What `tool_choice` configuration ensures metadata extraction happens first?

A) `tool_choice: "auto"` with instructions  
B) `tool_choice: {"type": "tool", "name": "extract_metadata"}` on the first request, then `"auto"` for subsequent requests  
C) `tool_choice: "any"`  
D) Include extraction in the enrichment tool  

**Correct Answer: B**  
Forced tool selection ensures `extract_metadata` runs first. After metadata is extracted, subsequent requests use `"auto"` to let the model choose enrichment tools freely.

---

**Q243.** Your schema uses an enum for `document_type` with values `["invoice", "receipt", "contract"]`. A new document type appears: "purchase order." What schema pattern handles this gracefully?

A) Add "purchase_order" to the enum  
B) Include an "other" enum value with a companion `document_type_detail` string field for extensible categorization  
C) Use a free-text field  
D) Reject unknown document types  

**Correct Answer: B**  
The "other" + detail string pattern allows extensible categorization. Unknown types are classified as "other" with the specific type in the detail field, without requiring schema changes for every new document type.

---

**Q244.** When designing a prompt for code review, which approach produces more actionable findings?

A) "Review this code for issues"  
B) "Report issues in these categories: (1) bugs: logic errors that would cause incorrect behavior; (2) security: SQL injection, XSS, authentication bypasses. Skip: style preferences, naming conventions, comment formatting."  
C) "Find all problems in the code"  
D) "Be thorough and detailed"  

**Correct Answer: B**  
Specific review criteria defining what to report (bugs, security) and what to skip (style, naming) produce more actionable findings than general instructions. This is the explicit criteria approach from the exam guide.

---

**Q245.** You process documents in two formats: narrative reports and structured tables. The extraction pipeline handles reports well but fails on tables. What technique would you use?

A) Pre-process tables into narrative format  
B) Add few-shot examples showing correct extraction from both narrative reports and structured tables to handle the structural variety  
C) Create a separate pipeline for tables  
D) Convert all documents to one format  

**Correct Answer: B**  
Few-shot examples demonstrating correct extraction from varied document structures help the model handle both formats. Examples teach the model how different structures map to the same output schema.

---

**Q246.** Your batch job submits 500 documents. After 24 hours, you have results for 480. The remaining 20 failed. What information helps you handle the failures efficiently?

A) The batch submission time  
B) The `custom_id` fields that identify which specific documents failed, along with failure reasons  
C) The total token count  
D) The average processing time  

**Correct Answer: B**  
`custom_id` fields identify which specific documents failed. Combined with failure reasons, you can resubmit only the 20 failed documents with targeted modifications rather than reprocessing all 500.

---

**Q247.** An engineer suggests running the code generator and code reviewer in the same Claude session "for efficiency." What is the architectural concern?

A) API cost  
B) Self-review limitation: the reviewer retains the generator's reasoning context, making it less effective at finding issues  
C) Token limit  
D) Session timeout  

**Correct Answer: B**  
The self-review limitation means the model retains its reasoning context from generation, making it less likely to question its own decisions. Independent instances provide better review quality.

---

**Q248.** Your validation finds that a `phone_number` field is in format "(555) 123-4567" but your downstream system requires "+15551234567". How should you handle this in the extraction pipeline?

A) Add a post-processing step  
B) Include format normalization rules in prompts alongside the strict output schema  
C) Reject non-standard formats  
D) Store both formats  

**Correct Answer: B**  
Including format normalization rules in prompts alongside strict output schemas handles inconsistent source formatting. The prompt instructs the model to normalize during extraction, and the schema enforces the output format.

---

**Q249.** What makes retries effective for extraction errors?

A) Retries always improve results  
B) Retries are effective for format mismatches and structural output errors, but not for absent information  
C) More retries always lead to better results  
D) Retries work by giving the model another chance  

**Correct Answer: B**  
Retries are effective for resolvable errors (format mismatches, structural issues) but not when information is absent from the source. Understanding this distinction prevents wasted retry attempts.

---

**Q250.** Your PR review covers 14 files. Some files get detailed 10-line feedback while others get a single generic comment. What pattern explains this?

A) The model ran out of tokens  
B) Attention dilution — when analyzing many files simultaneously, the model gives disproportionate attention to some files while treating others superficially  
C) Some files have fewer issues  
D) The model prioritizes larger files  

**Correct Answer: B**  
Attention dilution in single-pass multi-file reviews causes inconsistent depth. The solution is splitting into per-file passes for consistent analysis plus a cross-file integration pass.

---

**Q251.** You want to ensure consistent severity classification. Which approach is most effective?

A) Define "High", "Medium", "Low" with text descriptions  
B) Define severity levels with concrete code examples for each level, showing what a "High" severity issue looks like versus "Medium" and "Low"  
C) Let the model decide severity  
D) Use a separate classification model  

**Correct Answer: B**  
Concrete code examples for each severity level achieve more consistent classification than text descriptions alone. Examples demonstrate the expected calibration point.

---

**Q252.** Your extraction schema has a `confidence` field. After testing, you find the model always outputs `"high"`. How can you improve confidence calibration?

A) Add more confidence levels  
B) Use labeled validation sets to calibrate confidence thresholds, then use few-shot examples showing when confidence should be "low" or "medium"  
C) Remove the confidence field  
D) Use a separate model for confidence scoring  

**Correct Answer: B**  
Field-level confidence scores should be calibrated using labeled validation sets. Few-shot examples showing appropriate confidence levels for different scenarios help the model produce better-calibrated scores.

---

**Q253.** When is it appropriate to provide all issues in a single message versus addressing them sequentially?

A) Always one message for efficiency  
B) Use a single message when fixes interact with each other; use sequential iteration for independent problems  
C) Always sequential for clarity  
D) It depends on the number of issues  

**Correct Answer: B**  
Interacting problems should be addressed in a single message because their fixes affect each other. Independent problems should be addressed sequentially so each fix is clear and focused.

---

**Q254.** Your review generates a finding: "Potential SQL injection in line 42." The developer dismisses it as a false positive. What data should the review system capture?

A) Just the dismissal  
B) The finding details plus `detected_pattern` field to enable systematic analysis of which patterns trigger false positives  
C) The developer's reason for dismissal  
D) The code context  

**Correct Answer: B**  
The `detected_pattern` field enables systematic analysis of dismissal patterns. Over time, patterns with high dismissal rates can be identified and either excluded or refined with better detection criteria.

---

**Q255.** Your prompt includes detailed instructions for format normalization but the model inconsistently applies them. What is the most effective improvement?

A) Repeat the instructions  
B) Add 2-3 concrete input/output examples showing the exact normalization expected  
C) Use a separate normalization step  
D) Make the instructions shorter  

**Correct Answer: B**  
Concrete input/output examples are the most effective way to communicate expected transformations when prose descriptions produce inconsistent results. This is a core principle of iterative refinement.

---
