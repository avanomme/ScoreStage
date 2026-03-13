This file is a **handoff prompt**: paste it into Claude Code to set up a robust, project-agnostic agent + slash-command workflow for this repo.

---

**Claude, here’s how to set up this repo’s workflow scaffold:**

1. **Read this file fully, and treat it as the “single source of truth” for all commands/agents.**
2. **Don’t make any assumptions about the product or requirements beyond what’s in `project.md`.**
3. **Create only the minimal, generic scaffolding: directories, placeholder files, and canonical command/agent specs.**
4. **Do not generate a product plan, features, or tasks from `project.md` — that’s the job of `/bootstrap`.**
5. **Never overwrite existing files unless they are empty or the user asks.**
6. **After the scaffold, print a summary: what was created, what already existed, and the next step.**

## Directories to Ensure

- `.claude/`
- `.claude/commands/`
- `.claude/agents/`
- `docs/internal/`

## Required JSON Placeholders

- `.claude/settings.json` — conservative defaults:
  - `filesystem: true`
  - `web_access: false`
  - `execution: false`
  - small patch limits
- `.claude/tasks.json` — valid schema, empty task list

## Command Placeholders (Markdown)

Create these files under `.claude/commands/`:
- `bootstrap.md` (will read `project.md` and generate tasks)
- `next_task.md`
- `update_task.md`
- `status.md`
- `doc_sync.md`
- `review.md`
- `compact.md`
- `setup.md` (this file)

Each command file must contain:
- Purpose
- Inputs
- Outputs
- Guardrails
- Step-by-step behavior

## Agent Placeholders (Markdown)

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

Each agent file must contain:
- Role
- Reads (inputs)
- Writes (outputs)
- Guardrails

## Internal Docs Placeholders

Create these files under `docs/internal/`:
- `scope.md` (placeholder; `/bootstrap` will populate from `project.md`)
- `decisions.md` (decision log placeholder)
- `progress.md` (session log placeholder)

## Guardrails

- Do **not** generate a product plan.
- Do **not** generate tasks from `project.md` (that is for `/bootstrap`).
- Do **not** run shell commands unless the user explicitly asks.
- Keep changes limited to scaffolding files/directories.

---

**This file should be kept at the repo root. If you later change your workflow, update this file — the important part is that the content above stays your “single source of truth” for auto-creating all these commands/agents.**