# 📘 CCAF Training Guide — Part 3

## Domain 4: Prompt Engineering & Structured Output (20%) + Domain 5: Context Management & Reliability (15%)

---

# Chapter 5: Domain 4 — Prompt Engineering & Structured Output

## 5.1 Explicit Criteria vs. Vague Instructions

This is one of the **most heavily tested concepts** on the exam. The difference between vague and explicit instructions determines whether your system works reliably.

### The Core Problem

```
❌ VAGUE INSTRUCTIONS (don't work reliably):

  "Be conservative and only report high-confidence findings"
  "Check that comments are accurate"
  "Focus on important issues"
  "Be thorough but precise"

  Why they fail:
  → "Conservative" means different things in different runs
  → "High-confidence" is subjectively interpreted
  → "Important" is undefined
  → Results vary wildly between runs
```

```
✅ EXPLICIT CRITERIA (work reliably):

  "Flag comments ONLY when the described behavior directly
   contradicts the actual code logic. Skip:
   - Stylistic brevity
   - Naming preferences
   - Documentation length
   - Local conventions"

  Why this works:
  → Clear rule: "contradicts actual code logic"
  → Explicit exclusions: style, naming, length
  → Binary decision: contradicts or doesn't
  → Consistent across runs
```

### Severity Classification Example

```
❌ "Rate severity as High, Medium, or Low"
   → Same bug rated "High" one run, "Medium" the next

✅ Explicit rubric with examples:

   CRITICAL: Crashes, data loss, security vulnerabilities
     Example: Unhandled promise rejection in payment processing
   
   HIGH: Incorrect behavior that affects users
     Example: Refund calculation that doesn't include tax
   
   MEDIUM: Edge cases that produce wrong results
     Example: Date parsing fails for single-digit months
   
   LOW: Code quality issues without functional impact
     Example: Unused variable, inconsistent indentation
```

### Reducing False Positives

```
Problem: Code review flags too many false positives
  → Developers ignore ALL findings (including real bugs)
  → Trust in the system collapses

Solution:
  1. Define explicit criteria (what to report vs. skip)
  2. Temporarily disable high false-positive categories
  3. Improve prompts for disabled categories
  4. Re-enable when false positive rate is acceptable

Key metric: Track dismissal rates by detected_pattern
  → Patterns with 80%+ dismissal rate need refinement
```

---

## 5.2 Few-Shot Prompting

Few-shot examples are **more effective than detailed instructions** for achieving consistency.

### Why Examples Beat Instructions

```
Instructions only:
  "Extract dates in ISO 8601 format, normalize names to 
   uppercase, and handle missing fields gracefully"
  
  Run 1: {"name": "JOHN DOE", "date": "2024-03-15"}          ← correct
  Run 2: {"name": "John Doe", "date": "March 15, 2024"}      ← wrong!
  Run 3: {"name": "JOHN DOE", "date": "2024-3-15"}           ← partially wrong

Instructions + Examples:
  "Extract data per these examples:
   
   Input:  'john doe, born 3/15/1990'
   Output: {"name": "JOHN DOE", "date": "1990-03-15"}
   
   Input:  'jane smith, DOB: March 2, 1985'
   Output: {"name": "JANE SMITH", "date": "1985-03-02"}
   
   Input:  'bob jones, no date available'
   Output: {"name": "BOB JONES", "date": null}"
  
  All runs: consistent ✓
```

### How Many Examples?

```
Recommended: 2-4 targeted examples

❌ 1 example:  May not show enough variation
❌ 10 examples: Wastes tokens, may confuse with conflicting patterns
✅ 2-4 examples: Shows the pattern clearly, covers key variations

Each example should demonstrate:
  • The core pattern (what to do)
  • An edge case (what happens with unusual input)
  • A boundary case (when NOT to apply the pattern)
```

### What Few-Shot Examples Should Show

```
For tool selection ambiguity:
  Example 1: "Find order XYZ-1234" → use lookup_order
    Reasoning: "XYZ-1234 matches order ID format"
  
  Example 2: "Search for blue widgets" → use search_products
    Reasoning: "'blue widgets' is a product description, not an order ID"

For document extraction variety:
  Example 1: Invoice with inline line items → extract from body text
  Example 2: Invoice with summary table → extract from table structure
  Example 3: Invoice missing PO number → return null for missing fields

For review precision:
  Example 1: Comment says "validates email" but code validates phone → FLAG
  Example 2: Comment says "validates input" for a function that validates → SKIP
    (terse but accurate)
```

