# Claude Certified Architect – Foundations: Exam Question Bank

## Part 3: Domain 3 — Claude Code Configuration & Workflows (20% of Exam)

---

### Task Statement 3.1: CLAUDE.md Configuration Hierarchy

**Q136.** A new team member joins the project but doesn't receive the coding standards enforced by CLAUDE.md. Where are the instructions most likely located?

A) In the project-level `.claude/CLAUDE.md`  
B) In the user-level `~/.claude/CLAUDE.md` — which is not shared via version control and only applies to the original developer  
C) In the system prompt  
D) In `.mcp.json`  

**Correct Answer: B**  
Instructions in `~/.claude/CLAUDE.md` are user-level and apply only to that user. They are not shared with teammates via version control. For team-wide instructions, use project-level `.claude/CLAUDE.md` or root `CLAUDE.md`.

---

**Q137.** What is the correct CLAUDE.md configuration hierarchy from broadest to most specific?

A) Directory-level → Project-level → User-level  
B) User-level (`~/.claude/CLAUDE.md`) → Project-level (`.claude/CLAUDE.md` or root `CLAUDE.md`) → Directory-level (subdirectory `CLAUDE.md` files)  
C) Root → User → Environment  
D) Global → Regional → Local  

**Correct Answer: B**  
The hierarchy is: user-level (`~/.claude/CLAUDE.md`), project-level (`.claude/CLAUDE.md` or root `CLAUDE.md`), and directory-level (subdirectory `CLAUDE.md` files). Each level adds more specific context.

---

**Q138.** Your project has a large CLAUDE.md file (500+ lines) covering testing, API conventions, deployment, and coding standards. It's becoming difficult to maintain. What is the recommended approach?

A) Split it into sections with headers  
B) Split it into focused topic-specific files in `.claude/rules/` (e.g., `testing.md`, `api-conventions.md`, `deployment.md`)  
C) Move less important sections to comments  
D) Create separate CLAUDE.md files in each subdirectory  

**Correct Answer: B**  
The `.claude/rules/` directory allows organizing topic-specific rule files as an alternative to a monolithic CLAUDE.md. This improves maintainability with focused, purpose-specific files.

---

**Q139.** Your project uses the `@import` syntax in CLAUDE.md. What is this used for?

A) Importing npm packages  
B) Referencing external files to keep CLAUDE.md modular (e.g., importing specific standards files relevant to each package)  
C) Including API documentation  
D) Loading environment variables  

**Correct Answer: B**  
The `@import` syntax references external files to keep CLAUDE.md modular. This allows selectively including relevant standards files in each package's CLAUDE.md based on domain knowledge.

---

**Q140.** How can you verify which memory files are loaded and diagnose inconsistent behavior across sessions?

A) Check the session logs  
B) Use the `/memory` command to verify which memory files are loaded  
C) Read the CLAUDE.md file  
D) Check the API response headers  

**Correct Answer: B**  
The `/memory` command verifies which memory files are loaded and helps diagnose inconsistent behavior across sessions. This is useful when Claude behaves differently than expected.

---

**Q141.** A developer places team-wide coding standards in `~/.claude/CLAUDE.md`. Their teammate doesn't see these standards. What should the developer do?

A) Ask the teammate to copy the file  
B) Move the instructions to project-level `.claude/CLAUDE.md` or root `CLAUDE.md` so they're shared via version control  
C) Email the standards to the team  
D) Add them to the system prompt  

**Correct Answer: B**  
User-level `~/.claude/CLAUDE.md` instructions apply only to that user. For team-wide standards, use project-level configuration that's version-controlled and available to all developers who clone the repo.

---

**Q142.** You have three packages in your monorepo: `frontend`, `backend`, and `shared`. Each has different coding conventions. How should you organize CLAUDE.md?

A) One large CLAUDE.md at the root listing all conventions  
B) Use `@import` in each package's CLAUDE.md to selectively include relevant standards files  
C) Put all conventions in the system prompt  
D) Use environment variables to switch conventions  

**Correct Answer: B**  
Using `@import` to selectively include relevant standards files in each package's CLAUDE.md keeps configuration modular. Each package imports only its relevant standards based on maintainer domain knowledge.

