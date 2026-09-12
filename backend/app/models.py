import enum
import uuid
from datetime import UTC, datetime

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    Float,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


def utcnow() -> datetime:
    return datetime.now(UTC)


class Base(DeclarativeBase):
    pass


class UUIDTimestampMixin:
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False
    )


class UserRole(str, enum.Enum):
    learner = "learner"
    super_admin = "super_admin"
    admin = "admin"
    content_manager = "content_manager"
    support = "support"


class Lifecycle(str, enum.Enum):
    draft = "draft"
    published = "published"
    unavailable = "unavailable"
    archived = "archived"


class ContentProtectionPolicy(str, enum.Enum):
    none = "none"
    discourage_capture = "discourageCapture"
    block_capture = "blockCaptureWhereSupported"
    drm_required = "drmRequired"


class PolicyKind(str, enum.Enum):
    free = "free"
    premium = "premium"
    preview = "preview"
    inherit = "inherit"
    unavailable = "unavailable"


class EntitlementStatus(str, enum.Enum):
    active = "active"
    expired = "expired"
    revoked = "revoked"
    pending = "pending"
    grace_period = "gracePeriod"


class EntitlementSource(str, enum.Enum):
    free = "free"
    subscription = "subscription"
    purchase = "purchase"
    bundle = "bundle"
    promotion = "promotion"
    trial = "trial"
    scholarship = "scholarship"
    admin_grant = "admin_grant"


class ResourceType(str, enum.Enum):
    course = "course"
    module = "module"
    lesson = "lesson"
    assessment = "assessment"
    certificate = "certificate"
    resource = "resource"


class QuestionType(str, enum.Enum):
    single_choice = "singleChoice"
    multiple_choice = "multipleChoice"
    true_false = "trueFalse"
    text_response = "textResponse"


class AttemptStatus(str, enum.Enum):
    in_progress = "inProgress"
    submitted = "submitted"
    expired = "expired"


class CertificateStatus(str, enum.Enum):
    issued = "issued"
    revoked = "revoked"
    unavailable = "unavailable"
    pending_eligibility = "pendingEligibility"


class NotificationType(str, enum.Enum):
    course_update = "courseUpdate"
    lesson_reminder = "lessonReminder"
    live_class_reminder = "liveClassReminder"
    learning_reminder = "learningReminder"
    assessment_result = "assessmentResult"
    certificate_issued = "certificateIssued"
    download_completed = "downloadCompleted"
    payment_event = "paymentEvent"
    subscription_event = "subscriptionEvent"
    system_announcement = "systemAnnouncement"
    security_event = "securityEvent"


class NotificationPriority(str, enum.Enum):
    low = "low"
    normal = "normal"
    high = "high"
    urgent = "urgent"


class User(UUIDTimestampMixin, Base):
    __tablename__ = "users"
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    display_name: Mapped[str] = mapped_column(String(120))
    onboarding_complete: Mapped[bool] = mapped_column(Boolean, default=False)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), default=UserRole.learner)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    suspended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    suspension_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    learning_interests: Mapped[list] = mapped_column(JSON, default=list)
    language_preference: Mapped[str] = mapped_column(String(10), default="en")


