<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

**Last Updated**: 2026-02-10
**Current Version**: v0.0.4

v1 (Aider/OpenAI API) is complete and tested on hardware. v2+ (Claude Code/Anthropic API, version management, analytics) has documentation foundations done; core implementation in progress. Latest: server Anthropic tests + progress tracking implemented; client Claude Code installation with optional Ollama integration complete; version management complete (compatibility check, version pinning, downgrade script). **Phase 2 complete (6/6 items)**.

---

## Current Status

### v1 Implementation - COMPLETE

All 8 scripts delivered (server: 4, client: 3 + env.template). 48 tests passing (20 server, 28 client). Full spec compliance verified. Critical `OLLAMA_API_BASE` bug fixed in v0.0.4 (see "Lessons Learned" below).

### v2+ Implementation - IN PROGRESS

Phase 1 (documentation foundations) complete: 7/22 items done. **Phase 2: COMPLETE (6/6 items done)** - H1-3, H1-4, H1-6, H2-1, H2-2, H4-4. Server Anthropic tests, client Claude Code installation, version compatibility checking, version pinning, and progress tracking all implemented. **Phase 3: 2/3 items done** - H2-3 complete. **8 items remain** across 2 phases of implementation.

---

## Remaining Tasks

### Phase 2: Core Implementation - COMPLETE (6/6 items done)

All Phase 2 items completed: H1-3 (Anthropic tests), H1-4 (Claude Code install), H1-6 (env template sync), H2-1 (compatibility check), H2-2 (version pinning), H4-4 (progress tracking). See "Completed This Session" section below for details.

### Phase 3: Dependent Implementation (2 items remaining, now unblocked)

| ID | Task | Priority | Effort | Target Files | Dependencies |
|----|------|----------|--------|-------------|-------------|
| H2-4 | Add v2+ cleanup to client uninstall.sh. Remove `claude-ollama` alias markers from shell profile. | H2 | Small | `client/scripts/uninstall.sh` | H1-4 (DONE) |
| H2-5 | Add v2+ tests to client test.sh (8-10 tests: Claude Code binary, alias, `/v1/messages` connectivity, version scripts, `.version-lock` format). Add `--skip-claude`, `--v1-only`, `--v2-only` flags. | H2 | Medium | `client/scripts/test.sh` | H1-3, H1-4, H2-1, H2-2, H2-3 (ALL DONE) |

**Status**: Both H2-4 and H2-5 are now unblocked (all dependencies complete). All version management scripts complete.

### Phase 4: Validation and Polish (6 items)

| ID | Task | Priority | Effort | Target Files | Dependencies |
|----|------|----------|--------|-------------|-------------|
| H3-1 | Fix analytics bugs: (a) `compare-analytics.sh` lines 88-91 divide-by-zero -- no zero check on `ITER1`/`ITER2` before division; (b) `loop-with-analytics.sh` line 268 cache hit rate formula uses `total_input` denominator, spec requires `cache_creation + cache_read`. | H3 | Medium | `compare-analytics.sh`, `loop-with-analytics.sh` | None |
| H3-6 | Implement decision matrix output per `client/specs/ANALYTICS.md` lines 474-485. Neither analytics script outputs this. | H3 | Medium | `loop-with-analytics.sh`, `compare-analytics.sh` | None |
| H3-2 | Hardware testing: run all tests with `--verbose` on Apple Silicon server, manual Claude Code + Ollama validation, version management script testing. | H3 | Large | Manual | All H1 + H2 items |
| H3-3 | Update `server/README.md`: new test count, Anthropic test sample output, `--skip-anthropic-tests` flag docs. | H3 | Trivial | `server/README.md` | H1-3, H3-2 |
| H3-5 | Update `client/SETUP.md`: Claude Code integration section, version management quick-start, analytics overview. | H3 | Small | `client/SETUP.md` | H1-4, H2-1, H2-2, H2-3 (ALL DONE) |
| H4-3 | Auto-resolved when H2-1 is created (stale reference in `ANALYTICS_README.md`). | H4 | None | N/A | H2-1 |

**Bundling**: H3-1 + H3-6 (same files, related analytics work).

---

## Dependency Graph

