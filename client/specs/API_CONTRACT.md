# ai-server API Contract (client view)

The ai-server exposes a strict subset of the OpenAI API at the following base URL:

## Base URL

`http://ai-server:11434/v1`

- Hostname is fixed; resolved via Tailscale
- Port is always 11434

## Authentication

- `Authorization: Bearer <any-value>` or `api_key` parameter is required by SDKs but ignored by the server
- Recommended dummy value: `ollama`

## Supported Endpoints

All others return 404.

| Endpoint                     | Method | Key Capabilities (client can rely on)                          | Limitations (client must not assume) |
|------------------------------|--------|----------------------------------------------------------------|--------------------------------------|
| `/v1/chat/completions`       | POST   | streaming (`stream: true`), JSON mode (`response_format: { "type": "json_object" }`), tools/tool_choice, vision (image_url), temperature/top_p/max_tokens/seed/stop/n | No stateful conversation memory; no previous_response_id |
| `/v1/models`                 | GET    | Returns list of available models with id, created, owned_by   | created = last-modified timestamp only |
| `/v1/models/{model}`         | GET    | Single model details                                           | Same as above |
| `/v1/responses`              | POST   | Non-stateful responses, streaming, tools/function calling      | No previous_response_id or conversation support; requires Ollama 0.5.0+ (experimental) |

## Common Request Fields (guaranteed)

- `model` (string – any model name available on server)
- `messages` (array of role/content objects; content can be text or image_url)
- `stream`, `stream_options.include_usage`
- `tools`, `tool_choice` (supported when model implements it)
- `response_format.type = "json_object"`
- `temperature`, `top_p`, `max_tokens`, `seed`, `stop`, `n`

## Environment Variables the client must set

```bash
OLLAMA_API_BASE=http://ai-server:11434/v1
OPENAI_API_BASE=http://ai-server:11434/v1     # for tools that read this
OPENAI_API_KEY=ollama                                 # ignored by server
AIDER_MODEL=ollama/<model-name>                       # optional default
```

## Error Behavior (client must handle)

- 404 / connection refused → Tailscale not connected or server unreachable
- 429 → server-side concurrency limit (rare)
- 500 → inference error (model unloaded, OOM, etc.)

## This contract is the only API surface the client may depend on

Do not make assumptions about server internals, model availability, or features not explicitly listed above.
