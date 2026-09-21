from slowapi import Limiter
from slowapi.util import get_remote_address

# Keyed by client IP; behind Fly's proxy uvicorn is started with --proxy-headers.
limiter = Limiter(key_func=get_remote_address)
