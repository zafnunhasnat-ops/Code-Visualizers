# How we work

## Loop
Issue -> branch -> small commits -> PR (`Closes #N`) -> read your own diff -> squash merge.

## Issue size
1-3 hours. Bigger? Split it.

## Branch names
`<type>/<issue-number>-<short-name>`, e.g. `feat/12-python-tracer`.
Types: `feat`, `fix`, `chore`, `docs`, `test`, `refactor`.

## Commit messages (Conventional Commits)
`type(scope): summary in the imperative`
e.g. `feat(tracer): record call stack on each line event`

## PRs
- One issue per PR, with `Closes #N` in the description
- CI must pass (from Week 3)
- Squash merge only; the PR title becomes the commit message, so write it well

## Notes
Learning issues produce a file in `docs/notes/`. Decisions that were hard to make go in `docs/decisions/` as short ADRs.
