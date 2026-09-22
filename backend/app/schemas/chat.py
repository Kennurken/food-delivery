from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ChatMessageCreate(BaseModel):
    body: str = Field(min_length=1, max_length=800)

    @field_validator("body")
    @classmethod
    def _strip(cls, value: str) -> str:
        text = value.strip()
        if not text:
            raise ValueError("Message is empty")
        return text


class ChatMessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    order_id: int
    user_id: int | None
    sender_name: str
    body: str
    created_at: datetime