---

### Task Statement 3.2: Custom Slash Commands and Skills

**Q143.** You want to create a `/review` command that runs your team's standard code review checklist. This should be available to every developer who clones the repo. Where do you create this?

A) In `~/.claude/commands/` in each developer's home directory  
B) In `.claude/commands/` in the project repository  
C) In the CLAUDE.md file  
D) In `.claude/config.json`  

**Correct Answer: B**  
Project-scoped custom slash commands should be in `.claude/commands/` in the project repository. These are version-controlled and automatically available to all developers when they clone or pull the repo.

---

**Q144.** You create a skill that generates a comprehensive codebase analysis report. The report is 2000+ lines and pollutes the main conversation context, making subsequent interactions less effective. What should you do?

A) Truncate the report  
B) Use `context: fork` in the SKILL.md frontmatter to run the skill in an isolated sub-agent context, preventing output from polluting the main conversation  
C) Save the report to a file instead of returning it  
D) Split the analysis into smaller reports  

**Correct Answer: B**  
The `context: fork` frontmatter option runs skills in an isolated sub-agent context. This prevents verbose skill outputs from polluting the main conversation, maintaining clean context for subsequent interactions.

---

**Q145.** What frontmatter options are supported in SKILL.md files?

A) `name`, `description`, `version`  
B) `context: fork`, `allowed-tools`, and `argument-hint`  
C) `priority`, `timeout`, `retry`  
D) `model`, `temperature`, `max_tokens`  

**Correct Answer: B**  
SKILL.md files support frontmatter configuration including `context: fork` (isolated execution), `allowed-tools` (tool access restrictions), and `argument-hint` (prompts for required parameters).

---

**Q146.** You want to restrict a skill to only file write operations, preventing it from running destructive bash commands. What frontmatter should you use?

A) `permissions: write-only`  
B) `allowed-tools` in the SKILL.md frontmatter to restrict tool access during skill execution  
C) `safe-mode: true`  
D) `readonly: false`  

**Correct Answer: B**  
Configuring `allowed-tools` in skill frontmatter restricts tool access during skill execution. This can limit the skill to only file write operations, preventing destructive actions like arbitrary bash commands.

---

**Q147.** A developer wants to create a personal variant of a team skill without affecting teammates. Where should they create it?

A) Modify the project-level skill  
B) Create a personal variant in `~/.claude/skills/` with a different name  
C) Fork the repository  
D) Create a branch with the modified skill  

**Correct Answer: B**  
Personal skill customization is done by creating personal variants in `~/.claude/skills/` with different names. This avoids affecting teammates while providing customized behavior.

---

**Q148.** When should you use a skill versus a CLAUDE.md instruction?

A) Skills and CLAUDE.md serve the same purpose  
B) Skills are for on-demand invocation for task-specific workflows; CLAUDE.md is for always-loaded universal standards  
C) Skills are faster; CLAUDE.md is more reliable  
D) Skills are for personal use; CLAUDE.md is for teams  

**Correct Answer: B**  
Skills are invoked on-demand for specific tasks, while CLAUDE.md instructions are always loaded and apply universally. Use skills for task-specific workflows (like code analysis) and CLAUDE.md for consistent standards (like coding conventions).

---

**Q149.** The `argument-hint` frontmatter in SKILL.md is used for:

A) Providing default parameter values  
B) Prompting developers for required parameters when they invoke the skill without arguments  
C) Documenting the skill's purpose  
D) Setting skill priority  

**Correct Answer: B**  
`argument-hint` frontmatter prompts developers for required parameters when they invoke the skill without arguments. This ensures the skill receives necessary input.

---

**Q150.** What is the difference between project-scoped commands in `.claude/commands/` and user-scoped commands in `~/.claude/commands/`?

A) Project commands are faster  
B) Project commands are shared via version control and available to all team members; user commands are personal and not version-controlled  
C) User commands have more permissions  
D) They function identically  

**Correct Answer: B**  
Project-scoped commands in `.claude/commands/` are version-controlled and shared with all developers. User-scoped commands in `~/.claude/commands/` are personal and not shared via version control.

