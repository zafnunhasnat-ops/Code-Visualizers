#!/usr/bin/env bash
# =============================================================================
# setup-github.sh
# Bootstraps the GitHub side of the project: labels, 20 weekly milestones,
# issues (Weeks 1-3 detailed, later weeks rough), phase epics, optional board.
#
# Usage (run from inside your cloned repo):
#   DRY_RUN=1 ./scripts/setup-github.sh            # preview, touches nothing
#   ./scripts/setup-github.sh                      # for real
#   START_DATE=2026-11-16 ./scripts/setup-github.sh  # pick your Week 1 Monday
#   WITH_PROJECT=1 ./scripts/setup-github.sh       # also create a Projects board
#                                                  # (needs: gh auth refresh -s project)
#
# Run it ONCE. Labels and milestones are safe to re-run; issues are not
# (they would be duplicated).
# =============================================================================
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
WITH_PROJECT="${WITH_PROJECT:-0}"
START_DATE="${START_DATE:-}"
PROJECT_TITLE="${PROJECT_TITLE:-Roadmap}"

command -v python3 >/dev/null || { echo "python3 is required (used for date math)"; exit 1; }

if [ "$DRY_RUN" != "1" ]; then
  command -v gh >/dev/null || { echo "Install the GitHub CLI: https://cli.github.com"; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "Run: gh auth login"; exit 1; }
  gh repo view >/dev/null 2>&1 || { echo "Run this from inside your cloned repo"; exit 1; }
fi

# Default Week 1 start = next Monday
if [ -z "$START_DATE" ]; then
  START_DATE="$(python3 - <<'PY'
import datetime as d
t = d.date.today()
print(t + d.timedelta(days=(7 - t.weekday()) % 7 or 7))
PY
)"
fi
echo "Week 1 starts: $START_DATE"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
COUNTER=0

# ---------------------------------------------------------------- milestones
ms_title() {
  local w; w="$(printf '%02d' "$1")"
  case "$1" in
    1)  echo "Week $w: Architecture & trace schema" ;;
    2)  echo "Week $w: Python tracer (CLI)" ;;
    3)  echo "Week $w: Frontend skeleton" ;;
    4)  echo "Week $w: Pyodide + Web Worker" ;;
    5)  echo "Week $w: Call stack & variables" ;;
    6)  echo "Week $w: Heap & pointers I" ;;
    7)  echo "Week $w: Heap & pointers II" ;;
    8)  echo "Week $w: Single-player polish" ;;
    9)  echo "Week $w: Backend + database" ;;
    10) echo "Week $w: Short IDs & routing" ;;
    11) echo "Week $w: Hardening & link previews" ;;
    12) echo "Week $w: WebSockets & rooms" ;;
    13) echo "Week $w: Presenter/follower sync" ;;
    14) echo "Week $w: Shared editing I (Yjs)" ;;
    15) echo "Week $w: Shared editing II / hardening" ;;
    16) echo "Week $w: Cyberpunk design I" ;;
    17) echo "Week $w: Cyberpunk design II" ;;
    18) echo "Week $w: JavaScript support I" ;;
    19) echo "Week $w: JavaScript support II + plugin API" ;;
    20) echo "Week $w: Ship it" ;;
  esac
}

# -------------------------------------------------------------------- labels
make_label() { # name color description
  if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] label: $1"; return; fi
  gh label create "$1" --color "$2" --description "$3" --force >/dev/null
  echo "label: $1"
}

echo; echo "== Labels =="
make_label "type: feature"  "1D76DB" "New functionality"
make_label "type: bug"      "D73A4A" "Something is broken"
make_label "type: chore"    "CFD3D7" "Tooling, setup, refactors"
make_label "type: docs"     "0075CA" "Documentation"
make_label "type: learning" "A371F7" "Study task that produces a note in docs/notes"
make_label "type: epic"     "3E4B9E" "Phase-level tracking issue"
make_label "area: tracer"   "0E8A16" "Python/JS tracer and trace schema"
make_label "area: frontend" "FF2E88" "React UI"
make_label "area: backend"  "F9A825" "FastAPI, database, WebSockets"
make_label "area: collab"   "00BCD4" "Live collaboration"
make_label "area: design"   "B100FF" "Visual design and theming"
make_label "area: infra"    "5319E7" "CI/CD, deploy, repo setup"
make_label "status: needs-refinement" "FBCA04" "Rough draft, refine at start of its week"
make_label "stretch"        "C5DEF5" "Nice to have, first to cut if behind"