class AuthSession(UUIDTimestampMixin, Base):
    __tablename__ = "auth_sessions"
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    refresh_token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    device_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    platform: Mapped[str | None] = mapped_column(String(50), nullable=True)
    last_active_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    ip_address: Mapped[str | None] = mapped_column(String(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(String(300), nullable=True)
    __table_args__ = (Index("ix_auth_sessions_user_active", "user_id", "revoked_at", "expires_at"),)


class Notification(UUIDTimestampMixin, Base):
    __tablename__ = "notifications"
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    type: Mapped[NotificationType] = mapped_column(Enum(NotificationType), index=True)
    title: Mapped[str] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text)
    destination_type: Mapped[str] = mapped_column(String(50), default="none")
    destination_payload: Mapped[dict] = mapped_column(JSON, default=dict)
    priority: Mapped[NotificationPriority] = mapped_column(
        Enum(NotificationPriority), default=NotificationPriority.normal
    )
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    __table_args__ = (
        Index("ix_notifications_user_created", "user_id", "created_at", "id"),
        Index("ix_notifications_user_unread", "user_id", "read_at", "expires_at"),
    )


class NotificationPreferences(UUIDTimestampMixin, Base):
    __tablename__ = "notification_preferences"
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True
    )
    email_course_updates: Mapped[bool] = mapped_column(Boolean, default=True)
    email_learning_reminders: Mapped[bool] = mapped_column(Boolean, default=True)
    email_marketing: Mapped[bool] = mapped_column(Boolean, default=False)
    email_security_alerts: Mapped[bool] = mapped_column(Boolean, default=True)
    push_course_updates: Mapped[bool] = mapped_column(Boolean, default=True)
    push_learning_reminders: Mapped[bool] = mapped_column(Boolean, default=True)
    push_live_classes: Mapped[bool] = mapped_column(Boolean, default=True)
    push_assessment_updates: Mapped[bool] = mapped_column(Boolean, default=True)
    push_certificate_updates: Mapped[bool] = mapped_column(Boolean, default=True)
    push_payment_events: Mapped[bool] = mapped_column(Boolean, default=True)
    push_security_alerts: Mapped[bool] = mapped_column(Boolean, default=True)
    in_app_course_updates: Mapped[bool] = mapped_column(Boolean, default=True)
    in_app_reminders: Mapped[bool] = mapped_column(Boolean, default=True)
    in_app_certificates: Mapped[bool] = mapped_column(Boolean, default=True)


class PushDeviceToken(UUIDTimestampMixin, Base):
    __tablename__ = "push_device_tokens"
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token: Mapped[str] = mapped_column(String(500), unique=True, index=True)
    platform: Mapped[str] = mapped_column(String(30))
    device_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)


class SyncedUserSettings(UUIDTimestampMixin, Base):
    __tablename__ = "synced_user_settings"
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True
    )
    theme_mode: Mapped[str] = mapped_column(String(20), default="system")
    language: Mapped[str] = mapped_column(String(10), default="en")
    autoplay_next_lesson: Mapped[bool] = mapped_column(Boolean, default=True)
    preferred_playback_speed: Mapped[float] = mapped_column(Numeric(3, 2), default=1.0)
    captions_default_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    reduced_motion: Mapped[bool] = mapped_column(Boolean, default=False)
    high_contrast: Mapped[bool] = mapped_column(Boolean, default=False)
    download_quality: Mapped[str] = mapped_column(String(20), default="standard")
    download_wifi_only: Mapped[bool] = mapped_column(Boolean, default=True)


class AcademicTaxonomyMixin:
    name: Mapped[str] = mapped_column(String(120))
    code: Mapped[str] = mapped_column(String(60))
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class Curriculum(AcademicTaxonomyMixin, UUIDTimestampMixin, Base):
    __tablename__ = "curricula"
    country: Mapped[str] = mapped_column(String(80), default="India")
    region: Mapped[str | None] = mapped_column(String(100), nullable=True)
    __table_args__ = (UniqueConstraint("code"),)


class Standard(AcademicTaxonomyMixin, UUIDTimestampMixin, Base):
    __tablename__ = "standards"
    curriculum_id: Mapped[str] = mapped_column(
        ForeignKey("curricula.id", ondelete="RESTRICT"), index=True
    )
    __table_args__ = (UniqueConstraint("curriculum_id", "code"),)


class Stream(AcademicTaxonomyMixin, UUIDTimestampMixin, Base):
    __tablename__ = "streams"
    standard_id: Mapped[str] = mapped_column(
        ForeignKey("standards.id", ondelete="RESTRICT"), index=True
    )
    __table_args__ = (UniqueConstraint("standard_id", "code"),)


class Subject(AcademicTaxonomyMixin, UUIDTimestampMixin, Base):
    __tablename__ = "subjects"
    __table_args__ = (UniqueConstraint("code"),)


class StudentAcademicProfile(UUIDTimestampMixin, Base):
    __tablename__ = "student_academic_profiles"
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    active_curriculum_id: Mapped[str] = mapped_column(
        ForeignKey("curricula.id", ondelete="RESTRICT")
    )
    active_standard_id: Mapped[str] = mapped_column(ForeignKey("standards.id", ondelete="RESTRICT"))
    active_stream_id: Mapped[str | None] = mapped_column(
        ForeignKey("streams.id", ondelete="RESTRICT"), nullable=True
    )
    profile_version: Mapped[int] = mapped_column(Integer, default=1)


