<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

**Last Updated**: 2026-02-11

---

## Current Status

**Client**: Fully spec-compliant. All 6 scripts, env.template, and SETUP.md match specs. 40 tests passing. One documentation-only gap (README.md still says v2+ is "planned").

**Root Analytics**: Fully spec-compliant. loop.sh, loop-with-analytics.sh, compare-analytics.sh, and ANALYTICS_README.md all match ANALYTICS.md spec.

**Server**: Partially implemented. Ollama API surface works (OpenAI + Anthropic endpoints, 26 tests). **Major gap**: The HAProxy proxy layer specified in ARCHITECTURE.md, SECURITY.md, INTERFACES.md, FILES.md, and FUNCTIONALITIES.md is entirely missing. Ollama binds to `0.0.0.0` (all interfaces) instead of the specified `127.0.0.1` (loopback only).

**Architecture gap**:
```
Current:   Client → Tailscale → Ollama (0.0.0.0:11434)
Specified: Client → Tailscale → HAProxy (100.x.x.x:11434) → Ollama (127.0.0.1:11434)
```

---

## Remaining Tasks

### P1: Align SCRIPTS.md Spec with Security Architecture

**File**: `server/specs/SCRIPTS.md`
**Effort**: Small
**Dependencies**: None (gates all P2 tasks)

SCRIPTS.md says `OLLAMA_HOST=0.0.0.0` in 3 places (install.sh spec, Security Tests, No config files section). All 5 other spec files consistently specify `127.0.0.1`. Align SCRIPTS.md with the security architecture:

- Change `OLLAMA_HOST=0.0.0.0` to `OLLAMA_HOST=127.0.0.1` throughout
- Add HAProxy installation section (consent prompt, Homebrew install, config generation, plist creation, service loading)
- Add HAProxy uninstallation section (stop service, remove plist, delete config dir, clean logs)
- Add HAProxy test specifications (service loaded, Tailscale interface listening, allowlist enforcement, direct Ollama access blocked)
- Update Security Tests section to verify loopback binding instead of all-interfaces binding
- Update "No config files" section to reflect HAProxy config existence

### P2: Implement HAProxy in Server Scripts

Three script changes, ordered by dependency. Refer to specs for exact requirements.

#### P2a: Add HAProxy to install.sh

**File**: `server/scripts/install.sh`
**Effort**: Large
**Dependencies**: P1

Implement the HAProxy installation flow per FUNCTIONALITIES.md and FILES.md:

1. **User consent prompt** — "Install HAProxy proxy? (Y/n)" with benefits/tradeoffs explanation. Default: Yes.
2. **HAProxy installation** — `brew install haproxy` (with Homebrew noise suppression)
3. **Config generation** — Create `~/.haproxy/haproxy.cfg` with:
   - Frontend listening on Tailscale interface (`100.x.x.x:11434`, detected via `tailscale ip -4`)
   - Backend forwarding to `127.0.0.1:11434`
   - Endpoint allowlist (see FILES.md for exact paths: OpenAI, Anthropic, and safe Ollama native endpoints)
   - Default deny for all other paths
4. **Plist creation** — Create `~/Library/LaunchAgents/com.haproxy.plist` with RunAtLoad, KeepAlive
5. **Ollama binding change** — Set `OLLAMA_HOST=127.0.0.1` in Ollama plist (currently `0.0.0.0`)
6. **Service loading** — Load both LaunchAgents via `launchctl bootstrap`
7. **Verification** — Confirm HAProxy listening on Tailscale interface, Ollama on loopback only, proxy forwarding works

If user declines HAProxy, fall back to current behavior (`OLLAMA_HOST=0.0.0.0`, no proxy).

#### P2b: Add HAProxy Cleanup to uninstall.sh

**File**: `server/scripts/uninstall.sh`
**Effort**: Small
**Dependencies**: P1

Add 3 missing cleanup operations per FILES.md:

1. Stop and remove `~/Library/LaunchAgents/com.haproxy.plist` via `launchctl bootout`
2. Delete `~/.haproxy/` directory (contains haproxy.cfg)
3. Clean up `/tmp/haproxy.log`

Handle gracefully if HAProxy was never installed (no errors on missing files).

#### P2c: Add HAProxy Tests to test.sh

**File**: `server/scripts/test.sh`
**Effort**: Medium
**Dependencies**: P2a

Update existing tests and add new HAProxy-specific tests per FUNCTIONALITIES.md:

