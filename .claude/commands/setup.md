# /setup — Scaffold Claude Workflow Placeholders

## Purpose
Create the repository’s Claude Code workflow scaffold (directories + placeholder files) with **minimal opinions**.

This is intentionally a bootstrapper:
- It should **not** plan the product.
- It should **not** generate tasks from `project.md`.
- It should **not** implement features.

After `/setup` completes, the user will run `/bootstrap` to generate tasks from `project.md`.

## Inputs
- `claude_setup.md` (this repo’s handoff prompt and guardrails)
- `project.md` (may be incomplete; do not infer requirements)

## Behavior
1. Read `claude_setup.md` and follow its safety rules.
2. Ensure these directories exist:
   - `.claude/`
   - `.claude/commands/`
   - `.claude/agents/`
   - `docs/internal/`
3. Create placeholder files if missing (do not overwrite user edits; if the file exists, leave it as-is unless it’s clearly empty):

### Required JSON placeholders
- `.claude/settings.json`
  - If missing, create with conservative defaults:
    - filesystem: true
    - web_access: false
    - execution: false
    - small patch limits
- `.claude/tasks.json`
  - If missing, create an empty-but-valid schema with no real tasks yet.

### Command placeholders (Markdown)
Create these files under `.claude/commands/`:
- `bootstrap.md` (will read `project.md` and generate tasks)
- `next_task.md`
- `update_task.md`
- `status.md`
- `doc_sync.md`
- `review.md`
- `compact.md`
- `setup.md` (this file)

Each placeholder command file must contain:
- Purpose
- Inputs
- Outputs
- Guardrails
- Step-by-step behavior

### Agent placeholders (Markdown)
Create these files under `.claude/agents/`:
- `mvp-planner.md`
- `bug-fixer.md`
- `release-manager.md`
- `ui-stylist.md`
- `doc-syncer.md`
- `reviewer-readonly.md`
- `modular-architect.md`
- `test-sentinel.md`
- `auto-commenter.md`

Each agent placeholder must contain:
- Role
- Reads (inputs)
- Writes (outputs)
- Guardrails

### Internal docs placeholders
Create these files under `docs/internal/`:
- `scope.md` (placeholder; `/bootstrap` will populate based on `project.md`)
- `decisions.md` (decision log placeholder)
- `progress.md` (session log placeholder)

4. Print a short summary:
   - what was created
   - what was already present
   - next step: run `/bootstrap`

## Guardrails
- Do **not** generate a product plan.
- Do **not** generate tasks from `project.md` (that belongs to `/bootstrap`).
- Do **not** run shell commands unless the user explicitly asks.
- Keep changes limited to scaffolding files/directories.