echo; echo "== Milestones =="
EXISTING=""
if [ "$DRY_RUN" != "1" ]; then
  EXISTING="$(gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" --jq '.[].title')"
fi
for w in $(seq 1 20); do
  title="$(ms_title "$w")"
  due="$(python3 -c "import datetime as d; s=d.date.fromisoformat('$START_DATE'); print((s+d.timedelta(days=7*($w-1)+6)).isoformat()+'T23:59:59Z')")"
  if grep -Fxq "$title" <<<"$EXISTING"; then echo "skip (exists): $title"; continue; fi
  if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] milestone: $title (due ${due%%T*})"; continue; fi
  gh api "repos/{owner}/{repo}/milestones" -f title="$title" -f state=open \
    -f due_on="$due" -f description="~5 hours: learn, build, review." >/dev/null
  echo "milestone: $title (due ${due%%T*})"
done

# -------------------------------------------------------------------- issues
issue() { # week phase labels title   (body on stdin)
  local week="$1" phase="$2" labels="$3" title="$4" body num url
  body="$(cat)"
  if [ "$DRY_RUN" = "1" ]; then
    COUNTER=$((COUNTER + 1)); num="$COUNTER"; url="(dry-run)"
    echo "[dry-run] #$num [W$week] $title"
  else
    url="$(gh issue create --title "$title" --body "$body" --label "$labels" \
            --milestone "$(ms_title "$week")")"
    num="${url##*/}"
    echo "created #$num  [W$week] $title"
  fi
  echo "- [ ] #$num $title" >> "$TMP/phase-$phase"
  echo "$url" >> "$TMP/urls"
}

rough() { # week phase labels title description
  issue "$1" "$2" "$3,status: needs-refinement" "$4" <<EOF
## Goal
$5

> Rough draft. Refine tasks and done-criteria at the start of the week, once we know what we learned in earlier weeks.

## Tasks
- [ ] _to be refined_

## Done when
- [ ] _to be refined_
EOF
}

echo; echo "== Issues =="

# ============================ PHASE 1 — WEEK 1 ==============================
issue 1 1 "type: chore,area: infra" "chore: bootstrap repo structure, templates and branch rules" <<'EOF'
## Goal
Give the repo the structure and guardrails every later issue relies on.

## Tasks
- [ ] Create folders: `frontend/`, `backend/`, `tracer/`, `docs/notes/`, `docs/decisions/` (add a `.gitkeep` in each empty one)
- [ ] Copy in the provided `.github/` files (issue templates, PR template, CONTRIBUTING) and `docs/decisions/0001-client-side-execution.md`
- [ ] Rewrite `README.md` skeleton: name, one-line pitch, status badge placeholder, planned features, "how we work" link
- [ ] Settings -> General: allow **squash merging only**, enable **auto-delete head branches**
- [ ] Settings -> Rules: protect `main` (require a pull request, block force pushes). Required status checks come in Week 3.

## Done when
- [ ] This issue was closed by a merged PR (your first one!)
- [ ] `main` rejects direct pushes

## Learning goals
Branch -> commit -> PR -> squash-merge loop; what branch protection actually does.
EOF

issue 1 1 "type: learning,area: tracer" "learning: study how Python Tutor traces a program" <<'EOF'
## Goal
Understand the visualizer architecture (tracer -> trace JSON -> player) before designing anything.