---

### Task Statement 3.3: Path-Specific Rules

**Q151.** You want Terraform-specific conventions to apply only when editing Terraform files. How should you configure this?

A) Add Terraform conventions to the root CLAUDE.md  
B) Create a `.claude/rules/` file with YAML frontmatter `paths: ["terraform/**/*"]` so rules load only when editing matching files  
C) Create a CLAUDE.md in the terraform directory  
D) Add conditions in the system prompt  

**Correct Answer: B**  
Path-specific rules in `.claude/rules/` with YAML frontmatter path scoping (e.g., `paths: ["terraform/**/*"]`) load only when editing matching files. This reduces irrelevant context and token usage.

---

**Q152.** Your test files are spread throughout the codebase (e.g., `Button.test.tsx` next to `Button.tsx`). You want all tests to follow the same conventions regardless of location. Which approach is best?

A) Place a CLAUDE.md in every directory containing tests  
B) Use glob patterns in `.claude/rules/` (e.g., `**/*.test.tsx`) to apply conventions to test files regardless of directory location  
C) Add test conventions to every package's CLAUDE.md  
D) Create a single tests directory and move all tests there  

**Correct Answer: B**  
Glob patterns in `.claude/rules/` (like `**/*.test.tsx`) apply conventions to files by type regardless of directory location. This is essential for test files spread throughout the codebase, which directory-level CLAUDE.md files cannot easily handle.

---

**Q153.** Why are path-specific rules preferred over directory-level CLAUDE.md files for conventions that span multiple directories?

A) They're easier to write  
B) Path-specific rules with glob patterns apply to matching files regardless of directory, while directory-level CLAUDE.md files are directory-bound and can't handle files spread across many directories  
C) They're more performant  
D) They support more configuration options  

**Correct Answer: B**  
Path-specific rules with glob patterns match files by type regardless of location. Directory-level CLAUDE.md files are bound to their specific directory and cannot handle conventions that need to apply to files spread across many directories.

---

**Q154.** How do path-scoped rules reduce token usage?

A) They compress rule content  
B) They load only when editing matching files, avoiding loading irrelevant conventions into context  
C) They use shorter syntax  
D) They cache rules across sessions  

**Correct Answer: B**  
Path-scoped rules load only when editing matching files. This means Terraform conventions are not loaded when editing React components, and vice versa. This reduces irrelevant context and saves tokens.

---

**Q155.** You have API conventions that should apply to files in `src/api/`, `src/services/api/`, and `lib/api-utils/`. Which configuration approach works best?

A) Place a CLAUDE.md in each directory  
B) Create a `.claude/rules/api-conventions.md` with glob patterns like `paths: ["**/api/**/*", "**/api-*/**/*"]`  
C) Add API conventions to the root CLAUDE.md  
D) Create a skill for API-related changes  

**Correct Answer: B**  
Glob patterns in `.claude/rules/` can match files across multiple directories. This is more maintainable than placing CLAUDE.md files in each directory or loading all conventions globally.

---

### Task Statement 3.4: Plan Mode vs Direct Execution

**Q156.** You need to restructure a monolithic application into microservices, affecting dozens of files. Which mode should you use?

A) Direct execution with comprehensive upfront instructions  
B) Plan mode to explore the codebase, understand dependencies, and design an approach before making changes  
C) Direct execution, switching to plan mode only if complexity emerges  
D) Direct execution with incremental changes  

**Correct Answer: B**  
Plan mode is designed for complex tasks involving large-scale changes, multiple valid approaches, and architectural decisions. Monolith-to-microservices restructuring requires codebase exploration and design before committing to changes.

---

**Q157.** A developer needs to fix a bug: adding a null check to prevent a crash in a single function. The stack trace clearly shows the issue. Which mode should they use?

A) Plan mode for thorough analysis  
B) Direct execution — this is a well-understood change with clear scope  
C) Plan mode first, then switch to direct execution  
D) Create a skill for bug fixes  

