<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

**Last Updated**: 2026-02-12

---

## Current Status

| Component | v2 Compliance | Notes |
|-----------|:------------:|-------|
| **Specs** (18 files) | 100% | All v2-compliant. v1 mentions are historical context only. |
| **Documentation** (5 files) | 100% | READMEs, SETUP guides, ROUTER_SETUP.md — all v2-compliant. |
| **Root Analytics** (3 scripts) | 100% | `loop.sh`, `loop-with-analytics.sh`, `compare-analytics.sh`. |
| **Client Version Mgmt** (3 scripts) | 100% | `check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh`. |
| **Client Config** | 100% | `env.template` — uses static DMZ IP `192.168.100.10`, correct env vars. |
| **Server Scripts** (4 files) | ~65% | 3 of 4 complete (warm-models.sh, uninstall.sh, test.sh). 1 remaining (install.sh). |
| **Client Scripts** (3 files) | ~85% | `test.sh` v2-compliant. `install.sh`, `uninstall.sh` remaining. |

**Target Architecture** (v2):
```
Client → WireGuard VPN (OpenWrt Router) → Firewall → Ollama (192.168.100.10:11434)
```

---

## Dependency Graph

```
P1 (server scripts) ─── can start immediately
P2 (client scripts) ─── can start immediately (independent of P1)
        │
P3 (hardware validation) ─── depends on P1 + P2
```

P1 and P2 share no code and communicate only via `client/specs/API_CONTRACT.md`.

---

## P1: Server Scripts — v2 Migration

**Spec authority**: `server/specs/SCRIPTS.md`

### P1a: `server/scripts/install.sh` (751 lines — complete rewrite)

~300 lines of reusable code (helpers, system validation, Ollama install, LaunchAgent lifecycle); ~480 lines of v1 code to remove; ~250 lines of new v2 code to add.

**Remove:**
- Tailscale install/connect workflow (lines 95-227)
- HAProxy install/config (lines 352-624)
- Tailscale ACL instructions (lines 626-698)
- v1 final summary (lines 700-751)
- `OLLAMA_HOST=127.0.0.1` binding (line 284)

**Keep (with URL modifications):**
- Helpers, color output, banner (lines 1-52)
- System validation: macOS 14+, Apple Silicon, shell, Homebrew (lines 54-93)
- Ollama install via Homebrew (lines 229-248)
- Stop existing services (lines 250-262)
- LaunchAgent plist creation and loading (lines 264-308) — change `OLLAMA_HOST`
- Service verification retry loop (lines 310-329) — change URL
- Process ownership check (lines 331-342)
- Self-test API call (lines 344-350) — change URL

**Add:**
- Router setup prerequisite prompt (reference `ROUTER_SETUP.md`)
- DMZ network config prompts (subnet default `192.168.100.0/24`, IP default `192.168.100.10`)
- IP format and subnet membership validation
- Static IP config via `sudo networksetup -setmanual "Ethernet" ...`
- Interface detection via `networksetup -listallhardwareports`
- DNS config (router primary, public backup)
- Plist `OLLAMA_HOST=192.168.100.10` (or `0.0.0.0`)
- Binding verification via `lsof -i :11434`
- Router connectivity test via `ping -c 3 192.168.100.1`
- Optional model pre-pull prompt
- v2 final summary (DMZ IP, auto-start, router connectivity, troubleshooting)

### P1b: `server/scripts/uninstall.sh` — v2 migration ✅ COMPLETE

**Status**: Completed 2026-02-12

**Removed:**
- ✅ Entire HAProxy cleanup section (lines 92-156, ~64 lines)
- ✅ v1 references from preserved items list (Tailscale, HAProxy)
- ✅ Tailscale/HAProxy uninstall instructions (lines 200-206)

**Preserved:**
- ✅ Ollama service stop, plist removal, log cleanup, model preservation
- ✅ Core uninstall flow and user confirmation prompts

**Added:**
- ✅ Optional static IP → DHCP revert prompt with `networksetup -setdhcp` command
- ✅ Router config cleanup reminder (remove WireGuard peer, DMZ rules; reference `ROUTER_SETUP.md`)
- ✅ Updated "Left untouched" list to include network/router configuration notes

### P1c: `server/scripts/test.sh` — v2 migration ✅ COMPLETE

**Status**: Completed 2026-02-12

**Removed:**
- ✅ Test 18: loopback binding check expecting `127.0.0.1` (lines 853-872)
- ✅ Test 19: localhost access test (lines 874-880)
- ✅ Test 20: Tailscale IP access test (lines 882-897)
- ✅ Tests 21-30: entire HAProxy test section (lines 900-1058, ~159 lines)

**Fixed:**
- ✅ Test numbering conflict: Anthropic tests 21-26 overlapping with HAProxy tests 21-30 — resolved by removing HAProxy tests
- ✅ `TOTAL_TESTS` updated from 36 to 29 (7 tests removed)

**Modified:**
- ✅ Test 17: `OLLAMA_HOST` plist check now accepts `192.168.100.10` or `0.0.0.0` (not `127.0.0.1`)
- ✅ All API test URLs changed from `localhost` to `${OLLAMA_HOST}` (auto-detected from plist)
- ✅ "What's Next" section updated to reference `ROUTER_SETUP.md`/WireGuard