**Modify existing tests**:
- Update binding verification to check `OLLAMA_HOST=127.0.0.1` (currently checks `0.0.0.0`)
- Update network test to verify loopback-only binding via `lsof`

**Add new tests**:
- HAProxy LaunchAgent loaded (`launchctl list | grep com.haproxy`)
- HAProxy listening on Tailscale interface
- Endpoint allowlist enforcement: blocked paths (e.g., `/api/pull`, `/api/delete`) return 403 or connection refused
- Direct Ollama access from Tailscale IP blocked (loopback isolation verified)

Skip HAProxy tests gracefully if HAProxy was not installed (user declined during install).

### P3: Documentation Updates

#### P3a: Update client/README.md

**File**: `client/README.md`
**Effort**: Small
**Dependencies**: None

Multiple sections describe v2+ (Claude Code, Anthropic API, version management, analytics) as "planned" or "not yet implemented." All v2+ features are fully implemented and tested. Update to reflect current reality.

#### P3b: Add Root-Level Scripts to client/specs/SCRIPTS.md

**File**: `client/specs/SCRIPTS.md`
**Effort**: Small
**Dependencies**: None

Formally specify `loop.sh`, `loop-with-analytics.sh`, and `compare-analytics.sh`. These are already implemented and documented in ANALYTICS_README.md per the ANALYTICS.md spec, but not mentioned in the SCRIPTS.md spec.

#### P3c: Update Server Documentation Post-HAProxy

**Files**: `server/README.md`, `server/SETUP.md`
**Effort**: Small
**Dependencies**: P2a

Both files already describe the HAProxy architecture (written for the spec). After implementation, verify documentation accuracy and update test counts if new HAProxy tests changed totals.

### P4: Hardware Validation

**Effort**: Medium
**Dependencies**: P2a, P2c (for HAProxy tests); independent for existing tests

Run full test suites on Apple Silicon server hardware:

1. Server tests (`server/scripts/test.sh --verbose`) — including new HAProxy tests
2. Client tests (`client/scripts/test.sh --verbose`)
3. Manual Claude Code + Ollama integration validation
4. Version management script validation (check-compatibility.sh, pin-versions.sh, downgrade-claude.sh)
5. Analytics infrastructure validation (loop-with-analytics.sh, compare-analytics.sh)

All bug fixes from previous sessions are applied. Expecting clean test runs.

---

## Dependency Graph

```
P1 (SCRIPTS.md spec alignment)
 ├── P2a (install.sh HAProxy) ─── requires P1
 │    ├── P2c (test.sh HAProxy tests) ─── requires P2a
 │    └── P3c (server docs update) ─── requires P2a
 └── P2b (uninstall.sh cleanup) ─── requires P1

P3a (client README) ─── independent
P3b (client SCRIPTS.md spec) ─── independent

P4 (hardware validation) ─── requires P2a, P2c
```

**Suggested execution order**: P1 → P2a → P2b + P2c (parallel) → P3c → P4. P3a and P3b can run anytime.

---

## Implementation Constraints

1. **Security**: Tailscale-only network. No public exposure. No built-in authentication.
2. **API contract**: `client/specs/API_CONTRACT.md` is the single source of truth for the server-client interface.
3. **Idempotency**: All scripts must be safe to re-run without side effects.
4. **No stubs**: Implement completely or not at all.
5. **HAProxy is optional but recommended**: User consent prompt required. Default: Yes. Without it, Ollama falls back to `0.0.0.0` binding (functional but less secure).
6. **Claude Code integration is optional**: Always prompt for user consent on the client side.
7. **curl-pipe install**: Client `install.sh` must work via `curl | bash`.

---

## Completed Work

**v1 (Aider/OpenAI API)**: Server and client fully implemented. Server: install.sh, uninstall.sh, warm-models.sh, test.sh (26 tests). Client: install.sh, uninstall.sh, test.sh (40 tests), env.template.

**v2+ (Claude Code/Anthropic API)**: Client fully implemented. Server Anthropic API tests added. Version management scripts, analytics infrastructure, and documentation all complete.

**Bug fixes**: All test harness bugs from hardware testing sessions have been applied to both server and client test scripts.

---

## Spec Baseline

All work must comply with the authoritative specs:
- `server/specs/*.md` (9 files)
- `client/specs/*.md` (9 files)

Refer to specs for detailed requirements rather than duplicating spec content in this plan. Implementation deviations must be corrected unless there is a compelling reason to update the spec instead.
