<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

**Last Updated**: 2026-02-10
**Current Version**: v0.0.4 (v1 complete, v2+ in progress)

This document tracks remaining implementation work for the ai-server and ai-client components. For detailed specifications, see `client/specs/*.md` and `server/specs/*.md`.

---

## Current Status

### ✅ v1 Implementation - COMPLETE

**Scope**: Aider integration (OpenAI API)

- **Scripts**: All 8 spec-required scripts implemented and tested
  - Server: `install.sh`, `uninstall.sh`, `test.sh`, `warm-models.sh`
  - Client: `install.sh`, `uninstall.sh`, `test.sh`, `config/env.template`
- **Testing**: Hardware testing complete (20 server tests + 28 client tests, all passing)
- **Documentation**: README.md, SETUP.md complete for both components
- **Spec Compliance**: Full compliance verified via 4-pass exhaustive audit

**Critical Bug Fixed (v0.0.4)**:
- `OLLAMA_API_BASE` incorrectly included `/v1` suffix, breaking Aider's access to Ollama native endpoints
- Root cause: Aider/LiteLLM uses both OpenAI-compatible endpoints (`/v1/*`) and Ollama native endpoints (`/api/*`)
- Fix: Separated `OLLAMA_API_BASE` (no suffix) from `OPENAI_API_BASE` (with `/v1` suffix)
- Lesson: End-to-end integration tests are mandatory; API endpoint tests alone are insufficient

### 🚧 v2+ Implementation - IN PROGRESS (7/22 items complete)

**Scope**: Claude Code integration (Anthropic API), version management, analytics

**Completed (Phase 1 - Foundations)**:
- ✅ H1-1: Client README.md corrected (removed premature v2+ feature claims)
- ✅ H1-2: Server SCRIPTS.md updated with `/v1/messages` test requirements
- ✅ H1-5: Anthropic env vars added to `client/config/env.template`
- ✅ H2-6: Client SCRIPTS.md updated with v2+ test requirements
- ✅ H3-4: Server SETUP.md documents Anthropic API
- ✅ H4-1: Internal documentation fixes (stale URL examples)
- ✅ H4-2: Server hostname default spec updated to match implementation

**Remaining Work**: See "v2+ Implementation Tasks" section below

---

## v2+ Implementation Tasks

### Phase 2: Core Implementation (4 items)

#### H1-3: Add /v1/messages tests to server/scripts/test.sh
- **Status**: ⬜ TODO
- **Priority**: H1 (critical - validates Anthropic API surface)
- **What**: Add 4-6 tests for `POST /v1/messages` endpoint (non-streaming, streaming SSE, system prompts, error handling)
- **Effort**: Medium (~80-120 lines)
- **Dependencies**: H1-2 (spec complete)
- **Bundle with**: H4-4 (fix `show_progress` function while modifying test.sh)

#### H1-4: Add Claude Code integration to client/scripts/install.sh
- **Status**: ⬜ TODO
- **Priority**: H1 (critical - primary v2+ entry point)
- **What**: Optional Claude Code setup section; prompts user, creates `claude-ollama` shell alias with marker comments
- **Effort**: Medium (~60-80 lines)
- **Dependencies**: H1-5 (complete)
- **Bundle with**: H1-6 (sync embedded env template)

#### H1-6: Sync install.sh embedded env template with canonical template
- **Status**: ⬜ TODO
- **Priority**: H1 (medium - curl-pipe install produces incomplete env file)
- **What**: Copy Anthropic variable comments from `env.template` to embedded template in `install.sh`
- **Effort**: Trivial (~4 lines)
- **Dependencies**: H1-5 (complete)
- **Bundle with**: H1-4

#### H2-1: Create client/scripts/check-compatibility.sh
- **Status**: ⬜ TODO
- **Priority**: H2 (important - enables safe Claude Code updates)
- **What**: Detects Claude Code + Ollama versions, checks compatibility matrix, reports status
- **Effort**: Medium (~100-150 lines)
- **Dependencies**: None
- **Spec**: `client/specs/VERSION_MANAGEMENT.md` lines 66-131
- **Auto-resolves**: H4-3 (ANALYTICS_README.md stale reference)

#### H2-2: Create client/scripts/pin-versions.sh
- **Status**: ⬜ TODO
- **Priority**: H2 (important - enables version stability)
- **What**: Detects versions, pins them (npm/brew), creates `~/.ai-client/.version-lock`
- **Effort**: Medium (~80-120 lines)
- **Dependencies**: None
- **Spec**: `client/specs/VERSION_MANAGEMENT.md` lines 133-178

### Phase 3: Dependent Implementation (3 items)

#### H2-3: Create client/scripts/downgrade-claude.sh
- **Status**: ⬜ TODO
- **Priority**: H2 (important - recovery from breaking updates)
- **What**: Reads `.version-lock`, downgrades Claude Code to recorded version
- **Effort**: Small-medium (~60-100 lines)
- **Dependencies**: H2-2 (requires .version-lock file format)
- **Spec**: `client/specs/VERSION_MANAGEMENT.md` lines 180-226