**Correct Answer: B**  
Direct execution is appropriate for simple, well-scoped changes like a single-file bug fix with a clear stack trace. Plan mode would add unnecessary overhead for such a straightforward fix.

---

**Q158.** When is it valuable to combine plan mode and direct execution?

A) Never — they should be used independently  
B) Use plan mode for investigation and architecture decisions, then switch to direct execution for implementing the planned approach  
C) Always start with direct execution  
D) Use plan mode only for documentation  

**Correct Answer: B**  
Combining modes is valuable: plan mode for investigation and architecture decisions (e.g., planning a library migration), then direct execution for implementing the planned approach.

---

**Q159.** What is the Explore subagent used for in relation to plan mode?

A) Exploring alternative models  
B) Isolating verbose discovery output during exploration phases, returning summaries to preserve the main conversation context  
C) Browsing the web for documentation  
D) Testing code changes  

**Correct Answer: B**  
The Explore subagent isolates verbose discovery output. During multi-phase tasks, it prevents context window exhaustion by containing exploratory output and returning only summaries to the main conversation.

---

**Q160.** Which of the following tasks is most appropriate for plan mode?

A) Adding a date validation to one function  
B) Migrating a library that affects 45+ files with multiple valid implementation approaches  
C) Fixing a typo in a string constant  
D) Adding a log statement to a function  

**Correct Answer: B**  
Plan mode is appropriate for tasks with architectural implications. A library migration affecting 45+ files with multiple valid approaches requires exploration and design before committing to changes. The other options are simple, well-scoped changes suitable for direct execution.

---

**Q161.** A developer starts with direct execution on a task, but partway through discovers it requires changes across 30 files with complex interdependencies. What should they do?

A) Continue with direct execution to avoid wasting progress  
B) This is exactly when switching to plan mode provides value — for complex architectural tasks with discovered dependencies  
C) Start over in a new session  
D) Ask a teammate for help  

**Correct Answer: B**  
Discovering unexpected complexity during implementation is exactly when plan mode becomes valuable. The developer should switch to plan mode to design an approach that accounts for the newly discovered interdependencies.

---

### Task Statement 3.5: Iterative Refinement

**Q162.** You describe a data transformation in prose, but Claude's output is inconsistent across runs. Some runs produce the correct format, others don't. What is the most effective fix?

A) Be more detailed in the prose description  
B) Provide 2-3 concrete input/output examples to clarify transformation requirements  
C) Increase the temperature for variety  
D) Run multiple times and pick the best result  

**Correct Answer: B**  
Concrete input/output examples are the most effective way to communicate expected transformations when prose descriptions are interpreted inconsistently. They eliminate ambiguity about the expected format.

---

**Q163.** You're building a new feature in an unfamiliar domain and want Claude to surface considerations you might not have anticipated. What technique should you use?

A) Provide a detailed specification  
B) The interview pattern — have Claude ask questions to surface design considerations before implementing  
C) Let Claude decide the implementation autonomously  
D) Read documentation first and then provide instructions  

**Correct Answer: B**  
The interview pattern has Claude ask questions to surface considerations the developer may not have anticipated. This is especially valuable in unfamiliar domains where there may be non-obvious requirements (cache invalidation strategies, failure modes, etc.).

---

**Q164.** You find that Claude's implementation handles 90% of cases correctly but fails on edge cases (e.g., null values in migration scripts). What is the most effective approach?

A) Describe the edge cases in natural language  
B) Provide specific test cases with example input and expected output for the edge cases  
C) Increase the context about the edge cases  
D) Implement the edge case handling manually  

**Correct Answer: B**  
The exam guide recommends providing specific test cases with example input and expected output to fix edge case handling. Concrete examples are more effective than natural language descriptions for edge cases.

---

**Q165.** You have a test suite that covers expected behavior, edge cases, and performance requirements. Your implementation passes 70% of tests. What iterative approach should you use?

A) Rewrite the implementation from scratch  
B) Share the specific test failures with Claude, iterating by providing failing test output to guide progressive improvement  
C) Ask Claude to generate a new implementation  
D) Fix the failures manually  

