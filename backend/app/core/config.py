from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "sqlite:///./food.db"
    secret_key: str = "dev-secret"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60  # refresh token renews it
    refresh_token_expire_days: int = 30
    cors_origins: str = "*"  # comma-separated allowlist in prod; empty/`none` = none
    cors_origin_regex: str = ""  # e.g. https://.*\\.vercel\\.app
    login_rate_limit: str = "10/minute"
    env: str = "dev"  # "prod" enables safety checks
    allow_ephemeral_db: bool = False  # sqlite in /tmp on Vercel — data dies on cold start

    @property
    def sqlalchemy_url(self) -> str:
        """Fly/Heroku hand out `postgres://`; SQLAlchemy 2 wants an explicit driver."""
        url = self.database_url
        if url.startswith("postgres://"):
            url = "postgresql+psycopg://" + url[len("postgres://") :]
        elif url.startswith("postgresql://"):
            url = "postgresql+psycopg://" + url[len("postgresql://") :]
        return url

    @property
    def cors_origin_list(self) -> list[str]:
        raw = [o.strip() for o in self.cors_origins.split(",") if o.strip()]
        if not raw or raw == ["none"]:
            return []
        if "*" in raw:
            return ["*"]
        return raw

    @property
    def is_prod(self) -> bool:
        return self.env == "prod"

    def validate_for_prod(self) -> None:
        if not self.is_prod:
            return
        if self.secret_key in ("dev-secret", "change-me", "change-me-in-prod"):
            raise RuntimeError("SECRET_KEY must be set to a strong random value in prod")
        if self.cors_origins.strip() == "*" and not self.cors_origin_regex:
            raise RuntimeError("CORS_ORIGINS must be an explicit allowlist (or empty) in prod")
        if self.sqlalchemy_url.startswith("sqlite") and not self.allow_ephemeral_db:
            raise RuntimeError("DATABASE_URL must not be sqlite in prod")


settings = Settings()
settings.validate_for_prod()