**Added:**
- ✅ `detect_ollama_host()` function: auto-detect from env var → plist → fallback to `localhost`
- ✅ Test 18: Binding verification (`lsof -i :11434` shows DMZ IP or `0.0.0.0`)
- ✅ Test 19: DMZ IP connectivity test (`curl http://${OLLAMA_HOST}:11434/v1/models`)
- ✅ Test 20: Router gateway connectivity (`ping -c 3 192.168.100.1`)
- ✅ Test 21: DNS resolution (`nslookup google.com`)
- ✅ Test 22: Internet connectivity (`curl -I https://www.google.com`)
- ✅ Test 23: LAN isolation verification (ping `192.168.1.1` — should fail, confirms DMZ security posture)

### P1d: `server/scripts/warm-models.sh` — localhost fix ✅ COMPLETE

**Status**: Completed 2026-02-12

**Implemented:**
- ✅ Added `detect_ollama_host()` function: checks `OLLAMA_HOST` env → parses plist → fallback to `localhost`
- ✅ Replaced `localhost:11434` with `${OLLAMA_HOST}:11434` in both curl commands (lines 56, 95)
- ✅ Updated error messages to reference dynamic host detection

---

## P2: Client Scripts — Tailscale → WireGuard

**Spec authority**: `client/specs/SCRIPTS.md`

### P2a: `client/scripts/install.sh` (617 lines — substantial rewrite)

~350 lines of reusable code; ~140 lines to remove; ~180 lines to add.

**Remove:**
- Entire Tailscale section: GUI check, install, connection flow, IP detection (lines 152-280)

**Keep (with modifications):**
- System validation, Homebrew, Python install (lines 1-150)
- Config directory creation (lines 293-297)
- Env file generation (lines 299-336) — update hostname default
- Shell profile modification (lines 337-370)
- pipx + Aider installation (lines 372-468)
- Claude Code alias (lines 470-527) — update to use IP
- Uninstall script copy (lines 529-546)
- Connectivity test (lines 548-559) — update URL
- Final summary structure (lines 560-617) — update messaging

**Add:**
- WireGuard install: `brew install wireguard-tools`
- Keypair generation: `wg genkey | tee privatekey | wg pubkey > publickey`
- Key storage in `~/.ai-client/wireguard/` with `chmod 600` on private key
- Public key display with instructions to send to router admin
- Server IP prompt (default `192.168.100.10`)
- VPN server pubkey/endpoint prompts
- WireGuard config file generation (`~/.ai-client/wireguard/wg0.conf`)
- Import instructions for WireGuard app or `wg-quick`
- VPN connection confirmation before connectivity test
- Updated final summary (display pubkey, remind to send to admin, remind to connect VPN)

### P2b: `client/scripts/uninstall.sh` (156 lines — minor edit)

**Change:**
- Line 6: "Leaves Tailscale" → "Leaves WireGuard"
- Line 142: `echo "  - Tailscale"` → `echo "  - WireGuard"`

**Add:**
- Display public key (from `~/.ai-client/wireguard/publickey`) before directory deletion
- WireGuard config cleanup (directory already removed by `rm -rf ~/.ai-client/`)
- Optional `brew uninstall wireguard-tools` prompt
- Reminder to have router admin remove VPN peer (with public key displayed)

### P2c: `client/scripts/test.sh` — Tailscale → WireGuard ✅ COMPLETE

**Status**: Completed 2026-02-12

**Changed:**
- ✅ Test 8 (lines 248-254): `command -v tailscale` → `command -v wg` or `brew list wireguard-tools`
- ✅ Test 9 (lines 256-267): `tailscale status`/`tailscale ip -4` → WireGuard interface check (`wg show` or active `utun`)
- ✅ Test 14 comment (line 333): "Tailscale connectivity" → "VPN connectivity"
- ✅ Error messages (lines 641, 1413): "Tailscale" → "WireGuard VPN"/"VPN"

**Preserved:**
- ✅ All 40 tests: env config (1-7), dependencies (10-13), connectivity (14-19), API contract (20-22), Aider (23-26), script behavior (27-28), Claude Code (29-35), version management (36-40)
- ✅ Test harness structure, color-coded output, verbose mode, timing logic

---

## P3: Hardware Validation

**Dependencies**: P1 + P2 complete
**Location**: Apple Silicon hardware + OpenWrt router

- [ ] `server/scripts/install.sh` completes without errors on target hardware
- [ ] `server/scripts/test.sh --verbose` — all automated tests pass
- [ ] `server/scripts/uninstall.sh` cleanly removes configuration
- [ ] `client/scripts/install.sh` completes without errors
- [ ] `client/scripts/test.sh --verbose` — all automated tests pass
- [ ] `client/scripts/uninstall.sh` cleanly removes configuration
- [ ] WireGuard VPN: client connects through router tunnel to server
- [ ] DMZ isolation: server cannot reach LAN (`ping 192.168.1.x` fails)
- [ ] End-to-end: Aider and Claude Code inference works via VPN
- [ ] Version management: `check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh` work
- [ ] Analytics: `loop-with-analytics.sh` captures metrics
- [ ] Idempotency: re-running install scripts on already-installed system succeeds cleanly

---

## Implementation Constraints

1. **Specs are authoritative**: `server/specs/*.md` (9 files), `client/specs/*.md` (9 files). Scripts must match specs.
2. **API contract**: `client/specs/API_CONTRACT.md` is the single source of truth for the server-client interface.
3. **Security**: WireGuard VPN + OpenWrt firewall + DMZ isolation. No public exposure. No built-in auth.
4. **Idempotency**: All scripts must be safe to re-run without side effects.
5. **No stubs**: Implement completely or not at all.
6. **Claude Code integration is optional**: Always prompt for user consent on the client side.
7. **curl-pipe install**: Client `install.sh` must work via `curl | bash`.