class LessonContentItem(UUIDTimestampMixin, Base):
    __tablename__ = "lesson_content_items"
    lesson_id: Mapped[str] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"), index=True)
    content_type: Mapped[str] = mapped_column(String(30))
    position: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(200), default="")
    reference_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    assessment_id: Mapped[str | None] = mapped_column(
        ForeignKey("assessments.id", ondelete="RESTRICT"), nullable=True
    )
    body: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[Lifecycle] = mapped_column(Enum(Lifecycle), default=Lifecycle.draft)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    __table_args__ = (
        UniqueConstraint("lesson_id", "position"),
        CheckConstraint("content_type IN ('video', 'note', 'quiz', 'resource')"),
        CheckConstraint("position > 0"),
        CheckConstraint(
            "(content_type = 'quiz' AND assessment_id IS NOT NULL) OR (content_type <> 'quiz' AND assessment_id IS NULL)"
        ),
    )


class Category(UUIDTimestampMixin, Base):
    __tablename__ = "categories"
    name: Mapped[str] = mapped_column(String(100), unique=True)
    icon_name: Mapped[str] = mapped_column(String(60), default="school")


class Tag(UUIDTimestampMixin, Base):
    __tablename__ = "tags"
    name: Mapped[str] = mapped_column(String(80), unique=True, index=True)


class CourseTag(Base):
    __tablename__ = "course_tags"
    course_id: Mapped[str] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"), primary_key=True
    )
    tag_id: Mapped[str] = mapped_column(ForeignKey("tags.id", ondelete="CASCADE"), primary_key=True)


class CourseCategory(Base):
    __tablename__ = "course_categories"
    course_id: Mapped[str] = mapped_column(
        ForeignKey("courses.id", ondelete="CASCADE"), primary_key=True
    )
    category_id: Mapped[str] = mapped_column(
        ForeignKey("categories.id", ondelete="CASCADE"), primary_key=True
    )


class Course(UUIDTimestampMixin, Base):
    __tablename__ = "courses"
    curriculum_id: Mapped[str | None] = mapped_column(
        ForeignKey("curricula.id", ondelete="RESTRICT"), nullable=True
    )
    standard_id: Mapped[str | None] = mapped_column(
        ForeignKey("standards.id", ondelete="RESTRICT"), nullable=True
    )
    stream_id: Mapped[str | None] = mapped_column(
        ForeignKey("streams.id", ondelete="RESTRICT"), nullable=True
    )
    subject_id: Mapped[str | None] = mapped_column(
        ForeignKey("subjects.id", ondelete="RESTRICT"), nullable=True
    )
    title: Mapped[str] = mapped_column(String(200), index=True)
    subtitle: Mapped[str] = mapped_column(String(300), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    level: Mapped[str] = mapped_column(String(30), default="allLevels", index=True)
    language_code: Mapped[str] = mapped_column(String(12), default="en")
    policy_kind: Mapped[PolicyKind] = mapped_column(Enum(PolicyKind), default=PolicyKind.free)
    protection_policy: Mapped[ContentProtectionPolicy] = mapped_column(
        Enum(ContentProtectionPolicy), default=ContentProtectionPolicy.block_capture
    )
    required_tier: Mapped[str | None] = mapped_column(String(50))
    required_bundle_id: Mapped[str | None] = mapped_column(String(36))
    status: Mapped[Lifecycle] = mapped_column(Enum(Lifecycle), default=Lifecycle.draft, index=True)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    rating: Mapped[float] = mapped_column(Numeric(3, 2), default=0)
    rating_count: Mapped[int] = mapped_column(Integer, default=0)
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0)
    learning_outcomes: Mapped[list] = mapped_column(JSON, default=list)
    prerequisites: Mapped[list] = mapped_column(JSON, default=list)
    cover_reference: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    __table_args__ = (
        CheckConstraint("duration_seconds >= 0"),
        Index("ix_courses_catalog", "status", "published_at", "id"),
        Index(
            "ix_courses_academic_catalog",
            "curriculum_id",
            "standard_id",
            "stream_id",
            "subject_id",
            "status",
        ),
    )