**Correct Answer: B**  
Test-driven iteration involves writing test suites first, then iterating by sharing test failures to guide progressive improvement. The specific test failure output provides concrete feedback for the model to address.

---

**Q166.** You have five issues with Claude's output: two are independent (formatting and performance) and three interact with each other (validation, error handling, retry logic). How should you communicate the fixes?

A) Fix all five in one message for efficiency  
B) Address the three interacting issues in a single detailed message; address the two independent issues sequentially  
C) Fix each one separately across five messages  
D) Prioritize and fix only the most important  

**Correct Answer: B**  
The exam guide distinguishes between providing all issues in a single message (for interacting problems) versus fixing sequentially (for independent problems). Interacting issues should be addressed together since their fixes affect each other.

---

**Q167.** A developer gives Claude the instruction "add comprehensive tests to this code." The resulting tests are low quality. What iterative refinement technique should they use first?

A) Provide more context about the code  
B) Provide 2-3 concrete examples of expected test input/output, and write the test suite first with expected behavior before having Claude implement  
C) Use a different prompt template  
D) Lower the temperature  

**Correct Answer: B**  
Providing concrete examples and writing test suites covering expected behavior before implementation is the recommended approach. This sets clear quality standards for Claude to meet.

---

### Task Statement 3.6: CI/CD Integration

**Q168.** Your CI pipeline runs `claude "Analyze this PR"` but hangs indefinitely because Claude waits for interactive input. What flag fixes this?

A) `--batch`  
B) `-p` (or `--print`) to run in non-interactive mode  
C) `--headless`  
D) `--ci`  

**Correct Answer: B**  
The `-p` (or `--print`) flag runs Claude Code in non-interactive mode. It processes the prompt, outputs the result to stdout, and exits without waiting for user input — exactly what CI/CD pipelines require.

---

**Q169.** Your CI pipeline needs to produce machine-parseable output for posting as inline PR comments. What CLI flags should you use?

A) `--format json`  
B) `--output-format json` with `--json-schema` for structured output  
C) `--machine-readable`  
D) `--parse-output`  

**Correct Answer: B**  
`--output-format json` and `--json-schema` CLI flags enforce structured output in CI contexts. This produces machine-parseable JSON that can be automatically posted as inline PR comments.

---

**Q170.** The same Claude session that generated code is used to review its own changes. What is the issue with this approach?

A) It's fine for self-review  
B) Session context isolation matters — the same session retains reasoning context from generation, making it less effective at reviewing its own decisions  
C) It uses too many tokens  
D) The review might be faster  

**Correct Answer: B**  
The same Claude session that generated code retains reasoning context from generation, making it less likely to question its own decisions. An independent review instance (without prior reasoning context) is more effective at catching issues.

---

**Q171.** After a new commit, your CI re-runs the review and posts duplicate comments about issues already flagged in the previous review. How should you prevent this?

A) Delete previous comments before posting new ones  
B) Include prior review findings in context when re-running reviews, instructing Claude to report only new or still-unaddressed issues  
C) Only review the changed files  
D) Reduce the review scope  

**Correct Answer: B**  
Including prior review findings in context and instructing Claude to report only new or still-unaddressed issues avoids duplicate comments across review iterations.

---

**Q172.** Your CI generates test suggestions, but many duplicate existing tests. How should you improve this?

A) Deduplicate after generation  
B) Provide existing test files in context so test generation avoids suggesting duplicate scenarios already covered by the test suite  
C) Generate more tests and remove duplicates  
D) Only generate tests for new code  

**Correct Answer: B**  
Providing existing test files in context lets Claude Code avoid suggesting duplicate scenarios. This improves test generation quality by building on, not duplicating, existing coverage.

---

**Q173.** What role does CLAUDE.md play in CI-invoked Claude Code?

A) It's not used in CI  
B) It provides project context (testing standards, fixture conventions, review criteria) to CI-invoked Claude Code, improving output quality  
C) It configures CI pipeline settings  
D) It stores CI credentials  

**Correct Answer: B**  
CLAUDE.md provides project context to CI-invoked Claude Code. Documenting testing standards, valuable test criteria, and available fixtures in CLAUDE.md improves test generation quality and reduces low-value test output.