## Tasks
- [ ] Open pythontutor.com, run a recursive function, and step through it. Note everything that changes per step.
- [ ] Read the Python Tutor project README / docs on its trace format (search "OnlinePythonTutor trace format")
- [ ] Write `docs/notes/01-how-visualizers-work.md` (about 1 page, your own words): what is a step? what is on the stack vs the heap? what does the frontend need that the tracer must provide?

## Done when
- [ ] Note is merged
- [ ] It ends with a list of 5+ open questions the schema must answer

## Think-along hint
Don't copy their format. Ask: what is the *minimum* data the UI needs to draw one frame?
EOF

issue 1 1 "type: feature,area: tracer" "feat: design trace JSON schema v0.1" <<'EOF'
## Goal
A written, versioned contract between the tracer (producer) and frontend (consumer).

## Tasks
- [ ] Create `docs/trace-schema.md`
- [ ] Decide and document: what is one **step**? which **event types** (line / call / return / exception)?
- [ ] Decide how to represent the **call stack** (frames, function name, line, locals)
- [ ] Decide how to represent the **heap** and **references** (object ids, how a variable points to an object vs holds a primitive)
- [ ] Decide how **printed output** and **errors** are recorded
- [ ] Add a `schemaVersion` field and explain why it matters
- [ ] List at least 2 alternatives you rejected, and why (this becomes README material)

## Done when
- [ ] Field-by-field table in the doc
- [ ] A reviewer (me) can read it and draw frame N of a program without asking questions

## Learning goals
Schema-first design, producer/consumer contracts, versioning.
EOF

issue 1 1 "type: feature,area: tracer" "feat: hand-write a trace for recursive factorial(3)" <<'EOF'
## Goal
Prove the schema works by writing a real example by hand, before any code exists.

## Tasks
- [ ] Create `tracer/examples/factorial.py` (recursive factorial, called with 3)
- [ ] Create `tracer/examples/factorial.trace.json` by hand, following your schema
- [ ] Walk through it step by step and fix schema gaps you discover (update the schema doc in the same PR)

## Done when
- [ ] Trace has every step including the returns unwinding
- [ ] Schema doc and example agree

## Why by hand?
If it's painful to write by hand, it will be painful to consume. Friction here is cheap to fix; later it's expensive.
EOF

# ============================ PHASE 1 — WEEK 2 ==============================
issue 2 1 "type: learning,area: tracer" "learning: how sys.settrace works" <<'EOF'
## Goal
Understand Python's tracing hook well enough to explain it to someone else.

## Tasks
- [ ] Read the `sys.settrace` docs and the `frame` object docs (`f_lineno`, `f_locals`, `f_back`, `f_code`)
- [ ] Write a 15-line experiment that prints the event name and line number for each event of a small function
- [ ] Write `docs/notes/02-sys-settrace.md`: the 4 event types, what a frame is, what `f_back` gives you

## Done when
- [ ] Note and experiment script merged
EOF

issue 2 1 "type: feature,area: tracer" "feat(tracer): record line events and call-stack frames" <<'EOF'
## Goal
A tracer that produces one step per executed line, with the full stack of frames.