class CourseModule(UUIDTimestampMixin, Base):
    __tablename__ = "course_modules"
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    position: Mapped[int] = mapped_column(Integer)
    policy_kind: Mapped[PolicyKind] = mapped_column(Enum(PolicyKind), default=PolicyKind.inherit)
    __table_args__ = (UniqueConstraint("course_id", "position"),)


class Lesson(UUIDTimestampMixin, Base):
    __tablename__ = "lessons"
    module_id: Mapped[str] = mapped_column(
        ForeignKey("course_modules.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(200))
    position: Mapped[int] = mapped_column(Integer)
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0)
    content_type: Mapped[str] = mapped_column(String(30))
    content_ref: Mapped[str] = mapped_column(String(255), unique=True)
    is_preview: Mapped[bool] = mapped_column(Boolean, default=False)
    is_downloadable: Mapped[bool] = mapped_column(Boolean, default=True)
    policy_kind: Mapped[PolicyKind] = mapped_column(Enum(PolicyKind), default=PolicyKind.inherit)
    protection_policy: Mapped[ContentProtectionPolicy] = mapped_column(
        Enum(ContentProtectionPolicy), default=ContentProtectionPolicy.block_capture
    )
    __table_args__ = (
        UniqueConstraint("module_id", "position"),
        CheckConstraint("duration_seconds >= 0"),
    )


class Enrollment(UUIDTimestampMixin, Base):
    __tablename__ = "enrollments"
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"), index=True)
    status: Mapped[str] = mapped_column(String(20), default="active")
    __table_args__ = (UniqueConstraint("learner_id", "course_id"),)


class LessonProgress(UUIDTimestampMixin, Base):
    __tablename__ = "lesson_progress"
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    lesson_id: Mapped[str] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"), index=True)
    position_seconds: Mapped[int] = mapped_column(Integer, default=0)
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0)
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    revision: Mapped[int] = mapped_column(Integer, default=1)
    __table_args__ = (
        UniqueConstraint("learner_id", "lesson_id"),
        CheckConstraint("position_seconds >= 0 AND duration_seconds >= 0"),
    )


class ProgressMutation(Base):
    __tablename__ = "progress_mutations"
    learner_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    mutation_id: Mapped[str] = mapped_column(String(100), primary_key=True)
    request_hash: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Bookmark(UUIDTimestampMixin, Base):
    __tablename__ = "bookmarks"
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"))
    __table_args__ = (UniqueConstraint("learner_id", "course_id"),)


class RecentlyViewed(UUIDTimestampMixin, Base):
    __tablename__ = "recently_viewed"
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"))
    viewed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    __table_args__ = (
        UniqueConstraint("learner_id", "course_id"),
        Index("ix_recently_viewed_history", "learner_id", "viewed_at"),
    )


class PasswordResetCode(UUIDTimestampMixin, Base):
    __tablename__ = "password_reset_codes"
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    code_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class VideoWatchProgress(UUIDTimestampMixin, Base):
    __tablename__ = "video_watch_progress"
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    media_asset_id: Mapped[str] = mapped_column(ForeignKey("media_assets.id", ondelete="RESTRICT"))
    position_seconds: Mapped[float] = mapped_column(Float, default=0)
    furthest_seconds: Mapped[float] = mapped_column(Float, default=0)
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    checkpoint_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    __table_args__ = (UniqueConstraint("learner_id", "media_asset_id"),)


class MediaAsset(UUIDTimestampMixin, Base):
    __tablename__ = "media_assets"
    provider: Mapped[str | None] = mapped_column(String(30), nullable=True)
    provider_asset_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    content_item_id: Mapped[str | None] = mapped_column(
        ForeignKey("lesson_content_items.id", ondelete="RESTRICT"), nullable=True, index=True
    )
    lesson_id: Mapped[str] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"), index=True)
    asset_id: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    kind: Mapped[str] = mapped_column(String(20))
    origin_key: Mapped[str] = mapped_column(String(500), unique=True)
    public: Mapped[bool] = mapped_column(Boolean, default=False)
    status: Mapped[str] = mapped_column(String(20), default="active", index=True)
    download_size_bytes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    checksum_sha256: Mapped[str | None] = mapped_column(String(64), nullable=True)
    __table_args__ = (CheckConstraint("kind IN ('hls', 'download', 'subtitle', 'thumbnail')"),)


