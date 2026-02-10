# ai-server Functionalities (v1)

## Core Functionality

- One-time installer that configures Ollama as a LaunchAgent service
- Uninstaller that removes only server-side LaunchAgent configuration
- Ollama serves OpenAI-compatible HTTP endpoint at `/v1`
- Optional model pre-warming script for boot-time loading
- Comprehensive test script for automated validation of all server functionality
- Service management via standard launchctl commands (start/stop/restart/status)

## Exposed API

- OpenAI-compatible HTTP endpoint at `/v1`
- Primary route: `/v1/chat/completions`
- Supports:
  - Streaming (stream: true)
  - Non-streaming responses
  - JSON structured output (format: "json")
  - Tool / function calling (when underlying model implements it)
  - System, user, assistant message roles
- Model selection via `model` parameter (any model available on the server)

## Server Behavior Requirements

- Automatic model loading on first request (or pre-warming via optional script)
- Graceful handling of concurrent requests (Ollama-level queuing / concurrency)
- Keep-alive of frequently used models in memory when possible
- Clean shutdown / restart without losing in-flight generations (best-effort)

## Intended Testing Scope (non-normative)

- Large instruction-tuned models (30B–70B+ class)
- Code-specialized models
- Quantized variants suitable for Apple Silicon unified memory

## Performance Expectations (non-normative guidance)

- Low added latency for worldwide clients (dependent on upload bandwidth)
- Reasonable throughput on large models when kept resident
