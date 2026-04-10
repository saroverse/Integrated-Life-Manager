import httpx

from app.config import settings


async def generate_text(prompt: str, system: str) -> tuple[str, str]:
    """Generate text for scheduled jobs (briefings, recaps).
    Cascade: OpenClaw (local) → Claude API.
    """
    if settings.openclaw_url and settings.openclaw_gateway_token:
        return await _generate_openclaw([
            {"role": "system", "content": system},
            {"role": "user", "content": prompt},
        ])
    if settings.claude_api_key:
        return await _generate_claude(prompt, system)
    raise RuntimeError(
        "No AI service configured. Set CLAUDE_API_KEY or OPENCLAW_URL + OPENCLAW_GATEWAY_TOKEN in .env"
    )


async def generate_chat(messages: list[dict]) -> tuple[str, str]:
    """Multi-turn chat — goes directly to Claude API for best reasoning quality."""
    if settings.claude_api_key:
        return await _generate_claude_chat(messages)
    raise RuntimeError("CLAUDE_API_KEY not set in .env — chat requires Claude API")


async def _generate_openclaw(messages: list[dict]) -> tuple[str, str]:
    async with httpx.AsyncClient(timeout=300.0) as client:
        response = await client.post(
            f"{settings.openclaw_url}/v1/chat/completions",
            headers={"Authorization": f"Bearer {settings.openclaw_gateway_token}"},
            json={"model": "openclaw", "messages": messages, "stream": False},
        )
        response.raise_for_status()
        content: str = response.json()["choices"][0]["message"]["content"]
    return content, "openclaw"


async def _generate_claude(prompt: str, system: str) -> tuple[str, str]:
    model = settings.claude_model
    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": settings.claude_api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": model,
                "max_tokens": 1500,
                "system": system,
                "messages": [{"role": "user", "content": prompt}],
            },
        )
        response.raise_for_status()
        content: str = response.json()["content"][0]["text"]
    return content, model


async def _generate_claude_chat(messages: list[dict]) -> tuple[str, str]:
    """Multi-turn chat with Claude. Extracts system message if present."""
    model = settings.claude_model
    system = ""
    chat_messages = []
    for msg in messages:
        if msg["role"] == "system":
            system = msg["content"]
        else:
            chat_messages.append({"role": msg["role"], "content": msg["content"]})

    payload: dict = {
        "model": model,
        "max_tokens": 2000,
        "messages": chat_messages,
    }
    if system:
        payload["system"] = system

    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": settings.claude_api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json=payload,
        )
        response.raise_for_status()
        content: str = response.json()["content"][0]["text"]
    return content, model


# ── Ollama (V1 — disabled in V2, kept for reference) ─────────────────────────
#
# async def _generate_ollama(prompt, system, model):
#     async with httpx.AsyncClient(timeout=180.0) as client:
#         response = await client.post(
#             f"{settings.ollama_url}/v1/chat/completions",
#             json={"model": model, "messages": [
#                 {"role": "system", "content": system},
#                 {"role": "user", "content": prompt},
#             ], "temperature": 0.7, "max_tokens": 1500},
#         )
#         response.raise_for_status()
#         return response.json()["choices"][0]["message"]["content"], model
#
# async def _generate_ollama_chat(messages):
#     model = settings.chat_model
#     async with httpx.AsyncClient(timeout=180.0) as client:
#         response = await client.post(
#             f"{settings.chat_ai_url}/v1/chat/completions",
#             json={"model": model, "messages": messages, "temperature": 0.7, "max_tokens": 2000},
#         )
#         response.raise_for_status()
#         return response.json()["choices"][0]["message"]["content"], model
