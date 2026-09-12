import asyncio
import smtplib
from email.message import EmailMessage
from typing import Protocol

from .config import Settings


class PasswordResetDelivery(Protocol):
    async def send(self, *, recipient: str, reset_url: str, expires_minutes: int) -> None: ...


class PasswordResetDeliveryError(RuntimeError):
    """Raised when a reset message could not be handed to the configured relay."""


class SMTPPasswordResetDelivery:
    def __init__(self, settings: Settings):
        self.settings = settings

    async def send(self, *, recipient: str, reset_url: str, expires_minutes: int) -> None:
        try:
            await asyncio.to_thread(self._send, recipient, reset_url, expires_minutes)
        except (OSError, smtplib.SMTPException) as error:
            raise PasswordResetDeliveryError from error

    def _send(self, recipient: str, reset_url: str, expires_minutes: int) -> None:
        message = EmailMessage()
        message["Subject"] = "Reset your learning account password"
        message["From"] = self.settings.smtp_from_address
        message["To"] = recipient
        message.set_content(
            f"Use this link within {expires_minutes} minutes:\n{reset_url}\n\nIf you did not request this, ignore this message."
        )
        with smtplib.SMTP(self.settings.smtp_host, self.settings.smtp_port, timeout=10) as client:
            if self.settings.smtp_use_tls:
                client.starttls()
            if self.settings.smtp_username:
                client.login(self.settings.smtp_username, self.settings.smtp_password)
            client.send_message(message)
