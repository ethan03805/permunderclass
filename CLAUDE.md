# CLAUDE.md

## Source of Truth

1. `PLAN.md` is the product, architecture, delivery, and execution source of truth for this repository.
2. Read `PLAN.md` at the start of every session before making changes.
3. Do not change `PLAN.md` as part of routine implementation work.
4. Only modify `PLAN.md` when the user explicitly requests a plan change.
5. If the codebase diverges materially from `PLAN.md`, stop and ask the user before changing code or plan.

## Current State

1. This repository is no longer stack-agnostic.
2. The stack is fixed by `PLAN.md`:
   1. Rails 8
   2. Ruby 3.3
   3. PostgreSQL 16
   4. Hotwire
   5. Cloudflare for DNS, proxy, Turnstile, and R2
   6. Render for hosting
   7. Resend for transactional email
3. Browsing is anonymous.
4. Posting, commenting, and voting require an account.
5. UI copy is intentionally generic for now.

## Working Rules

1. Follow the build order and work packages in `PLAN.md`.
2. Prefer the smallest correct change that advances the current package.
3. Do not add features excluded by `PLAN.md`.
4. Do not add social login, magic links, passkeys, DMs, search, badges, leaderboards, monetization, or tracking scripts unless the user explicitly changes the plan.
5. Do not add component libraries or UI kits.
6. Keep the UI restrained and text-first.
7. All user-facing strings should come from locale files, not hardcoded strings.
8. Do not invent repository commands once wrapper commands exist.
9. Prefer these wrappers when present:
   1. `bin/setup`
   2. `bin/dev`
   3. `bin/test`
   4. `bin/lint`
   5. `bin/security`
   6. `bin/worker`
   7. `bin/render-release`

## Documentation And Verification

1. Every completed task must be documented in the `docs/` directory.
2. Task documentation must describe:
   1. what changed
   2. which files were added or modified
   3. how the change was verified
   4. any follow-up work or known limitations
3. The top-level orchestrator agent must verify each task after subagents complete work. Do not assume subagent output is correct without review.
4. The highest priority is that the code works together as a coherent application. Avoid isolated changes that compile individually but do not integrate cleanly.
5. Before adding new helpers, services, controllers, or commands, inspect the existing codebase and reuse or extend current implementations when possible instead of duplicating functionality.
6. When delegating to subagents, provide enough repository context, package boundaries, and existing-file references to prevent duplicate or conflicting implementations.

## Stop And Ask User

Agents must stop and ask the user before doing any of the following:
1. creating or logging into vendor accounts
2. changing DNS or nameservers
3. using Cloudflare, Render, Vercel, or Resend dashboards
4. entering, generating, rotating, or storing production secrets
5. adding billing details or enabling paid infrastructure
6. choosing the initial public tag seed list
7. choosing the first moderator or admin account
8. changing product scope, ranking rules, or moderation rules defined in `PLAN.md`

## Implementation Guidance

1. Treat each work package in `PLAN.md` as a bounded unit of work.
2. If a task does not clearly map to a package, ask the user before proceeding.
3. When orchestrating multiple agents, split work only along package boundaries or clearly independent sub-parts of the same package.
4. Finish verification for the current package before jumping to a later package.
5. If the user asks for implementation, proceed package by package and keep outputs aligned with `PLAN.md`.
6. Before assigning a subagent, first review the relevant files yourself and pass the subagent the exact context it needs, including existing entry points, naming, and constraints.
7. After any subagent writes code, review the resulting integration points yourself and run the relevant verification commands before marking the task complete.

## File Precedence

1. `PLAN.md` controls product scope, architecture, behavior, and delivery order.
2. Concrete manifests and checked-in config control exact command syntax and file layout once they exist.
3. If a manifest or implementation detail appears to conflict with `PLAN.md`, do not assume the manifest is correct. Stop and ask the user.

## Prohibited Shortcuts

1. Do not skip validation or moderation rules because they seem inconvenient.
2. Do not add placeholder analytics scripts.
3. Do not add hidden gamification fields to the user model.
4. Do not quietly loosen media constraints.
5. Do not replace the stack with a JS framework or serverless stack.
6. Do not turn generic copy into branded voice without user approval.