### Key Advantage

> Few-shot examples enable the model to **generalize judgment to novel patterns** rather than only matching pre-specified cases. A whitelist of acceptable patterns can't cover new patterns; examples teach the reasoning behind the distinction.

---

## 5.3 Structured Output via Tool Use

### The Three Approaches (Reliability Ranking)

```
Most Reliable ──────────────────────── Least Reliable

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  tool_use with   │  │  --json-schema   │  │ "Output JSON"    │
│  JSON schema     │  │  CLI flag        │  │  in prompt       │
│                  │  │                  │  │                  │
│ • 0% syntax err  │  │ • ~0% syntax err │  │ • ~6% syntax err │
│ • Schema enforced│  │ • Schema enforced│  │ • No guarantee   │
│ • API-level      │  │ • CLI-level      │  │ • Prompt-level   │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

### Using Tool Use for Guaranteed Structured Output

```json
// Define a tool with a JSON schema
{
  "name": "extract_invoice",
  "description": "Extracts structured data from an invoice document",
  "input_schema": {
    "type": "object",
    "properties": {
      "vendor_name": {"type": "string"},
      "invoice_date": {"type": "string", "format": "date"},
      "total_amount": {"type": "number"},
      "line_items": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "description": {"type": "string"},
            "quantity": {"type": "integer"},
            "unit_price": {"type": "number"}
          }
        }
      },
      "purchase_order_number": {
        "type": ["string", "null"]   // ← NULLABLE! Prevents hallucination
      }
    },
    "required": ["vendor_name", "invoice_date", "total_amount", "line_items"]
  }
}
```

### Syntax Errors vs. Semantic Errors

```
Tool use with JSON schema eliminates:
  ✅ Trailing commas
  ✅ Missing quotes
  ✅ Surrounding prose ("Here is the JSON: {...}")
  ✅ Invalid field names

Tool use does NOT prevent:
  ❌ Values in wrong fields (date in name field)
  ❌ Totals that don't sum correctly
  ❌ Fabricated values for missing data
  ❌ Logically inconsistent data

→ You still need VALIDATION for semantic correctness
```

### Nullable Fields — Preventing Hallucination

```
❌ Required field for data that may not exist:
   "purchase_order_number": {"type": "string"}  // REQUIRED
   
   Document has no PO number → Model invents "PO-2024-00001" 💀

✅ Nullable field:
   "purchase_order_number": {"type": ["string", "null"]}
   
   Document has no PO number → Model returns null ✓
```

### Extensible Enums with "Other" + Detail

```
❌ Rigid enum (breaks on new types):
   "document_type": {"enum": ["invoice", "receipt", "contract"]}
   New type "warranty claim" → forced into "invoice" 💀

✅ Extensible enum:
   "document_type": {
     "enum": ["invoice", "receipt", "contract", "other"]
   },
   "document_type_detail": {
     "type": ["string", "null"],
     "description": "When document_type is 'other', describe the type"
   }
   
   New type → {"document_type": "other", "document_type_detail": "warranty claim"} ✓
```

---

## 5.4 Validation, Retry, and Feedback Loops

### Retry-with-Error-Feedback

```
Step 1: Extract data from document
  → Result: {"total": 150, "line_items": [{"amount": 100}, {"amount": 75}]}

Step 2: Validate
  → ERROR: total (150) ≠ sum of line items (175)

Step 3: Retry WITH specific error context
  ❌ "Please fix the errors"  → Model doesn't know WHAT to fix
  ✅ "Total is $150 but sum of line items is $175. 
      Please re-extract the total from the source document."

Step 4: Model corrects → {"total": 175, ...} ✓
```

### When Retries Work vs. When They Don't

```
Retries ARE effective for:
  ✅ Format mismatches (date in wrong format)
  ✅ Structural errors (value in wrong field)
  ✅ Calculation errors (incorrect sum)

Retries are NOT effective for:
  ❌ Information that doesn't exist in the source document
  ❌ Contradictory source data
  → Flag for manual review instead
```

### Self-Correction Validation Design

```json
// Extract BOTH stated and calculated values
{
  "stated_total": 1200,          // What the document says
  "calculated_total": 1150,      // Sum of line items
  "conflict_detected": true,     // Flag the discrepancy
  "conflict_description": "Stated total ($1,200) differs from calculated ($1,150)"
}
```

### Tracking False Positives with `detected_pattern`

```json
{
  "finding": "Nested callback without error handling",
  "severity": "medium",
  "detected_pattern": "nested_callback",   // ← Track this!
  "file": "api/orders.js",
  "line": 42
}