#### H2-4: Add v2+ cleanup to client/scripts/uninstall.sh
- **Status**: ⬜ TODO
- **Priority**: H2 (must reverse H1-4)
- **What**: Remove `claude-ollama` alias markers from shell profile
- **Effort**: Small (~15-25 lines)
- **Dependencies**: H1-4 (must know what to reverse)

#### H2-5: Add v2+ tests to client/scripts/test.sh
- **Status**: ⬜ TODO
- **Priority**: H2 (validates all v2+ functionality)
- **What**: 8-10 new tests (Claude Code binary, alias, `/v1/messages` connectivity, version scripts, .version-lock format)
- **Effort**: Medium (~150-200 lines)
- **Dependencies**: H2-6 (spec complete), H1-3, H1-4, H2-1, H2-2, H2-3
- **Flags**: Add `--skip-claude`, `--v1-only`, `--v2-only`

### Phase 4: Validation and Polish (5 items)

#### H3-1: Fix analytics bugs and implement missing spec features
- **Status**: ⬜ TODO
- **Priority**: H3 (nice-to-have - analytics partially working)
- **What**:
  1. Fix divide-by-zero in `loop-with-analytics.sh` (line 494) and `compare-analytics.sh` (lines 88-104)
  2. Implement decision matrix output per `client/specs/ANALYTICS.md` lines 474-485
  3. Fix per-iteration cache hit rate formula (line 268) - should be `cache_read * 100 / (cache_creation + cache_read)`
- **Effort**: Medium (bug fixes small, decision matrix requires new logic)
- **Dependencies**: None
- **Bundle with**: H3-6

#### H3-2: Hardware testing for v2+ features
- **Status**: ⬜ TODO
- **Priority**: H3 (required before v2+ release)
- **What**:
  1. Run `server/scripts/test.sh --verbose` (with Anthropic tests)
  2. Run `client/scripts/test.sh --verbose` (with v2+ tests)
  3. Manual: `claude-ollama --model <model> -p "Hello"`
  4. Test version management scripts
- **Effort**: Large (requires hardware access)
- **Dependencies**: All H1 and H2 items complete

#### H3-3: Update server/README.md to document Anthropic API testing
- **Status**: ⬜ TODO
- **Priority**: H3 (documentation polish)
- **What**: Add sample Anthropic test output, new test count, `--skip-anthropic-tests` flag docs
- **Effort**: Trivial
- **Dependencies**: H1-3, H3-2

#### H3-5: Update client/SETUP.md to document v2+ features
- **Status**: ⬜ TODO
- **Priority**: H3 (documentation gap)
- **What**: Add Claude Code integration section, version management quick-start, analytics overview
- **Effort**: Small
- **Dependencies**: H1-4, H2-1, H2-2, H2-3

#### H3-6: Fix per-iteration cache hit rate formula
- **Status**: ⬜ TODO (bundled with H3-1)
- **Priority**: H3 (correctness issue)
- **What**: Change formula from `cache_read * 100 / total_input` to `cache_read * 100 / (cache_creation + cache_read)`
- **Effort**: Trivial
- **Bundle with**: H3-1

#### H4-4: Fix server test.sh show_progress function never called
- **Status**: ⬜ TODO (bundled with H1-3)
- **Priority**: H4 (cosmetic - tests work, but progress not shown)
- **What**: Add `show_progress` calls before each test
- **Effort**: Small (~20 function calls)
- **Bundle with**: H1-3

---

## Dependency Graph

```
Phase 1 (COMPLETE):
H1-1, H1-2, H1-5, H2-6, H3-4, H4-1, H4-2 ──── ✅ ALL DONE

Phase 2 (Core Implementation):
H1-3 + H4-4 ──── depends on H1-2 ✅
H1-4 + H1-6 ──── depends on H1-5 ✅
H2-1 ──────────── standalone
H2-2 ──────────── standalone

Phase 3 (Dependent Implementation):
H2-3 ──────────── depends on H2-2
H2-4 ──────────── depends on H1-4
H2-5 ──────────── depends on H2-6 ✅, H1-3, H1-4, H2-1, H2-2, H2-3

Phase 4 (Validation and Polish):
H3-1 + H3-6 ──── standalone
H3-2 ──────────── depends on all H1 + H2
H3-3 ──────────── depends on H1-3, H3-2
H3-5 ──────────── depends on H1-4, H2-1, H2-2, H2-3
```

## Recommended Execution Order

**Phase 2**: (partially parallelizable)
1. H1-3 + H4-4 — Server Anthropic tests + progress fixes
2. H1-4 + H1-6 — Client Claude Code install + template sync
3. H2-1 — check-compatibility.sh (parallel with 1-2)
4. H2-2 — pin-versions.sh (parallel with 1-2)