---

**Q174.** You want Claude Code to generate structured JSON output in your CI pipeline for automated processing. Which approach provides the most reliable structured output?

A) Ask Claude to "output in JSON format" in the prompt  
B) Use `--output-format json` with `--json-schema` to enforce schema-compliant output  
C) Parse the text output with regex  
D) Use `tool_choice: "any"` in the system prompt  

**Correct Answer: B**  
The `--output-format json` flag combined with `--json-schema` enforces structured output in CI contexts. This is more reliable than prompt-based JSON requests because it eliminates formatting inconsistencies.

---

**Q175.** Your CI pipeline runs a security review using Claude Code. The pipeline runs `claude "Review for security issues"` and hangs. After adding `-p`, it works but produces unstructured text. You need each finding as a JSON object with `file`, `line`, `severity`, and `description` fields. What's the complete solution?

A) `claude -p "Review for security issues and output JSON"`  
B) `claude -p --output-format json --json-schema '{"type":"array","items":{"type":"object","properties":{"file":{"type":"string"},"line":{"type":"integer"},"severity":{"type":"string"},"description":{"type":"string"}}}}' "Review for security issues"`  
C) `claude --batch --json "Review for security issues"`  
D) `claude -p "Review for security issues" | jq`  

**Correct Answer: B**  
The combination of `-p` (non-interactive), `--output-format json`, and `--json-schema` (with the desired schema) produces machine-parseable, schema-compliant structured output suitable for automated PR comment posting.

---

### Additional Claude Code Configuration Questions

**Q176.** You have a monorepo with `frontend/`, `backend/`, and `infrastructure/` directories. Each needs different conventions. What's the best configuration strategy?

A) One large CLAUDE.md at root  
B) Combine `.claude/rules/` with path-specific glob patterns for each area, plus a root CLAUDE.md for shared standards  
C) Separate CLAUDE.md in each directory only  
D) Use environment variables  

**Correct Answer: B**  
Combining `.claude/rules/` with path-specific glob patterns handles directory-specific conventions, while a root CLAUDE.md handles shared standards. This is more maintainable than either approach alone.

---

**Q177.** A skill runs a brainstorming session that generates many alternative approaches. This pollutes the main conversation context, causing confusion in subsequent work. What SKILL.md configuration prevents this?

A) `max-output: 100`  
B) `context: fork` — runs the skill in isolated context, preventing output from polluting the main conversation  
C) `quiet: true`  
D) `redirect: file`  

**Correct Answer: B**  
`context: fork` runs skills in an isolated sub-agent context. This is ideal for skills that produce verbose output (codebase analysis) or exploratory context (brainstorming alternatives) that shouldn't affect the main session.

---

**Q178.** When should you use the `/compact` command?

A) To compress files  
B) To reduce context usage during extended exploration sessions when context fills with verbose discovery output  
C) To minify code  
D) To compress API responses  

**Correct Answer: B**  
The `/compact` command reduces context usage during extended exploration sessions. When context fills with verbose discovery output, `/compact` helps manage the context window.

---

**Q179.** Your team's code review skill needs access to Read and Grep tools but should NOT have access to Write, Edit, or Bash to prevent modifications. How do you configure this?

A) Add instructions in the skill prompt  
B) Use `allowed-tools` in the SKILL.md frontmatter to restrict tool access to only Read and Grep  
C) Remove Write, Edit, and Bash from the system  
D) Create a read-only user account  

**Correct Answer: B**  
`allowed-tools` in SKILL.md frontmatter restricts tool access during skill execution. This provides deterministic access control, preventing the skill from accessing tools not in the allowed list.

---

**Q180.** A developer creates a `/deploy` command in `.claude/commands/` that runs deployment scripts. A new team member clones the repo. Will they have access to this command?

A) No, commands need to be installed separately  
B) Yes — project-scoped commands in `.claude/commands/` are version-controlled and automatically available when the repo is cloned  
C) Only if they have the right permissions  
D) Only after running a setup script  

**Correct Answer: B**  
Project-scoped commands in `.claude/commands/` are version-controlled. When a developer clones or pulls the repo, these commands are automatically available.