// Over time, analyze:
//   nested_callback: 80% dismissal rate → refine or exclude
//   sql_injection:   2% dismissal rate → keep as-is
```

---

## 5.5 Batch Processing with Message Batches API

### Key Facts

```
┌─────────────────────────────────────────────────────┐
│  MESSAGE BATCHES API                                │
├─────────────────────────────────────────────────────┤
│  Cost:     50% cheaper than synchronous API         │
│  Latency:  Up to 24 hours (no SLA guarantee)        │
│  Use for:  Non-blocking, latency-tolerant workloads │
│  NOT for:  Blocking workflows (pre-merge checks)    │
│  Limits:   No multi-turn tool calling per request   │
│  Tracking: Use custom_id to identify each document  │
└─────────────────────────────────────────────────────┘
```

### When to Use Batch vs. Synchronous

```
                    ┌──────────────────────┐
                    │ Does the user/system │
                    │ wait for the result? │
                    └──────────┬───────────┘
                               │
              ┌────────────────┴────────────────┐
              │ YES                             │ NO
              ▼                                 ▼
     ┌────────────────┐               ┌────────────────┐
     │ SYNCHRONOUS    │               │ BATCH API      │
     │ API            │               │ (50% cheaper)  │
     │                │               │                │
     │ • Pre-merge    │               │ • Overnight    │
     │   checks       │               │   reports      │
     │ • Interactive  │               │ • Weekly       │
     │   reviews      │               │   audits       │
     │ • Customer     │               │ • Nightly test │
     │   support      │               │   generation   │
     └────────────────┘               └────────────────┘
```

### Batch Workflow

```
1. Prompt refinement on SAMPLE SET first
   → Maximize first-pass success rate
   → Don't waste money on 10,000 documents with a bad prompt

2. Submit batch with custom_id for each document
   → {"custom_id": "doc-0042", "messages": [...]}

3. Receive results (up to 24 hours)
   → Most succeed
   → Some fail (context limit, parsing errors)

4. Identify failures by custom_id
   → Resubmit ONLY failed documents
   → Modify as needed (chunk oversized ones)
```

### SLA Planning

```
Requirement: 30-hour SLA for document processing
Batch processing: up to 24 hours

→ Submit every 4-6 hours
→ Even worst case (24-hour processing), SLA is met
→ Documents wait maximum 6 hours + 24 hours = 30 hours ✓
```

---

## 5.6 Multi-Pass Review Architectures

### Self-Review Is Unreliable

```
┌─────────────────────────────────────────────────────┐
│ SELF-REVIEW LIMITATION                              │
│                                                     │
│ Same session generates code → reviews code          │
│                                                     │
│ Problem: Model retains reasoning context from       │
│ generation. It's less likely to question             │
│ decisions it just made.                             │
│                                                     │
│ Like asking an author to proofread their own book   │
│ immediately after writing it — they "see" what they │
│ intended, not what they actually wrote.             │
└─────────────────────────────────────────────────────┘

Solution: Use an INDEPENDENT Claude instance for review
  → No prior reasoning context
  → Fresh perspective
  → More effective at catching issues
```

### Attention Dilution

```
Single-pass review of 14 files:

  File 1:  ████████████ detailed analysis ✓
  File 2:  █████████ good analysis ✓
  File 3:  ████████ decent ✓
  File 4:  ██████ getting shorter
  File 5:  ████ superficial
  ...
  File 14: █ "Looks fine" ← MISSED A BUG!

Problem: "Attention dilution" — model gives disproportionate
         attention to early files, treats later files superficially.
```

### Multi-Pass Solution

```
Pass 1: Per-file local analysis
  ┌─── auth.py ───────┐  Each file gets
  │ Full deep analysis │  equal, focused
  └────────────────────┘  attention
  ┌─── orders.py ─────┐
  │ Full deep analysis │
  └────────────────────┘
  ┌─── payments.py ────┐
  │ Full deep analysis │
  └────────────────────┘

Pass 2: Cross-file integration analysis
  ┌─────────────────────────────────────┐
  │ Data flow: auth → orders → payments │
  │ Consistency check across all files  │
  │ Missing error propagation detected  │
  └─────────────────────────────────────┘
