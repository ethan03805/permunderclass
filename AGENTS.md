# AGENTS.md

## Current state
- This repository has no verified project files or toolchain config yet. Treat it as uninitialized until real manifests, source files, or CI config appear.

## Working rules
- Do not assume a framework, language, package manager, or deploy target.
- Do not invent `dev`, `build`, `lint`, `typecheck`, or `test` commands; none are currently defined.
- Before scaffolding, adding lockfiles, or creating a project structure, confirm the intended stack with the user.
- If more files are added later, re-scan root manifests, lockfiles, workflows, and local instruction files first. Concrete config (for example `package.json`, `pyproject.toml`, or CI YAML) takes precedence over this file if they diverge.