---

**Q181.** You want Claude to follow specific TypeScript conventions when editing `.ts` files and specific Python conventions when editing `.py` files. What is the most efficient approach?

A) Include both sets of conventions in the root CLAUDE.md  
B) Create separate `.claude/rules/` files with path-scoped YAML frontmatter: `paths: ["**/*.ts"]` for TypeScript rules and `paths: ["**/*.py"]` for Python rules  
C) Use a single CLAUDE.md with conditional logic  
D) Create separate branches for each language  

**Correct Answer: B**  
Path-scoped rules load only when editing matching files. TypeScript conventions load for `.ts` files; Python conventions load for `.py` files. This is more efficient than loading all conventions regardless of the file being edited.

---

**Q182.** Your CI pipeline runs test generation with Claude Code. The generated tests use incorrect assertion patterns and mock frameworks. How should you improve the output?

A) Post-process the generated tests  
B) Document testing standards, valuable test criteria, and available fixtures in CLAUDE.md so Claude Code uses them during generation  
C) Provide a test template  
D) Use a different testing framework  

**Correct Answer: B**  
Documenting testing standards in CLAUDE.md improves test generation quality. When Claude Code has access to project-specific testing conventions, fixtures, and criteria, it produces higher-quality, consistent tests.

---

**Q183.** What happens when path-specific rules in `.claude/rules/` don't match the file being edited?

A) They load anyway with lower priority  
B) They are not loaded, reducing irrelevant context and token usage  
C) They generate warnings  
D) They use default values  

**Correct Answer: B**  
Path-scoped rules load only when editing matching files. If the glob pattern doesn't match the current file, the rules are not loaded, reducing irrelevant context and saving tokens.

---

**Q184.** You have a complex codebase analysis task that requires loading many files. During analysis, the context fills with verbose output and Claude starts giving vague answers. What two features can help?

A) Higher temperature and more tokens  
B) The Explore subagent for isolating verbose discovery output, and `/compact` for reducing context usage  
C) Multiple API requests and caching  
D) Summarization prompts and file filters  

**Correct Answer: B**  
The Explore subagent isolates verbose discovery output while returning summaries. The `/compact` command reduces context usage. Together, they prevent context exhaustion during complex exploration tasks.

---

**Q185.** When running Claude Code in CI, why should you use an independent session for code review rather than the same session that generated the code?

A) For billing purposes  
B) Session context isolation ensures the reviewer doesn't retain the generator's reasoning context, making it more effective at finding issues  
C) To avoid API rate limits  
D) For security compliance  

**Correct Answer: B**  
Self-review limitations mean a model retains reasoning context from generation, making it less likely to question its own decisions. An independent review instance without prior reasoning context is more effective at catching subtle issues.

---

**Q186.** You want to create a `.claude/rules/testing.md` file that applies to all test files across the codebase. What should the YAML frontmatter look like?

A) `type: testing`  
B) `paths: ["**/*.test.*", "**/*.spec.*", "**/__tests__/**/*"]`  
C) `scope: tests`  
D) `match: test`  

**Correct Answer: B**  
YAML frontmatter in `.claude/rules/` uses `paths` with glob patterns. `**/*.test.*`, `**/*.spec.*`, and `**/__tests__/**/*` cover common test file patterns regardless of directory location.

---

**Q187.** A skill generates a codebase dependency graph and saves it to a file. Should this skill use `context: fork`?

A) No, the dependency graph is useful context  
B) Yes — the skill likely produces verbose discovery output that would pollute the main conversation; the saved file persists regardless of context isolation  
C) Only if the graph is large  
D) No, forking is only for destructive operations  

**Correct Answer: B**  
If the skill produces verbose output during graph generation, `context: fork` prevents that from polluting the main conversation. The saved file persists regardless of context isolation, so the developer still gets the result.

---

**Q188.** Your team has five developers, each with their own debugging preferences. How should personal debugging tools be configured?

A) Add all preferences to the project CLAUDE.md  
B) Each developer creates personal commands/skills in `~/.claude/commands/` or `~/.claude/skills/` for their individual preferences  
C) Create five branches with different configurations  
D) Use environment variables per developer  