class AccessPolicy(UUIDTimestampMixin, Base):
    __tablename__ = "access_policies"
    resource_type: Mapped[ResourceType] = mapped_column(Enum(ResourceType))
    resource_id: Mapped[str] = mapped_column(String(36))
    kind: Mapped[PolicyKind] = mapped_column(Enum(PolicyKind))
    required_tier: Mapped[str | None] = mapped_column(String(50))
    required_bundle_id: Mapped[str | None] = mapped_column(String(36))
    __table_args__ = (UniqueConstraint("resource_type", "resource_id"),)


class Entitlement(UUIDTimestampMixin, Base):
    __tablename__ = "entitlements"
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    source: Mapped[EntitlementSource] = mapped_column(Enum(EntitlementSource))
    status: Mapped[EntitlementStatus] = mapped_column(Enum(EntitlementStatus), index=True)
    resource_type: Mapped[ResourceType | None] = mapped_column(Enum(ResourceType))
    resource_id: Mapped[str | None] = mapped_column(String(36), index=True)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    purchase_id: Mapped[str | None] = mapped_column(
        ForeignKey("purchases.id", ondelete="CASCADE"), index=True, nullable=True
    )
    subscription_id: Mapped[str | None] = mapped_column(
        ForeignKey("subscriptions.id", ondelete="CASCADE"), index=True, nullable=True
    )
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    __table_args__ = (
        CheckConstraint(
            "NOT (purchase_id IS NOT NULL AND subscription_id IS NOT NULL)",
            name="ck_entitlement_single_commerce_source",
        ),
        Index(
            "ix_entitlements_resolution",
            "learner_id",
            "status",
            "resource_type",
            "resource_id",
            "expires_at",
        ),
    )


class PlatformSetting(Base):
    __tablename__ = "platform_settings"
    key: Mapped[str] = mapped_column(String(80), primary_key=True)
    value: Mapped[bool] = mapped_column(Boolean, nullable=False)
    version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    description: Mapped[str] = mapped_column(String(300), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow, nullable=False
    )
    updated_by: Mapped[str | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )


class Assessment(UUIDTimestampMixin, Base):
    __tablename__ = "assessments"
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    instructions: Mapped[list] = mapped_column(JSON, default=list)
    passing_percentage: Mapped[int] = mapped_column(Integer, default=70)
    time_limit_seconds: Mapped[int | None] = mapped_column(Integer)
    max_attempts: Mapped[int] = mapped_column(Integer, default=3)
    required_for_certificate: Mapped[bool] = mapped_column(Boolean, default=True)
    protection_policy: Mapped[ContentProtectionPolicy] = mapped_column(
        Enum(ContentProtectionPolicy), default=ContentProtectionPolicy.block_capture
    )
    status: Mapped[Lifecycle] = mapped_column(Enum(Lifecycle), default=Lifecycle.draft)
    __table_args__ = (
        CheckConstraint("passing_percentage BETWEEN 0 AND 100"),
        CheckConstraint("max_attempts > 0"),
    )


class AssessmentQuestion(UUIDTimestampMixin, Base):
    __tablename__ = "assessment_questions"
    assessment_id: Mapped[str] = mapped_column(
        ForeignKey("assessments.id", ondelete="CASCADE"), index=True
    )
    type: Mapped[QuestionType] = mapped_column(Enum(QuestionType))
    prompt: Mapped[str] = mapped_column(Text)
    points: Mapped[int] = mapped_column(Integer)
    position: Mapped[int] = mapped_column(Integer)
    grading_data: Mapped[dict] = mapped_column(JSON, default=dict)
    settings: Mapped[dict] = mapped_column(JSON, default=dict)
    explanation: Mapped[str | None] = mapped_column(Text)
    __table_args__ = (UniqueConstraint("assessment_id", "position"), CheckConstraint("points > 0"))


class AssessmentOption(UUIDTimestampMixin, Base):
    __tablename__ = "assessment_options"
    question_id: Mapped[str] = mapped_column(
        ForeignKey("assessment_questions.id", ondelete="CASCADE"), index=True
    )
    text: Mapped[str] = mapped_column(Text)
    hint: Mapped[str | None] = mapped_column(Text)
    position: Mapped[int] = mapped_column(Integer)
    __table_args__ = (UniqueConstraint("question_id", "position"),)


