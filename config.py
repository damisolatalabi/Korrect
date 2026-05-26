from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    openai_api_key: str = ""
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"
    groq_api_key: str = ""

    # STT 모드: "local" | "api" (OpenAI) | "google" | "groq"
    whisper_mode: str = "local"
    # local 모드 모델 크기: tiny, base, small, medium, large
    whisper_model_size: str = "small"

    # Google Cloud STT 서비스 계정 키 파일 경로 (google 모드일 때만 사용)
    google_credentials_path: str = ""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