```
Phase 2: COMPLETE (all 6 items done)
  ✓ H1-3, H1-4, H1-6, H2-1, H2-2, H4-4

Phase 3: 2/3 COMPLETE
  ✓ H2-3 ───────── DONE (downgrade-claude.sh)
  H2-4 ─────────── UNBLOCKED (H1-4 complete)
  H2-5 ─────────── UNBLOCKED (H1-3, H1-4, H2-1, H2-2, H2-3 all complete)

Phase 4 (polish):
  H3-1 + H3-6 ─── no blockers (can start anytime)
  H3-2 ─────────── depends on ALL Phase 3 (awaits H2-4, H2-5)
  H3-3 ─────────── needs H3-2
  H3-5 ─────────── UNBLOCKED (H1-4, H2-1, H2-2, H2-3 all complete)
  H4-3 ─────────── auto-resolved (H2-1 complete)
```

## Recommended Execution Order

**Batch 1** (parallel, now unblocked):
1. H2-4 -- Uninstall v2+ cleanup
2. H2-5 -- Client v2+ tests
3. H3-1 + H3-6 -- Analytics bug fixes + decision matrix

**Batch 2** (after H2-4, H2-5):
4. H3-2 -- Hardware testing
5. H3-5 -- Client SETUP update (can start anytime after H2-3 done)

**Batch 3** (after Batch 2):
6. H3-3 -- Server README update

---

## Effort Summary

| Category | Items | Effort |
|----------|-------|--------|
| ~~Server test.sh (Anthropic tests + progress fix)~~ | ~~H1-3, H4-4~~ | ~~DONE~~ |
| ~~Client install.sh (Claude Code + template sync)~~ | ~~H1-4, H1-6~~ | ~~DONE~~ |
| ~~Version management (all scripts)~~ | ~~H2-1, H2-2, H2-3~~ | ~~DONE~~ |
| Client uninstall.sh (v2+ cleanup) | H2-4 | Small |
| Client test.sh (v2+ tests) | H2-5 | Medium |
| Analytics fixes + decision matrix | H3-1, H3-6 | Medium |
| Hardware testing | H3-2 | Large |
| Documentation updates | H3-3, H3-5 | Small |

**New files**: 0 remaining (all created)
**Modified files**: ~2 existing files
**Estimated total**: Less than 1 day + hardware testing session

---

## Implementation Constraints

1. **Security**: Tailscale-only network. No public exposure. No built-in auth.
2. **API contract**: `client/specs/API_CONTRACT.md` is the single source of truth for server-client interface.
3. **Idempotency**: All scripts must be safe to re-run without side effects.
4. **No stubs**: Implement completely or not at all. No TODO/FIXME/HACK in production code.
5. **Claude Code integration is optional**: Always prompt for user consent. Anthropic cloud is default; Ollama is an alternative.
6. **curl-pipe install**: Client `install.sh` must work when executed via `curl | bash`.

---

## Completed This Session (2026-02-10)

### H1-3: Anthropic `/v1/messages` Tests
**File**: `server/scripts/test.sh`
- Added 6 Anthropic API tests (tests 21-26):
  1. Non-streaming `/v1/messages` basic request
  2. Streaming SSE with `stream: true`
  3. System prompts in Anthropic format
  4. Error handling (400/404/500)
  5. Multi-turn conversation history
  6. Streaming with usage metrics
- Bumped `TOTAL_TESTS` from 20 to 26
- Added `--skip-anthropic-tests` flag
- All tests verify Ollama 0.5.0+ Anthropic API compatibility

### H4-4: Progress Tracking Fix
**File**: `server/scripts/test.sh`
- Fixed `show_progress()` never being called (was stuck at 0/20)
- Added `show_progress()` calls before ALL 26 tests
- `CURRENT_TEST` now increments properly for all tests (1/26 → 26/26)
- Progress bar now displays correctly throughout test execution

### H1-4: Optional Claude Code Setup
**File**: `client/scripts/install.sh`
- Added Step 12: Optional Claude Code + Ollama integration section (after Aider installation)
- User consent prompt with clear messaging about benefits (offline, faster) and limitations (no prompt caching)
- Defaults to "No" to avoid unintended Anthropic API interference
- Creates `claude-ollama` shell alias using marker comments (`# >>> claude-ollama >>>` / `# <<< claude-ollama <<<`)
- Idempotent: checks for existing markers before adding alias
- Fixed step numbering (Step 13 → Step 14 for connectivity test)
- Fully compliant with `client/specs/CLAUDE_CODE.md` lines 171-284