## Tasks
- [ ] Create `tracer/tracer.py` with a trace function installed via `sys.settrace`
- [ ] Record function name, line number, and locals for each frame on the stack
- [ ] Ignore frames from the tracer itself and from stdlib (only trace the user's code)
- [ ] Compare output against your hand-written factorial trace

## Done when
- [ ] Running on `factorial.py` yields the same steps as your hand-written trace (ignoring heap detail for now)

## Think-along hint
Walk `frame.f_back` upward to build the stack. Decide how to avoid tracing your own code.
EOF

issue 2 1 "type: feature,area: tracer" "feat(tracer): serialize values with heap ids and references" <<'EOF'
## Goal
Distinguish primitives from heap objects, and show aliasing (two variables, one list).

## Tasks
- [ ] Primitives (int, str, float, bool, None) are stored inline
- [ ] Lists, dicts, tuples, sets, and instances get a stable id and live in a heap map; variables hold a reference
- [ ] Handle cycles (a list that contains itself) without infinite recursion
- [ ] Cap very large collections (e.g. first 50 items + a "truncated" marker)

## Done when
- [ ] `a = [1,2]; b = a` produces a trace where both variables reference the same heap id
- [ ] A self-referencing list does not crash the tracer

## Learning goals
References vs values, `id()`, how Python's object model maps to our schema.
EOF

issue 2 1 "type: feature,area: tracer" "feat(tracer): CLI, step limit, output capture and pytest suite" <<'EOF'
## Goal
Make the tracer usable and safe: `python tracer.py file.py` prints valid trace JSON.

## Tasks
- [ ] CLI entry point reading a file and printing JSON
- [ ] Hard step limit (e.g. 2000) so infinite loops stop with a clear "step limit reached" marker
- [ ] Capture `print` output into the trace
- [ ] Catch exceptions in user code and record them as a final step
- [ ] pytest tests: factorial, a loop, list aliasing, infinite loop, exception

## Done when
- [ ] `pytest` passes locally
- [ ] README in `tracer/` shows how to run it
EOF

# ============================ PHASE 1 — WEEK 3 ==============================
issue 3 1 "type: learning,area: frontend" "learning: React + TypeScript mental model" <<'EOF'
## Goal
Get the minimum React/TS mental model needed for the player UI.

## Tasks
- [ ] Work through the official React "Quick Start" and "Thinking in React"
- [ ] Skim the TypeScript handbook: types, interfaces, unions
- [ ] Write `docs/notes/03-react-ts-basics.md`: components, props, state, effects, and one thing that surprised you coming from Rails/Java

## Done when
- [ ] Note merged
EOF

issue 3 1 "type: chore,area: frontend" "chore(frontend): scaffold Vite + React + TypeScript + Tailwind + lint" <<'EOF'
## Goal
A running, linted frontend project.

## Tasks
- [ ] `npm create vite@latest frontend -- --template react-ts`
- [ ] Add Tailwind, ESLint, Prettier
- [ ] Add `npm run lint`, `npm run build` scripts that pass
- [ ] Short `frontend/README.md`

## Done when
- [ ] `npm run dev` shows a page; lint and build pass
EOF

issue 3 1 "type: chore,area: infra" "chore(ci): GitHub Actions for tracer tests and frontend lint/build" <<'EOF'
## Goal
Every PR is automatically checked.

## Tasks
- [ ] Workflow: run `pytest` for `tracer/`
- [ ] Workflow: run `npm ci`, lint, and build for `frontend/`
- [ ] Update the `main` ruleset to **require these checks**
- [ ] Add CI status badge to README

## Done when
- [ ] A deliberately failing PR is blocked from merging (then fix it)

## Learning goals
What CI is, YAML basics, why required checks matter.
EOF

issue 3 1 "type: feature,area: frontend" "feat(frontend): TS types for the trace + load sample trace into a Zustand store" <<'EOF'
## Goal
The frontend can load your factorial trace and knows "the current step".

## Tasks
- [ ] TypeScript types mirroring `docs/trace-schema.md`
- [ ] Zustand store: `trace`, `currentStep`, `next()`, `prev()`, `goTo(n)` with bounds checks
- [ ] Load `factorial.trace.json` on startup
- [ ] Unit tests (Vitest) for the store's bounds behavior

## Done when
- [ ] Tests pass; stepping past the end does nothing weird
EOF

issue 3 1 "type: feature,area: frontend" "feat(frontend): Monaco editor with current-line highlight and step controls" <<'EOF'
## Goal
First visible magic: step through the factorial trace and watch the highlighted line move.

## Tasks
- [ ] Add Monaco (read-only for now) showing the trace's source code
- [ ] Highlight the current line via Monaco decorations
- [ ] Slider + Prev/Next buttons wired to the store
- [ ] Keyboard shortcuts: left/right arrows

## Done when
- [ ] Screen recording / GIF added to the PR description
EOF

# ============================ PHASE 2 =======================================
rough 4 2 "type: feature,area: frontend" "feat: run Pyodide in a Web Worker" "Load Pyodide off the main thread and execute Python without freezing the UI."
rough 4 2 "type: feature,area: tracer"   "feat: run the tracer inside Pyodide and return the trace" "Port tracer.py to run in the worker and send the trace to the UI. Handle load time with a clear loading state."
rough 5 2 "type: feature,area: frontend" "feat: call stack panel" "Render frames, function names and a recursion-friendly stack view that animates push/pop."
rough 5 2 "type: feature,area: frontend" "feat: variables panel per frame" "Show locals per frame, highlight what changed since the previous step."
rough 6 2 "type: feature,area: frontend" "feat: heap objects layout (lists, dicts, instances)" "Draw heap objects as boxes with an SVG layout; start with lists and dicts."
rough 6 2 "type: feature,area: frontend" "feat: pointer arrows between variables and heap objects" "SVG arrows from references to heap objects that update correctly on each step."
rough 7 2 "type: feature,area: frontend" "feat: linked lists and trees layout" "Auto-layout for node-like objects (use D3 for layout math, not rendering)."
rough 7 2 "type: feature,area: frontend" "feat: arrow animation and aliasing view" "Smooth transitions between steps; make aliasing (two refs, one object) obvious."
rough 8 2 "type: feature,area: frontend" "feat: editable code, Run button, error display" "Let users write their own code and see runtime errors nicely."
rough 8 2 "type: chore,area: frontend"   "chore: tests and bug-bash for single-player experience" "Component tests, an end-to-end smoke test (Playwright), and a list of known bugs."

# ============================ PHASE 3 =======================================
rough 9  3 "type: feature,area: backend" "feat: FastAPI project, database models, health endpoint" "Scaffold backend with SQLite locally; Pydantic models for a snippet."
rough 9  3 "type: feature,area: backend" "feat: POST/GET snippet endpoints with tests" "Save code (and optional trace) and fetch by id. pytest coverage."
rough 10 3 "type: feature,area: backend" "feat: short id generation and collision handling" "Generate URL-safe short ids; test collisions."
rough 10 3 "type: feature,area: frontend" "feat: /v/:id route that loads a shared visualization" "Client routing, loading and error states, Share button copies link."
rough 11 3 "type: feature,area: backend" "feat: input validation, size limits and rate limiting" "Protect the save endpoint from abuse."
rough 11 3 "type: feature,area: infra"   "feat: Open Graph preview cards for shared links" "So links look good when pasted in Discord/Slack."

# ============================ PHASE 4 =======================================
rough 12 4 "type: learning,area: collab" "learning: WebSocket fundamentals and room design" "Write a note on how WebSockets differ from HTTP and how rooms and presence work."
rough 12 4 "type: feature,area: backend"   "feat: WebSocket endpoint with rooms and join/leave events" "FastAPI WebSocket manager; broadcast within a room."
rough 13 4 "type: feature,area: collab"    "feat: presenter/follower role model" "One presenter controls the step, followers mirror it."
rough 13 4 "type: feature,area: frontend" "feat: live step sync and presence indicator" "Sync currentStep over WebSocket; show who is in the room."
rough 14 4 "type: learning,area: collab"   "learning: CRDTs and Yjs basics" "Why naive shared text editing breaks; what a CRDT guarantees."
rough 14 4 "type: feature,area: collab,stretch" "feat: Yjs shared document for the editor" "Bind Monaco to a Yjs doc and sync via the WebSocket server."
rough 15 4 "type: feature,area: collab,stretch" "feat: shared cursors and reconnect handling" "Cursors, reconnection, and conflict testing with two browsers."
rough 15 4 "type: chore,area: collab"       "chore: harden collaboration (tests, limits, edge cases)" "Room size limits, disconnect handling, test with 3 clients."

# ============================ PHASE 5 =======================================
rough 16 5 "type: feature,area: design" "feat: cyberpunk design tokens (colors, fonts, spacing)" "CSS variables, neon palette, typography system, dark base."
rough 16 5 "type: feature,area: design" "feat: glitch, scanline and glow effects (with reduced-motion support)" "Effects as reusable components; respect prefers-reduced-motion."
rough 17 5 "type: feature,area: design" "feat: responsive layout and mobile view" "Panels reflow on small screens."
rough 17 5 "type: chore,area: design"   "chore: accessibility pass (contrast, focus, keyboard)" "Neon themes often fail contrast; audit and fix."

# ============================ PHASE 6 =======================================
rough 18 6 "type: learning,area: tracer" "learning: options for tracing JavaScript" "Compare interpreter-based tracing vs instrumentation; decide and record an ADR."
rough 18 6 "type: feature,area: tracer"   "feat: JS tracer producing the same trace schema" "Minimal JS tracer for lines, calls, variables."
rough 19 6 "type: feature,area: tracer"   "feat: JS heap and closures support" "Objects, arrays, closures mapped into the schema."
rough 19 6 "type: chore,area: frontend"   "refactor: language plugin interface and language picker" "UI does not care which language produced the trace."

# ============================ PHASE 7 =======================================
rough 20 7 "type: chore,area: infra" "chore: deploy frontend and backend, configure domain" "Vercel + Fly.io/Railway, env vars, CORS, production DB."
rough 20 7 "type: docs"               "docs: README with GIF demo, architecture diagram and technical decisions" "The recruiter-facing front door."
rough 20 7 "type: docs"               "docs: write the project case study / portfolio post" "What we built, what was hard, what we would do next."

# --------------------------------------------------------------------- epics
echo; echo "== Epics =="
epic() { # phase title blurb
  local p="$1" title="$2" blurb="$3" tasks body
  tasks="$(cat "$TMP/phase-$p" 2>/dev/null || true)"
  body="$blurb

## Tasks
$tasks

_GitHub ticks these boxes automatically when the linked issues close._"
  if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] epic: $title"; return; fi
  local url
  url="$(gh issue create --title "$title" --body "$body" --label "type: epic")"
  echo "created epic: $title"
  echo "$url" >> "$TMP/urls"
}

