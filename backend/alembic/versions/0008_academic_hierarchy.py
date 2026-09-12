"""Add academic context and ordered lesson content without replacing legacy IDs."""

import uuid

import sqlalchemy as sa
from alembic import op

revision = "0008_academic_hierarchy"
down_revision = "0007_cms_phase34"
branch_labels = None
depends_on = None


def identity_columns():
    return [
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    ]


def upgrade():
    for name, parent, extras in [
        (
            "curricula",
            None,
            [
                sa.Column("country", sa.String(80), nullable=False),
                sa.Column("region", sa.String(100)),
            ],
        ),
        ("standards", ("curriculum_id", "curricula"), []),
        ("streams", ("standard_id", "standards"), []),
        ("subjects", None, []),
    ]:
        columns = (
            identity_columns()
            + [
                sa.Column("name", sa.String(120), nullable=False),
                sa.Column("code", sa.String(60), nullable=False),
                sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
                sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
            ]
            + extras
        )
        if parent:
            columns.append(
                sa.Column(
                    parent[0],
                    sa.String(36),
                    sa.ForeignKey(f"{parent[1]}.id", ondelete="RESTRICT"),
                    nullable=False,
                )
            )
            columns.append(sa.UniqueConstraint(parent[0], "code"))
        else:
            columns.append(sa.UniqueConstraint("code"))
        op.create_table(name, *columns)
        if parent:
            op.create_index(f"ix_{name}_{parent[0]}", name, [parent[0]])
    for column, table in [
        ("curriculum_id", "curricula"),
        ("standard_id", "standards"),
        ("stream_id", "streams"),
        ("subject_id", "subjects"),
    ]:
        op.add_column(
            "courses",
            sa.Column(
                column,
                sa.String(36),
                sa.ForeignKey(f"{table}.id", ondelete="RESTRICT"),
                nullable=True,
            ),
        )
    op.create_index(
        "ix_courses_academic_catalog",
        "courses",
        ["curriculum_id", "standard_id", "stream_id", "subject_id", "status"],
    )
    op.create_table(
        "student_academic_profiles",
        *identity_columns(),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column(
            "active_curriculum_id",
            sa.String(36),
            sa.ForeignKey("curricula.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "active_standard_id",
            sa.String(36),
            sa.ForeignKey("standards.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "active_stream_id", sa.String(36), sa.ForeignKey("streams.id", ondelete="RESTRICT")
        ),
        sa.Column("profile_version", sa.Integer(), nullable=False, server_default="1"),
    )
    lifecycle = sa.Enum(
        "draft", "published", "unavailable", "archived", name="lifecycle", create_type=False
    )
    if op.get_bind().dialect.name == "postgresql":
        from sqlalchemy.dialects.postgresql import ENUM

        lifecycle = ENUM(
            "draft", "published", "unavailable", "archived", name="lifecycle", create_type=False
        )
    op.create_table(
        "lesson_content_items",
        *identity_columns(),
        sa.Column(
            "lesson_id",
            sa.String(36),
            sa.ForeignKey("lessons.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("content_type", sa.String(30), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("reference_id", sa.String(255)),
        sa.Column(
            "assessment_id", sa.String(36), sa.ForeignKey("assessments.id", ondelete="RESTRICT")
        ),
        sa.Column("body", sa.Text()),
        sa.Column("status", lifecycle, nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=False),
        sa.UniqueConstraint("lesson_id", "position"),
        sa.CheckConstraint("content_type IN ('video', 'note', 'quiz', 'resource')"),
        sa.CheckConstraint("position > 0"),
        sa.CheckConstraint(
            "(content_type = 'quiz' AND assessment_id IS NOT NULL) OR (content_type <> 'quiz' AND assessment_id IS NULL)"
        ),
    )
    op.create_index("ix_lesson_content_items_lesson_id", "lesson_content_items", ["lesson_id"])
    op.add_column(
        "media_assets",
        sa.Column(
            "content_item_id",
            sa.String(36),
            sa.ForeignKey("lesson_content_items.id", ondelete="RESTRICT"),
        ),
    )
    op.create_index("ix_media_assets_content_item_id", "media_assets", ["content_item_id"])
    # Only backfill resolvable references; unsupported legacy content remains untouched.
    bind = op.get_bind()
    rows = bind.execute(
        sa.text(
            """SELECT l.*, m.course_id FROM lessons l JOIN course_modules m ON m.id=l.module_id"""
        )
    ).mappings()
    items = sa.table(
        "lesson_content_items",
        sa.column("id"),
        sa.column("lesson_id"),
        sa.column("content_type"),
        sa.column("position"),
        sa.column("title"),
        sa.column("reference_id"),
        sa.column("assessment_id"),
        sa.column("status"),
        sa.column("metadata_json", sa.JSON()),
        sa.column("created_at"),
        sa.column("updated_at"),
    )
    for row in rows:
        kind, ref = row["content_type"], row["content_ref"]
        if kind not in {"video", "quiz", "resource"} or not ref:
            continue
        if kind == "quiz":
            valid = bind.execute(
                sa.text("SELECT id FROM assessments WHERE id=:ref AND course_id=:course"),
                {"ref": ref, "course": row["course_id"]},
            ).first()
        else:
            valid = bind.execute(
                sa.text(
                    "SELECT id FROM media_assets WHERE asset_id=:ref AND lesson_id=:lesson AND kind=:kind AND status='active'"
                ),
                {"ref": ref, "lesson": row["id"], "kind": "hls" if kind == "video" else "download"},
            ).first()
        if not valid:
            continue
        item_id = str(uuid.uuid4())
        bind.execute(
            items.insert().values(
                id=item_id,
                lesson_id=row["id"],
                content_type=kind,
                position=1,
                title=row["title"],
                reference_id=ref if kind != "quiz" else None,
                assessment_id=ref if kind == "quiz" else None,
                status="published",
                metadata_json={},
                created_at=row["created_at"],
                updated_at=row["updated_at"],
            )
        )
        if kind != "quiz":
            bind.execute(
                sa.text("UPDATE media_assets SET content_item_id=:item WHERE id=:id"),
                {"item": item_id, "id": valid[0]},
            )


def downgrade():
    # Deliberately refuse an automatic rollback that would erase newly authored data.
    raise RuntimeError(
        "Academic hierarchy contains durable data; use a reviewed forward migration."
    )
