from pathlib import Path

from app.models import Base


def test_security_constraints_are_present():
    tables = Base.metadata.tables
    assert {
        "users",
        "auth_sessions",
        "entitlements",
        "assessment_attempts",
        "assessment_responses",
        "certificates",
        "certificate_revocations",
        "audit_events",
        "idempotency_records",
    } <= set(tables)
    unique_names = {c.name for c in tables["assessment_attempts"].constraints if c.name}
    assert any("assessment" in name for name in unique_names)


def test_backend_identifiers_use_domain_terminology():
    names = {table.name for table in Base.metadata.tables.values()}
    assert {"courses", "lessons", "enrollments"} <= names
    assert all(name == name.lower() for name in names)


def test_commerce_entitlement_provenance_constraints_are_present():
    tables = Base.metadata.tables
    entitlement = tables["entitlements"]
    assert {"purchase_id", "subscription_id"} <= set(entitlement.columns.keys())
    foreign_targets = {
        foreign_key.target_fullname
        for column in (entitlement.c.purchase_id, entitlement.c.subscription_id)
        for foreign_key in column.foreign_keys
    }
    assert foreign_targets == {"purchases.id", "subscriptions.id"}
    subscription_unique = {
        constraint.name for constraint in tables["subscriptions"].constraints if constraint.name
    }
    assert "uq_subscription_provider_original_transaction" in subscription_unique


def test_initial_migration_uses_frozen_schema_snapshot():
    backend_root = Path(__file__).resolve().parents[1]
    migration = (backend_root / "alembic/versions/0001_phase_a_foundation.py").read_text()
    assert "app.schema_baseline_snapshot" in migration
    assert "from app.models import Base" not in migration
    assert (backend_root / "alembic/versions/0005_p0_commerce_integrity.py").is_file()
    latest = backend_root / "alembic/versions/0006_r3_query_indexes.py"
    assert latest.is_file()
    assert 'down_revision = "0005_p0_integrity"' in latest.read_text()


def test_readiness_requires_the_exact_latest_migration_revision():
    from alembic.script import ScriptDirectory

    from app.readiness import expected_migration_head

    backend_root = Path(__file__).resolve().parents[1]
    heads = ScriptDirectory(str(backend_root / "alembic")).get_heads()
    assert len(heads) == 1
    assert expected_migration_head() == heads[0]