epic 1 "Epic: Phase 1 - Foundations (Weeks 1-3)" "Schema, Python tracer, frontend skeleton."
epic 2 "Epic: Phase 2 - Core visuals (Weeks 4-8)" "Pyodide, call stack, variables, heap and pointers."
epic 3 "Epic: Phase 3 - Shareable links (Weeks 9-11)" "Backend, database, short ids, link previews."
epic 4 "Epic: Phase 4 - Live collaboration (Weeks 12-15)" "WebSockets, synced stepping, shared editing."
epic 5 "Epic: Phase 5 - Cyberpunk design system (Weeks 16-17)" "Visual identity, effects, responsive, accessibility."
epic 6 "Epic: Phase 6 - JavaScript support (Weeks 18-19)" "Second language behind a plugin interface."
epic 7 "Epic: Phase 7 - Ship (Week 20)" "Deploy, README, case study."

# ------------------------------------------------------------ projects board
if [ "$WITH_PROJECT" = "1" ] && [ "$DRY_RUN" != "1" ]; then
  echo; echo "== Project board =="
  OWNER="$(gh repo view --json owner --jq .owner.login)"
  NUM="$(gh project create --owner "$OWNER" --title "$PROJECT_TITLE" --format json \
        | python3 -c 'import sys, json; print(json.load(sys.stdin)["number"])')"
  while read -r url; do
    gh project item-add "$NUM" --owner "$OWNER" --url "$url" >/dev/null
  done < "$TMP/urls"
  echo "Board #$NUM created with all issues."
  echo "Add the Board and Roadmap views in the web UI (the CLI cannot create views yet)."
fi

echo; echo "Done. Next steps:"
echo "  1. Open the Issues tab and check milestones."
echo "  2. Start with Week 1, issue 1: branch -> PR -> squash merge."