class AssessmentAttempt(UUIDTimestampMixin, Base):
    __tablename__ = "assessment_attempts"
    assessment_id: Mapped[str] = mapped_column(
        ForeignKey("assessments.id", ondelete="CASCADE"), index=True
    )
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    attempt_number: Mapped[int] = mapped_column(Integer)
    status: Mapped[AttemptStatus] = mapped_column(
        Enum(AttemptStatus), default=AttemptStatus.in_progress
    )
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    score: Mapped[int | None] = mapped_column(Integer)
    max_score: Mapped[int | None] = mapped_column(Integer)
    percentage: Mapped[float | None] = mapped_column(Numeric(6, 3))
    passed: Mapped[bool | None] = mapped_column(Boolean)
    result_json: Mapped[dict | None] = mapped_column(JSON)
    __table_args__ = (
        UniqueConstraint(
            "assessment_id", "learner_id", "attempt_number", name="uq_assessment_attempt_number"
        ),
    )


class AssessmentResponse(UUIDTimestampMixin, Base):
    __tablename__ = "assessment_responses"
    attempt_id: Mapped[str] = mapped_column(
        ForeignKey("assessment_attempts.id", ondelete="CASCADE"), index=True
    )
    question_id: Mapped[str] = mapped_column(
        ForeignKey("assessment_questions.id", ondelete="CASCADE")
    )
    answer_json: Mapped[dict] = mapped_column(JSON)
    earned_points: Mapped[int] = mapped_column(Integer)
    correct: Mapped[bool] = mapped_column(Boolean)
    __table_args__ = (UniqueConstraint("attempt_id", "question_id"),)


class IdempotencyRecord(UUIDTimestampMixin, Base):
    __tablename__ = "idempotency_records"
    principal_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    operation: Mapped[str] = mapped_column(String(100))
    key: Mapped[str] = mapped_column(String(120))
    request_hash: Mapped[str] = mapped_column(String(64))
    response_json: Mapped[dict | None] = mapped_column(JSON)
    status_code: Mapped[int | None] = mapped_column(Integer)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    __table_args__ = (UniqueConstraint("principal_id", "operation", "key"),)


class Certificate(UUIDTimestampMixin, Base):
    __tablename__ = "certificates"
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    course_id: Mapped[str] = mapped_column(ForeignKey("courses.id", ondelete="CASCADE"), index=True)
    credential_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    learner_name: Mapped[str] = mapped_column(String(120))
    course_title: Mapped[str] = mapped_column(String(200))
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    status: Mapped[CertificateStatus] = mapped_column(
        Enum(CertificateStatus), default=CertificateStatus.issued
    )
    grade: Mapped[str | None] = mapped_column(String(30))
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    __table_args__ = (
        UniqueConstraint("learner_id", "course_id", name="uq_active_certificate_context"),
        Index("ix_certificate_history", "learner_id", "issued_at", "id"),
    )


class CertificateRevocation(UUIDTimestampMixin, Base):
    __tablename__ = "certificate_revocations"
    certificate_id: Mapped[str] = mapped_column(
        ForeignKey("certificates.id", ondelete="CASCADE"), unique=True
    )
    actor_id: Mapped[str] = mapped_column(ForeignKey("users.id"))
    reason: Mapped[str] = mapped_column(String(500))
    revoked_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class AuditEvent(Base):
    __table_args__ = (
        Index("ix_audit_events_subject_occurred", "subject_type", "occurred_at", "id"),
    )
    __tablename__ = "audit_events"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    actor_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), index=True)
    event_type: Mapped[str] = mapped_column(String(100), index=True)
    subject_type: Mapped[str] = mapped_column(String(50))
    subject_id: Mapped[str] = mapped_column(String(64), index=True)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, index=True
    )
    correlation_id: Mapped[str | None] = mapped_column(String(64))
    data: Mapped[dict] = mapped_column(JSON, default=dict)


# --- Phase 7B: Commerce and Subscription Domain Models ---


class PaymentProvider(str, enum.Enum):
    apple_app_store = "appleAppStore"
    google_play = "googlePlay"
    stripe = "stripe"
    mock = "mock"


class CommerceProductType(str, enum.Enum):
    course = "course"
    bundle = "bundle"
    subscription = "subscription"
    certificate = "certificate"


class SubscriptionTier(str, enum.Enum):
    free = "free"
    standard = "standard"
    pro = "pro"
    student = "student"
    family = "family"
    institution = "institution"