```

---

# Chapter 6: Domain 5 — Context Management & Reliability

## 6.1 Context Preservation

### The Progressive Summarization Problem

```
Turn 1: Customer says "Order #12345 arrived damaged, product was $89.99,
        I want a full refund credited to my Visa ending in 4321"

Turn 5: Agent summary: "The customer had issues with their order"

                            ↑
               LOST: order #, price, card number, "full refund"
```

### Solution: Persistent "Case Facts" Block

```
Every prompt includes a structured facts block that persists
across the conversation, OUTSIDE the summarized history:

┌─ CASE FACTS (always present) ──────────────────────┐
│ Customer: Jane Smith (CUST-12345)                   │
│ Order: #12345                                       │
│ Item: Blue Widget ($89.99)                          │
│ Issue: Arrived damaged                              │
│ Status: Within 30-day return window                 │
│ Request: Full refund to Visa ****4321               │
│ Verified: Identity confirmed via email              │
└────────────────────────────────────────────────────┘

┌─ CONVERSATION SUMMARY ────────────────────────────┐
│ Customer reported damage, agent confirmed order    │
│ details and return eligibility...                  │
└────────────────────────────────────────────────────┘
```

### The "Lost in the Middle" Effect

```
In very long inputs, models process information at the
BEGINNING and END more reliably than the MIDDLE:

  ┌──────────────────────────────────────────────────┐
  │ BEGINNING: High attention ████████████████████   │
  │ MIDDLE:    Low attention  ████████               │
  │ END:       High attention ████████████████████   │
  └──────────────────────────────────────────────────┘

Mitigation:
  • Place key findings SUMMARIES at the beginning
  • Organize detailed results with explicit section headers
  • Don't bury critical information in the middle of long contexts
```

### Trimming Verbose Tool Outputs

```
lookup_order returns 40+ fields:
  order_id, status, created_date, updated_date, customer_id,
  shipping_carrier, package_dimensions_x, package_dimensions_y,
  package_dimensions_z, weight_kg, warehouse_location,
  picking_zone, batch_id, fulfillment_center, ...

For a return request, only 5 fields matter:
  order_id, status, item_name, price, return_eligible_until

→ Use PostToolUse hook to trim to relevant fields
→ Saves tokens, reduces noise, prevents context exhaustion
```

---

## 6.2 Escalation Patterns

### Reliable Escalation Triggers

```
┌─────────────────────────────────────────────────────────┐
│  ALWAYS ESCALATE:                                       │
│  ✅ Customer explicitly requests a human agent          │
│  ✅ Policy is ambiguous/silent on the customer's need   │
│  ✅ Agent cannot make meaningful progress               │
│  ✅ Policy exception required (outside normal rules)    │
│                                                         │
│  DO NOT USE AS ESCALATION TRIGGERS:                     │
│  ❌ Negative sentiment / frustration                    │
│  ❌ LLM self-reported confidence scores                 │
│  ❌ Long conversation length                            │
│  ❌ Number of tool calls                                │
└─────────────────────────────────────────────────────────┘
```

### Why Sentiment-Based Escalation Fails

```
Scenario 1: Customer is FURIOUS but issue is simple (return within policy)
  → Sentiment says: ESCALATE!
  → Reality: Agent can resolve in 1 step
  → Correct: Acknowledge frustration, resolve the issue

Scenario 2: Customer is calm but issue is complex (policy gap)
  → Sentiment says: Don't escalate
  → Reality: Agent can't resolve (no policy covers this)
  → Correct: Escalate despite calm tone
```

### Why Self-Reported Confidence Fails

```
❌ "On a scale of 1-10, how confident are you?"
   
   Model says 9/10 on a case it handles INCORRECTLY
   Model says 5/10 on a straightforward case
   
   → Self-reported confidence is poorly calibrated
   → Don't use it for escalation decisions
```

### Multiple Match Ambiguity

```
Agent calls get_customer("John Smith")
  → Returns 3 matching records

  ❌ Agent picks the one with most recent activity (heuristic)
     → Risk: Wrong customer selected!

  ✅ Agent asks for additional identifiers:
     "I found multiple accounts for John Smith. Can you provide
      your email address or account number to help me locate
      your specific account?"
