# Agent Roles and Responsibilities

This document clarifies the roles and responsibilities of different agents working on this monorepo.

## Monorepo Structure

This is a single monorepo containing two distinct components:
- `server/` – The ai-server component
- `client/` – The ai-client component

## Important: Single Implementation Plan

**Only ONE `IMPLEMENTATION_PLAN.md` exists** – at the root of the monorepo. Both server and client implementation should reference and update this single file.

Do not create separate implementation plans in the server or client directories.

## Agent Coordination

### When working on server (ai-server)
- Focus on specifications in `server/specs/`
- Implement server-side scripts in `server/scripts/`
- Maintain the API contract as documented in `client/specs/API_CONTRACT.md`
- Update root `IMPLEMENTATION_PLAN.md` for server progress
- Do not implement any client-specific functionality

### When working on client (ai-client)
- Focus on specifications in `client/specs/`
- Implement client-side scripts in `client/scripts/`
- Strictly adhere to the API contract in `client/specs/API_CONTRACT.md`
- Update root `IMPLEMENTATION_PLAN.md` for client progress
- Do not make assumptions about server internals beyond the API contract

### API Contract Ownership
- The server team owns the implementation of the contract
- The client team owns the consumption of the contract
- Changes to `client/specs/API_CONTRACT.md` require coordination between both teams
- The contract is the single source of truth for the interface between components

## References to Components

When writing specifications or documentation:
- Refer to components as "ai-server" and "ai-client" conceptually
- Actual folder paths use `server/` and `client/`
- Do not use terms like "ai-server project" or "ai-client repository" within the specs
- Simply say "server" or "client" when referring to the folders in this monorepo

## Workflow Guidelines

1. **Read specifications first** – All specs in the relevant `specs/` directory
2. **Reference the API contract** – Especially when working on integration points
3. **Update IMPLEMENTATION_PLAN.md** – Single file at root, not per-component files
4. **Maintain separation** – Server and client should remain independent except via the API contract
5. **Test integration** – Regularly test server-client interaction via the contract

## Environment Persistence

This project uses the persistent environment configured via `CLAUDE_ENV_FILE` (`/etc/sandbox-persistent.sh`).

- Environment variables stored in `/etc/sandbox-persistent.sh` persist across all bash invocations
- When using the Bash tool with newly installed tools (sdkman, nvm, etc.), use `bash -l -c "command"` to ensure environment is properly loaded
- See root `CLAUDE.md` for critical warnings about shell completions

## Critical Reminders

- **Never add shell completion scripts to `/etc/sandbox-persistent.sh`** – This will break the bash tool
- Only add core initialization scripts for tools (e.g., `nvm.sh`, `sdkman-init.sh`)
- Use login shells (`bash -l -c`) when tools modify PATH
