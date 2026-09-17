from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "sqlite:///./food.db"
    secret_key: str = "dev-secret"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7


settings = Settings()