```

---

## 6.3 Error Propagation in Multi-Agent Systems

### Local Recovery First

```
Subagent encounters timeout:

  Step 1: TRY LOCAL RECOVERY
    → Retry with exponential backoff
    → Try alternative data source
    → Use cached results if fresh enough

  Step 2: IF LOCAL RECOVERY FAILS → PROPAGATE TO COORDINATOR
    → Include: what failed, what was attempted, partial results
    → Include: potential alternatives
    → DO NOT: return empty results as success (anti-pattern!)
    → DO NOT: terminate entire workflow (anti-pattern!)
```

### Error Propagation Structure

```json
// ❌ BAD: Generic error
{"status": "error", "message": "search unavailable"}

// ✅ GOOD: Structured error context
{
  "status": "error",
  "failureType": "transient_timeout",
  "attemptedQuery": "AI market size 2024",
  "retryAttempts": 3,
  "partialResults": [
    {"source": "cached_data", "claim": "Market ~$150B", "freshness": "2 months old"}
  ],
  "alternatives": [
    "Try alternative search endpoint",
    "Use cached results (2 months old)",
    "Proceed without this data source"
  ]
}
```

### Anti-Patterns in Error Handling

```
❌ Anti-Pattern 1: Silent Suppression
   Error occurs → return empty results as success
   → Coordinator thinks query succeeded with no matches
   → NO recovery possible

❌ Anti-Pattern 2: Full Workflow Termination
   One subagent fails → kill entire pipeline
   → Other subagents had useful results
   → Partial findings are valuable

✅ Correct: Propagate structured errors → let coordinator decide
```

---

## 6.4 Large Codebase Exploration

### Context Degradation in Long Sessions

```
Turn 1-5:   "Class AuthManager in auth/manager.py handles..."  ← SPECIFIC
Turn 10-15: "The authentication system uses typical patterns..." ← VAGUE
Turn 20+:   "Based on common practices..."                      ← GENERIC
                                                                    ↑
                                                    Context degradation!
```

### Three Mitigation Techniques

```
┌─────────────────────────────────────────────────────────┐
│ 1. SCRATCHPAD FILES                                     │
│    Record key findings to a file                        │
│    Reference the file in subsequent questions           │
│    Findings persist across context boundaries           │
│                                                         │
│ 2. SUBAGENT DELEGATION                                  │
│    Spawn subagents for specific investigation questions  │
│    Each subagent gets fresh context                      │
│    Main agent stays clean for coordination              │
│                                                         │
│ 3. /compact COMMAND                                     │
│    Reduces context usage during extended sessions       │
│    Use when context fills with verbose discovery output │
└─────────────────────────────────────────────────────────┘
```

### Between-Phase Knowledge Transfer

```
Phase 1: Explore → Key findings documented in scratchpad

Phase 2: New subagent spawned with:
  "Here are key findings from the exploration phase:
   - Authentication: AuthManager in auth/manager.py (lines 45-120)
   - Database: SQLAlchemy models in models/ (12 tables)
   - API: FastAPI routes in api/ (23 endpoints)
   - Tests: pytest in tests/ (67% coverage)
   
   Now investigate: [specific question for Phase 2]"
```

### Crash Recovery

```
┌─────────────────────────────────────────────────────┐
│ CRASH RECOVERY ARCHITECTURE                         │
│                                                     │
│ Each agent exports state → structured manifest      │
│                                                     │
│ Agent 1: ✅ Complete → state saved                  │
│ Agent 2: ✅ Complete → state saved                  │
│ Agent 3: 💥 Crash at 80%                            │
│                                                     │
│ On resume:                                          │
│ Coordinator loads manifest                          │
│ → Agent 1: Skip (already complete)                  │
│ → Agent 2: Skip (already complete)                  │
│ → Agent 3: Resume from saved state                  │
└─────────────────────────────────────────────────────┘
```

---

## 6.5 Human Review Workflows

### Aggregate Accuracy Can Be Misleading

```
Overall accuracy: 97% ← Looks great!

But break it down:
  Invoices:   99% ← Excellent
  Receipts:   98% ← Great
  Contracts:  85% ← PROBLEM!
  
The 97% aggregate masks the 85% contract accuracy.
→ ALWAYS validate by document type AND field before automating
```

### Confidence Calibration

```
Step 1: Create labeled validation set
  → 200 documents with known correct extractions

Step 2: Run extraction with confidence scores
  → Model says "high confidence" on 150 documents
  → Model says "medium confidence" on 35 documents
  → Model says "low confidence" on 15 documents