class BillingInterval(str, enum.Enum):
    monthly = "monthly"
    annual = "annual"
    quarterly = "quarterly"


class PurchaseStatus(str, enum.Enum):
    pending = "pending"
    completed = "completed"
    failed = "failed"
    refunded = "refunded"
    revoked = "revoked"


class SubscriptionStatus(str, enum.Enum):
    active = "active"
    trialing = "trialing"
    in_grace_period = "inGracePeriod"
    billing_retry = "billingRetry"
    cancelled = "cancelled"
    paused = "paused"
    expired = "expired"
    revoked = "revoked"


class DiscountType(str, enum.Enum):
    percentage = "percentage"
    fixed_amount = "fixedAmount"


class ProviderEventStatus(str, enum.Enum):
    pending = "pending"
    processed = "processed"
    failed = "failed"
    ignored = "ignored"


class SubscriptionPlan(UUIDTimestampMixin, Base):
    __tablename__ = "subscription_plans"
    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    tier: Mapped[SubscriptionTier] = mapped_column(Enum(SubscriptionTier))
    billing_interval: Mapped[BillingInterval] = mapped_column(Enum(BillingInterval))
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    price_cents: Mapped[int] = mapped_column(Integer)
    formatted_price: Mapped[str] = mapped_column(String(30))
    currency_code: Mapped[str] = mapped_column(String(10), default="USD")
    trial_days: Mapped[int] = mapped_column(Integer, default=0)
    introductory_offer_json: Mapped[dict | None] = mapped_column(JSON)
    benefits: Mapped[list] = mapped_column(JSON, default=list)
    is_popular: Mapped[bool] = mapped_column(Boolean, default=False)
    is_recommended: Mapped[bool] = mapped_column(Boolean, default=False)
    savings_percent: Mapped[int] = mapped_column(Integer, default=0)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)


class CommerceProduct(UUIDTimestampMixin, Base):
    __tablename__ = "commerce_products"
    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    product_type: Mapped[CommerceProductType] = mapped_column(
        Enum(CommerceProductType), default=CommerceProductType.course
    )
    course_id: Mapped[str | None] = mapped_column(
        ForeignKey("courses.id", ondelete="SET NULL"), index=True
    )
    bundle_id: Mapped[str | None] = mapped_column(String(64), index=True)
    course_ids: Mapped[list] = mapped_column(JSON, default=list)
    title: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    price_cents: Mapped[int] = mapped_column(Integer)
    formatted_price: Mapped[str] = mapped_column(String(30))
    currency_code: Mapped[str] = mapped_column(String(10), default="USD")
    original_price_cents: Mapped[int | None] = mapped_column(Integer)
    discount_percent: Mapped[int] = mapped_column(Integer, default=0)
    features: Mapped[list] = mapped_column(JSON, default=list)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)


class ProviderProductMapping(UUIDTimestampMixin, Base):
    __tablename__ = "provider_product_mappings"
    internal_product_type: Mapped[str] = mapped_column(String(30))  # plan, course, bundle
    internal_product_id: Mapped[str] = mapped_column(String(64), index=True)
    provider: Mapped[PaymentProvider] = mapped_column(Enum(PaymentProvider), index=True)
    provider_product_id: Mapped[str] = mapped_column(String(255), index=True)
    __table_args__ = (
        UniqueConstraint("provider", "provider_product_id", name="uq_provider_product"),
    )


class PaymentTransaction(UUIDTimestampMixin, Base):
    __tablename__ = "payment_transactions"
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[PaymentProvider] = mapped_column(Enum(PaymentProvider), index=True)
    provider_transaction_id: Mapped[str] = mapped_column(String(255), index=True)
    provider_product_id: Mapped[str | None] = mapped_column(String(255), index=True)
    idempotency_key: Mapped[str | None] = mapped_column(String(120), index=True)
    status: Mapped[str] = mapped_column(String(30), default="pending", index=True)
    amount_cents: Mapped[int | None] = mapped_column(Integer)
    currency_code: Mapped[str | None] = mapped_column(String(10))
    receipt_payload: Mapped[str | None] = mapped_column(Text)
    error_message: Mapped[str | None] = mapped_column(Text)
    raw_response_json: Mapped[dict] = mapped_column(JSON, default=dict)
    __table_args__ = (
        UniqueConstraint("provider", "provider_transaction_id", name="uq_provider_transaction"),
    )


