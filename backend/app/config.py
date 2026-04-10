from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    database_url: str = "sqlite+aiosqlite:///./ilm.db"
    ollama_url: str = "http://localhost:11434"
    preferred_ai_model: str = "mistral:7b-instruct"
    fallback_ai_model: str = "llama3.2:3b"
    chat_ai_url: str = "http://localhost:11434"
    chat_model: str = "mistral:7b-instruct"
    claude_api_key: str = ""
    claude_model: str = "claude-haiku-4-5-20251001"
    firebase_credentials_path: str = "./firebase-service-account.json"
    device_api_token: str = "change-this-to-a-random-secret"
    timezone: str = "Europe/Berlin"
    backend_host: str = "0.0.0.0"
    backend_port: int = 8000
    zepp_email: str = ""
    zepp_password: str = ""
    openclaw_url: str = "http://localhost:18789"
    openclaw_gateway_token: str = ""
    groq_api_key: str = ""
    groq_model: str = "llama-3.1-8b-instant"


settings = Settings()