Step 3: Check actual accuracy per confidence level
  → High confidence: 98% accurate ← reliable
  → Medium confidence: 82% accurate ← needs review
  → Low confidence: 60% accurate ← always review

Step 4: Set routing thresholds
  → High confidence: auto-process
  → Medium/Low: route to human review
```

### Stratified Random Sampling

```
Don't just sample randomly — stratify by:
  • Document type (invoices, contracts, receipts)
  • Field (dates, amounts, names)
  • Confidence level (high, medium, low)
  • Source (different vendors, formats)

This catches novel error patterns that random sampling misses.
```

---

## 6.6 Information Provenance

### The Attribution Problem

```
Subagent 1 finds: "AI market valued at $150B" (Source: Industry Report 2024)
Subagent 2 finds: "Market grew 20% YoY" (Source: Tech Analysis Quarterly)

Synthesis WITHOUT provenance:
  "The AI market is valued at $150B and grew 20% year-over-year."
  → Where did each claim come from? UNKNOWN.

Synthesis WITH provenance:
  "The AI market is valued at $150B (Industry Report 2024)
   and grew 20% year-over-year (Tech Analysis Quarterly, Q3 2024)."
  → Every claim has a source ✓
```

### Structured Claim-Source Mappings

```json
// What subagents should return:
{
  "findings": [
    {
      "claim": "AI market valued at $150B",
      "source_url": "https://example.com/report",
      "source_name": "Industry Report 2024",
      "publication_date": "2024-03-15",
      "excerpt": "The global AI market reached $150 billion...",
      "confidence": "high"
    }
  ]
}
```

### Handling Contradictions

```
Source A: Market size = $50B (2024 data)
Source B: Market size = $65B (2025 data)

❌ Pick one arbitrarily
❌ Average them ($57.5B)
❌ Omit the conflicting data

✅ Annotate the conflict with attribution:
   "Market size ranges from $50B (Source A, 2024 data)
    to $65B (Source B, 2025 data). The difference may
    reflect temporal changes or methodological differences."
```

### Temporal Context

```
❌ Without dates:
   "Revenue was $10M" vs "Revenue was $15M" → CONTRADICTION?

✅ With temporal context:
   "Revenue was $10M in 2023" vs "Revenue was $15M in 2024"
   → Not a contradiction — it's growth!

→ ALWAYS require publication/collection dates in structured outputs
```

### Rendering Different Content Types

```
❌ Everything as prose paragraphs:
   "Revenue was 10 million in Q1, 12 million in Q2, 15 million
    in Q3, and 18 million in Q4..."

✅ Content-appropriate formatting:
   Financial data → TABLE
   | Quarter | Revenue |
   |---------|---------|
   | Q1      | $10M    |
   | Q2      | $12M    |
   | Q3      | $15M    |
   | Q4      | $18M    |
   
   News → PROSE
   Technical findings → STRUCTURED LISTS
```

---

## 6.7 Domain 4 & 5 — Key Exam Tips

> [!CAUTION]
> ### Must-Know Items
> 
> **Domain 4:**
> 1. **Explicit criteria > vague instructions** ("flag contradictions" vs "be conservative")
> 2. **2-4 few-shot examples** for ambiguous scenarios
> 3. **`tool_use` eliminates JSON syntax errors** but not semantic errors
> 4. **Nullable fields prevent hallucination** for missing data
> 5. **"other" + detail pattern** for extensible enums
> 6. **Retry with specific error context** — not generic "fix it"
> 7. **Batch API: 50% savings, up to 24 hours, no multi-turn tool calling**
> 8. **Self-review is unreliable** — use independent instances
> 9. **Attention dilution** — split reviews into per-file + cross-file passes
> 10. **`detected_pattern`** enables systematic false positive analysis
> 
> **Domain 5:**
> 11. **Extract transactional facts** into persistent "case facts" blocks
> 12. **"Lost in the middle"** — place key info at beginning/end
> 13. **Trim tool outputs** to relevant fields
> 14. **Sentiment/confidence are unreliable** for escalation
> 15. **Honor explicit human requests immediately** — no pre-investigation
> 16. **Local error recovery first** → propagate only what can't be resolved
> 17. **Empty results as success = anti-pattern** (silent suppression)
> 18. **Scratchpad files** persist findings across context degradation
> 19. **Aggregate accuracy masks segment issues** — validate by type
> 20. **Claim-source mappings** must survive through synthesis

---