class Purchase(UUIDTimestampMixin, Base):
    __tablename__ = "purchases"
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    product_id: Mapped[str] = mapped_column(String(64), index=True)
    product_type: Mapped[CommerceProductType] = mapped_column(Enum(CommerceProductType))
    order_id: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    transaction_id: Mapped[str | None] = mapped_column(
        ForeignKey("payment_transactions.id", ondelete="SET NULL"), index=True
    )
    status: Mapped[PurchaseStatus] = mapped_column(
        Enum(PurchaseStatus), default=PurchaseStatus.completed, index=True
    )
    purchased_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, index=True
    )
    amount_cents: Mapped[int | None] = mapped_column(Integer)
    currency_code: Mapped[str | None] = mapped_column(String(10))
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    __table_args__ = (
        Index("ix_purchases_learner_purchased_at", "learner_id", "purchased_at", "id"),
    )


class Subscription(UUIDTimestampMixin, Base):
    __tablename__ = "subscriptions"
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    provider: Mapped[PaymentProvider] = mapped_column(Enum(PaymentProvider), index=True)
    plan_id: Mapped[str] = mapped_column(String(64), index=True)
    tier: Mapped[SubscriptionTier] = mapped_column(Enum(SubscriptionTier))
    billing_interval: Mapped[BillingInterval] = mapped_column(Enum(BillingInterval))
    status: Mapped[SubscriptionStatus] = mapped_column(
        Enum(SubscriptionStatus), default=SubscriptionStatus.active, index=True
    )
    current_period_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    current_period_end: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    cancel_at_period_end: Mapped[bool] = mapped_column(Boolean, default=False)
    renews_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    trial_start_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    trial_end_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    trial_duration_days: Mapped[int | None] = mapped_column(Integer)
    introductory_price_cents: Mapped[int | None] = mapped_column(Integer)
    cancellation_reason: Mapped[str | None] = mapped_column(String(500))
    original_transaction_id: Mapped[str | None] = mapped_column(String(255), index=True)
    latest_transaction_id: Mapped[str | None] = mapped_column(String(255), index=True)
    provider_state_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), index=True
    )
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    __table_args__ = (
        UniqueConstraint(
            "provider",
            "original_transaction_id",
            name="uq_subscription_provider_original_transaction",
        ),
        Index(
            "ix_subscriptions_learner_status_created",
            "learner_id",
            "status",
            "created_at",
        ),
    )


class Coupon(UUIDTimestampMixin, Base):
    __tablename__ = "coupons"
    code: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    discount_type: Mapped[DiscountType] = mapped_column(Enum(DiscountType))
    discount_value: Mapped[int] = mapped_column(Integer)
    valid_from: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    valid_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), index=True)
    max_redemptions: Mapped[int | None] = mapped_column(Integer)
    redemption_count: Mapped[int] = mapped_column(Integer, default=0)
    applicable_product_ids: Mapped[list] = mapped_column(JSON, default=list)
    description: Mapped[str | None] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)


class CouponRedemption(UUIDTimestampMixin, Base):
    __tablename__ = "coupon_redemptions"
    coupon_id: Mapped[str] = mapped_column(ForeignKey("coupons.id", ondelete="CASCADE"), index=True)
    learner_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    order_id: Mapped[str | None] = mapped_column(String(100), index=True)
    redeemed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    __table_args__ = (
        UniqueConstraint("coupon_id", "learner_id", name="uq_coupon_learner_redemption"),
    )


class ProviderEvent(Base):
    __tablename__ = "provider_events"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    provider: Mapped[PaymentProvider] = mapped_column(Enum(PaymentProvider), index=True)
    event_id: Mapped[str] = mapped_column(String(255), index=True)
    event_type: Mapped[str] = mapped_column(String(100), index=True)
    payload_json: Mapped[dict] = mapped_column(JSON, default=dict)
    status: Mapped[ProviderEventStatus] = mapped_column(
        Enum(ProviderEventStatus), default=ProviderEventStatus.pending, index=True
    )
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, index=True
    )
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    error_message: Mapped[str | None] = mapped_column(Text)
    __table_args__ = (UniqueConstraint("provider", "event_id", name="uq_provider_event"),)
