# Dunk Simulator Development Guide

## Before You Edit

- Read the relevant files in `README.md` and `docs/` before modifying the project.
- Identify the server, client, and shared files involved in a feature before editing.
- Follow the boundaries documented in `docs/ARCHITECTURE.md`.
- Do not implement gameplay outside the requested scope.

## Engineering Rules

- Keep currency, progression, rewards, purchases, and competitive results server-authoritative.
- Treat all client input as untrusted and validate it on the server.
- Keep systems modular with focused services and modules; avoid giant scripts.
- Keep configuration separate from gameplay logic.
- Use clear, beginner-readable Luau because the project owner is learning Roblox development.
- Do not introduce dependencies unless they are necessary and approved by the project needs.
- Do not rewrite, reformat, or remove unrelated files.

## Changes and Validation

- Explain significant architectural changes and update the relevant documentation.
- Run available validation, tests, formatting, or build checks after changes when appropriate.
- Report the files changed and the validation performed in each handoff.
- Do not commit, push, or change repository history unless explicitly asked.
