"""Printable sheet of table QR codes. Filled in by a worker; see the task spec."""

from fastapi import APIRouter

router = APIRouter(tags=["qr"])
