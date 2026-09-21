from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "sqlite:///./food.db"
    secret_key: str = "dev-secret"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7
    env: str = "dev"  # "prod" enables safety checks

    def validate_for_prod(self) -> None:
        if self.env == "prod" and self.secret_key in ("dev-secret", "change-me", "change-me-in-prod"):
            raise RuntimeError("SECRET_KEY must be set to a strong random value in prod")


settings = Settings()
settings.validate_for_prod()
