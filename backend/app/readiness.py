"""One migration authority for public and administrative readiness."""

from functools import lru_cache
from pathlib import Path

from alembic.script import ScriptDirectory
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError


@lru_cache
def expected_migration_head() -> str:
    # Resolve against the packaged source tree, never the process working directory.
    scripts = ScriptDirectory(str(Path(__file__).resolve().parents[1] / "alembic"))
    heads = scripts.get_heads()
    if len(heads) != 1:
        raise RuntimeError("Exactly one Alembic head is required")
    return heads[0]


async def schema_status(db) -> dict:
    expected = expected_migration_head()
    try:
        # A missing version table must not poison the CMS request transaction.
        async with db.begin_nested():
            revisions = (
                (await db.execute(text("SELECT version_num FROM alembic_version"))).scalars().all()
            )
    except SQLAlchemyError:
        revisions = []
    return {
        "currentMigrationHead": revisions[0] if len(revisions) == 1 else None,
        "requiredMigrationHead": expected,
        "schemaReady": revisions == [expected],
    }
