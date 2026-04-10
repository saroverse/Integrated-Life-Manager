"""OpenClaw — lightweight local AI proxy for ILM scheduled jobs.

Runs on port 18789. Receives OpenAI-compatible chat/completions requests
and forwards them to Groq (cheap, fast) for briefings and recaps.

Start with:
    cd backend && source venv/bin/activate && python3 openclaw/server.py

The main ILM backend uses this for generate_text() (briefings, recaps).
Claude API is used directly for generate_chat() (user-facing chat).
"""

import os
import sys

import httpx
import uvicorn
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.config import settings  # noqa: E402

app = FastAPI(title="OpenClaw", version="2.0")

GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"


class Message(BaseModel):
    role: str
    content: str


class CompletionRequest(BaseModel):
    model: str = "openclaw"
    messages: list[Message]
    stream: bool = False
    max_tokens: int = 1500
    temperature: float = 0.7


@app.get("/health")
async def health():
    return {"status": "ok", "service": "openclaw", "backend": "groq", "model": settings.groq_model}


@app.post("/v1/chat/completions")
async def chat_completions(
    req: CompletionRequest,
    authorization: str = Header(default=""),
) -> dict:
    # Simple internal token check
    token = authorization.removeprefix("Bearer ").strip()
    if settings.openclaw_gateway_token and token != settings.openclaw_gateway_token:
        raise HTTPException(status_code=401, detail="Invalid OpenClaw token")

    if not settings.groq_api_key:
        raise HTTPException(status_code=503, detail="GROQ_API_KEY not configured")

    messages = [{"role": m.role, "content": m.content} for m in req.messages]

    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(
            GROQ_API_URL,
            headers={
                "Authorization": f"Bearer {settings.groq_api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": settings.groq_model,
                "messages": messages,
                "max_tokens": req.max_tokens,
                "temperature": req.temperature,
            },
        )
        if response.status_code != 200:
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Groq API error: {response.text[:300]}",
            )
        body = response.json()

    content: str = body["choices"][0]["message"]["content"]
    model_used: str = body.get("model", settings.groq_model)

    return {
        "id": body.get("id", "openclaw-1"),
        "object": "chat.completion",
        "model": model_used,
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": content},
                "finish_reason": "stop",
            }
        ],
    }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=18790, log_level="info")