**Correct Answer: B**  
Personal preferences should be in user-scoped directories (`~/.claude/commands/`, `~/.claude/skills/`). These are personal, not version-controlled, and don't affect teammates.

---

**Q189.** What is the advantage of using `.claude/rules/` with glob patterns over placing CLAUDE.md files in every subdirectory?

A) It's fewer files  
B) Glob patterns apply conventions based on file type regardless of directory location, while directory-level CLAUDE.md files are bound to specific directories  
C) Rules are loaded faster  
D) Rules support more syntax  

**Correct Answer: B**  
Glob patterns match files by type (e.g., `**/*.test.tsx`) regardless of where they are in the directory structure. Directory-level CLAUDE.md files only apply to files in that specific directory, which is insufficient when conventions need to apply across many directories.

---

**Q190.** When should you use plan mode for a task in Claude Code? (Select the best answer)

A) For any task to be safe  
B) When the task involves large-scale changes, multiple valid approaches, architectural decisions, or multi-file modifications  
C) Only when explicitly asked by a manager  
D) When you're unsure about the code  

**Correct Answer: B**  
Plan mode is appropriate for complex tasks with architectural implications, multiple valid approaches, large-scale changes, or multi-file modifications. It enables safe exploration and design before committing to changes.

---

**Q191.** Your CI pipeline runs Claude Code for test generation. How should you ensure generated tests are valuable and not low-quality filler?

A) Filter tests by coverage  
B) Document testing standards, valuable test criteria (what makes a good test), and available fixtures in CLAUDE.md  
C) Generate more tests and pick the best  
D) Only generate unit tests  

**Correct Answer: B**  
Documenting what makes a valuable test, the project's testing standards, and available fixtures in CLAUDE.md improves test generation quality. This gives Claude Code the criteria needed to produce meaningful tests.

---

**Q192.** You run a review on a PR where a colleague previously fixed some flagged issues. The review still flags the old issues. What's the fix?

A) Clear the review cache  
B) Include prior review findings in context and instruct Claude to report only new or still-unaddressed issues  
C) Review only new commits  
D) Use a different reviewer instance  

**Correct Answer: B**  
Including prior review findings in context and instructing Claude to report only new or still-unaddressed issues prevents re-flagging issues that have already been addressed.

---

**Q193.** What does `context: fork` prevent when used in a SKILL.md?

A) File system modifications  
B) Skill outputs from polluting the main conversation — the skill runs in an isolated sub-agent context  
C) Network access  
D) Tool execution  

**Correct Answer: B**  
`context: fork` runs the skill in an isolated sub-agent context, preventing its outputs from polluting the main conversation. This is crucial for verbose skills (codebase analysis, brainstorming) that would otherwise fill the context window.

---

**Q194.** A CI pipeline needs to run Claude Code for both security review and test generation. Should these use the same session?

A) Yes, for efficiency  
B) No — using separate sessions provides context isolation, preventing cross-contamination between the security review and test generation tasks  
C) It depends on the pipeline configuration  
D) Yes, to share context between tasks  

**Correct Answer: B**  
Separate sessions provide context isolation. The security review should not be influenced by test generation reasoning and vice versa. Independent sessions produce more focused, higher-quality output.

---

**Q195.** Your team wants consistent Terraform conventions across all `.tf` files, consistent React conventions across `.tsx` files, and consistent API conventions across files in any `api/` directory. What configuration provides this?

A) One CLAUDE.md with all rules  
B) Three `.claude/rules/` files with path-scoped frontmatter: `paths: ["**/*.tf"]`, `paths: ["**/*.tsx"]`, and `paths: ["**/api/**/*"]`  
C) Three CLAUDE.md files in terraform/, react/, and api/ directories  
D) A single `.claude/rules/conventions.md` with all rules  

**Correct Answer: B**  
Three separate `.claude/rules/` files with specific path patterns ensures each convention loads only for matching files. This is more targeted than a single file with all rules (which loads everything) or directory-specific files (which don't handle files spread across directories).

---