**Phase 3**: (sequential)
5. H2-3 — downgrade-claude.sh (after H2-2)
6. H2-4 — Uninstall v2+ cleanup (after H1-4)
7. H2-5 — Client v2+ tests (after all scripts exist)

**Phase 4**: (polish)
8. H3-1 + H3-6 — Analytics fixes
9. H3-2 — Hardware testing (after all H1/H2 complete)
10. H3-3 — Server README update (after H3-2)
11. H3-5 — Client SETUP update (after scripts exist)

---

## Effort Summary

**Total remaining**: 15 items across 3 phases

| Priority | Item | Effort | Files |
|----------|------|--------|-------|
| H1-3 | Server Anthropic tests | Medium | `server/scripts/test.sh` |
| H1-4 | Client Claude install | Medium | `client/scripts/install.sh` |
| H1-6 | Template sync | Trivial | `client/scripts/install.sh` |
| H2-1 | check-compatibility.sh | Medium | New file |
| H2-2 | pin-versions.sh | Medium | New file |
| H2-3 | downgrade-claude.sh | Small-medium | New file |
| H2-4 | Uninstall v2+ | Small | `client/scripts/uninstall.sh` |
| H2-5 | Client v2+ tests | Medium | `client/scripts/test.sh` |
| H3-1 | Analytics fixes | Medium | `loop-with-analytics.sh`, `compare-analytics.sh` |
| H3-2 | Hardware testing | Large | Manual testing |
| H3-3 | Server README | Trivial | `server/README.md` |
| H3-5 | Client SETUP | Small | `client/SETUP.md` |
| H3-6 | Cache formula fix | Trivial | Bundled with H3-1 |
| H4-4 | show_progress fix | Small | Bundled with H1-3 |

**New files**: 3 (`check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh`)
**Modified files**: ~10 existing files
**Total estimated effort**: 5-7 days focused development + hardware testing

---

## Implementation Constraints

These constraints apply to ALL implementation work:

1. **Security**: No public internet exposure. Tailscale-only. No built-in auth.
2. **API contract**: `client/specs/API_CONTRACT.md` is the single source of truth for server-client interface.
3. **Independence**: Server and client remain independent except via the API contract.
4. **Idempotency**: All scripts must be safe to re-run without breaking existing setup.
5. **No stubs**: Implement completely or not at all. No TODO/FIXME/HACK markers in production code.
6. **macOS only**: Server requires Apple Silicon. Client requires macOS 14+ Sonoma.
7. **Aider is the v1 interface**: But env var setup ensures any OpenAI-compatible tool works.
8. **Claude Code integration is OPTIONAL**: Always prompt for user consent. Anthropic cloud is the default; Ollama is an alternative, not a replacement.
9. **curl-pipe install support**: Client install.sh must work when executed via `curl | bash`.

---

## Critical Lessons Learned (v0.0.3 Bug)

**Context**: All 47 automated tests passed, but first real Aider usage failed immediately.

**Root Cause**: `OLLAMA_API_BASE` set to `http://hostname:11434/v1` caused Aider/LiteLLM to construct invalid URLs like `http://hostname:11434/v1/api/show` when accessing Ollama native endpoints.

**Why Tests Missed It**:
- Tests validated OpenAI endpoints (`/v1/models`, `/v1/chat/completions`) ✅
- Tests validated Aider binary installation ✅
- Tests validated environment variables were set ✅
- Tests did NOT validate end-to-end tool usage with real prompts ❌

**Lesson**: Component tests are insufficient. **End-to-end integration tests with actual tools are mandatory**, not just API endpoint validation with curl.

**Applied Fix**: Added Test 26 to `client/scripts/test.sh` - non-interactive Aider invocation that validates the complete integration chain.

**Technical Detail**: Ollama serves two API surfaces:
1. OpenAI-compatible: `/v1/chat/completions`, `/v1/models` (requires `/v1` prefix)
2. Ollama native: `/api/show`, `/api/tags`, `/api/chat` (requires NO prefix)

Tools like Aider/LiteLLM use BOTH. Solution: Separate `OLLAMA_API_BASE` (no suffix) from `OPENAI_API_BASE` (with `/v1` suffix).

---

## Spec Baseline

All implementation must comply with specifications in:
- `server/specs/*.md` (7 files: ARCHITECTURE, FILES, FUNCTIONALITIES, INTERFACES, REQUIREMENTS, SCRIPTS, SECURITY, ANTHROPIC_COMPATIBILITY)
- `client/specs/*.md` (6 files: ANALYTICS, API_CONTRACT, ARCHITECTURE, CLAUDE_CODE, FILES, FUNCTIONALITIES, REQUIREMENTS, SCRIPTS, VERSION_MANAGEMENT)

Specs are the authoritative source. When implementation deviates from specs, implementation must be corrected unless there is a compelling reason to update the spec instead.
