import asyncio

from sqlalchemy import select

from app.db import session_factory
from app.models import Curriculum, Standard


CURRICULA = [
    ("CBSE", "CBSE", "India", None),
    ("ICSE", "ICSE", "India", None),
    ("Kerala State", "KERALA", "India", "Kerala"),
]


async def main():
    async with session_factory()() as db:
        for curriculum_order, (name, code, country, region) in enumerate(CURRICULA):
            curriculum = await db.scalar(
                select(Curriculum).where(Curriculum.code == code)
            )

            if curriculum is None:
                curriculum = Curriculum(
                    name=name,
                    code=code,
                    country=country,
                    region=region,
                    sort_order=curriculum_order,
                    is_active=True,
                )
                db.add(curriculum)
                await db.flush()

            for class_number in range(1, 13):
                code_value = str(class_number)

                standard = await db.scalar(
                    select(Standard).where(
                        Standard.curriculum_id == curriculum.id,
                        Standard.code == code_value,
                    )
                )

                if standard is None:
                    db.add(
                        Standard(
                            curriculum_id=curriculum.id,
                            name=f"Class {class_number}",
                            code=code_value,
                            sort_order=class_number,
                            is_active=True,
                        )
                    )

        await db.commit()
        print("Academic taxonomy bootstrap complete.")


if __name__ == "__main__":
    asyncio.run(main())
