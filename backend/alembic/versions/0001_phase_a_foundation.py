"""Frozen initial schema baseline.

The snapshot imported here must never be changed. Runtime model evolution belongs
in a new revision so a fresh install and a historical upgrade converge.
"""

from alembic import op
from app.schema_baseline_snapshot import Base

revision = "0001_phase_a"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    Base.metadata.create_all(bind=op.get_bind(), checkfirst=False)


def downgrade():
    Base.metadata.drop_all(bind=op.get_bind(), checkfirst=False)
