"""Controlled first-owner provisioning command; intentionally not exposed over HTTP."""

import argparse
import asyncio

from sqlalchemy import func, select

from .db import session_factory
from .models import User, UserRole


async def provision(email: str) -> None:
    async with session_factory()() as db:
        existing_owners = await db.scalar(
            select(func.count(User.id)).where(User.role == UserRole.super_admin)
        )
        if existing_owners:
            raise RuntimeError("A super administrator already exists; use audited CMS controls.")
        user = await db.scalar(
            select(User).where(func.lower(User.email) == email.strip().lower()).with_for_update()
        )
        if not user or not user.is_active:
            raise RuntimeError("An active existing user with that email is required.")
        user.role = UserRole.super_admin
        await db.commit()


def main() -> None:
    parser = argparse.ArgumentParser(description="Provision the first super administrator.")
    parser.add_argument("--email", required=True)
    arguments = parser.parse_args()
    asyncio.run(provision(arguments.email))


if __name__ == "__main__":
    main()
