import httpx

from app.config import settings


async def generate_text(prompt: str, system: str, model: str | None = None) -> tuple[str, str]:
    """Generate text via OpenClaw (primary), Ollama, or Claude API. Returns (content, model_used)."""
    if settings.openclaw_url and settings.openclaw_gateway_token:
        return await _generate_openclaw([
            {"role": "system", "content": system},
            {"role": "user", "content": prompt},
        ])
    if settings.claude_api_key:
        return await _generate_claude(prompt, system)
    return await _generate_ollama(prompt, system, model or settings.preferred_ai_model)


async def generate_chat(messages: list[dict]) -> tuple[str, str]:
    """Multi-turn chat via OpenClaw (primary), Ollama, or Claude. Returns (content, model_used)."""
    if settings.openclaw_url and settings.openclaw_gateway_token:
        return await _generate_openclaw(messages)
    return await _generate_ollama_chat(messages)


async def _generate_openclaw(messages: list[dict]) -> tuple[str, str]:
    async with httpx.AsyncClient(timeout=300.0) as client:
        response = await client.post(
            f"{settings.openclaw_url}/v1/chat/completions",
            headers={"Authorization": f"Bearer {settings.openclaw_gateway_token}"},
            json={"model": "openclaw", "messages": messages, "stream": False},
        )
        response.raise_for_status()
        content: str = response.json()["choices"][0]["message"]["content"]
    return content, "openclaw/flo"


async def _generate_ollama(prompt: str, system: str, model: str) -> tuple[str, str]:
    async with httpx.AsyncClient(timeout=180.0) as client:
        response = await client.post(
            f"{settings.ollama_url}/v1/chat/completions",
            json={
                "model": model,
                "messages": [
                    {"role": "system", "content": system},
                    {"role": "user", "content": prompt},
                ],
                "temperature": 0.7,
                "max_tokens": 1500,
            },
        )
        response.raise_for_status()
        content: str = response.json()["choices"][0]["message"]["content"]
    return content, model


async def _generate_ollama_chat(messages: list[dict]) -> tuple[str, str]:
    model = settings.chat_model
    async with httpx.AsyncClient(timeout=180.0) as client:
        response = await client.post(
            f"{settings.chat_ai_url}/v1/chat/completions",
            json={"model": model, "messages": messages, "temperature": 0.7, "max_tokens": 2000},
        )
        response.raise_for_status()
        content: str = response.json()["choices"][0]["message"]["content"]
    return content, model


async def _generate_claude(prompt: str, system: str) -> tuple[str, str]:
    model = "claude-haiku-4-5"
    async with httpx.AsyncClient(timeout=60.0) as client:
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
