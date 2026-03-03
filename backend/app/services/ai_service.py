import httpx

from app.config import settings


async def generate_text(prompt: str, system: str, model: str | None = None) -> tuple[str, str]:
    """Generate text via Ollama or Claude API. Returns (content, model_used)."""
    use_claude = bool(settings.claude_api_key)
    model = model or settings.preferred_ai_model

    if use_claude:
        return await _generate_claude(prompt, system)
    return await _generate_ollama(prompt, system, model)


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
        data = response.json()
        return data["choices"][0]["message"]["content"], model


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
        data = response.json()
        return data["content"][0]["text"], model