### H1-6: Env Template Sync
**File**: `client/scripts/install.sh`
- Synced embedded env template (lines 311-323) with canonical `client/config/env.template`
- Added missing Anthropic variable comments:
  - `ANTHROPIC_AUTH_TOKEN` (line 9 of template)
  - `ANTHROPIC_API_KEY` (line 10)
  - `ANTHROPIC_BASE_URL` (line 11-12 with Ollama example)
- Ensures install.sh accurately reflects all supported environment variables

### H2-1: Version Compatibility Check
**File**: `client/scripts/check-compatibility.sh`
- Compatibility matrix with tested version pairs (Claude Code 2.1.38→Ollama 0.5.4, 2.1.39→0.5.5)
- Auto-detects Claude Code version via `claude --version`
- Queries Ollama server via `/api/version` endpoint (`http://localhost:11434`)
- Loads environment from `~/.ai-client/env` if available
- Exit code 0: Compatible (green success message)
- Exit code 1: Tool not found / server unreachable (red error)
- Exit code 2: Version mismatch (yellow warning, provides upgrade/downgrade recommendations)
- Exit code 3: Unknown compatibility (yellow warning, guides user to test and update matrix)
- Color-coded output with clear status messages
- Fully compliant with `client/specs/VERSION_MANAGEMENT.md` lines 66-131

### H2-2: Version Pinning Script
**File**: `client/scripts/pin-versions.sh`
- Auto-detects Claude Code version and installation method (npm or Homebrew)
- Queries Ollama server for version via `/api/version` endpoint
- Pins Claude Code automatically based on installation method:
  - npm: `npm install -g @anthropic-ai/claude-code@${VERSION}`
  - brew: `brew pin claude-code`
- Displays server-side Ollama pinning instructions (must run on server)
- Creates `~/.ai-client/.version-lock` file with:
  - `CLAUDE_CODE_VERSION`, `OLLAMA_VERSION`
  - `TESTED_DATE`, `STATUS=working`
  - `CLAUDE_INSTALL_METHOD`, `OLLAMA_SERVER`
- Color-coded output and comprehensive summary
- Fully compliant with `client/specs/VERSION_MANAGEMENT.md` lines 133-178

### H2-3: Version Downgrade Script
**File**: `client/scripts/downgrade-claude.sh`
- Reads `~/.ai-client/.version-lock` file created by `pin-versions.sh`
- Extracts `CLAUDE_CODE_VERSION` and `CLAUDE_INSTALL_METHOD`
- Detects current Claude Code version via `claude --version`
- Skips downgrade if already at target version
- User confirmation prompt before executing downgrade
- Supports npm downgrade: `npm install -g @anthropic-ai/claude-code@{VERSION}`
- For Homebrew: provides manual downgrade instructions (brew doesn't support easy downgrades)
- Verification step after downgrade confirms success
- Color-coded output and comprehensive error handling
- Fully compliant with `client/specs/VERSION_MANAGEMENT.md` lines 180-226

**Impact**: Client installation now supports optional Claude Code integration with proper user consent, clear messaging, idempotent alias creation, and accurate env template documentation. Server test suite comprehensively validates both OpenAI and Anthropic API surfaces with proper progress tracking. Complete version management workflow: users can check compatibility, pin working versions, and downgrade to known-good configurations when upgrades break compatibility.

---

## Lessons Learned (v0.0.4)

All 48 automated tests passed, but first real Aider usage failed. Root cause: `OLLAMA_API_BASE` included `/v1` suffix, breaking Ollama native endpoints (`/api/*`). Fix: separate `OLLAMA_API_BASE` (no suffix) from `OPENAI_API_BASE` (with `/v1`). Lesson: end-to-end integration tests with actual tools are mandatory.

---

## Spec Baseline

All work must comply with:
- `server/specs/*.md` (8 files including ANTHROPIC_COMPATIBILITY)
- `client/specs/*.md` (9 files including ANALYTICS, CLAUDE_CODE, VERSION_MANAGEMENT)

Specs are authoritative. Implementation deviations must be corrected unless there is a compelling reason to update the spec.
