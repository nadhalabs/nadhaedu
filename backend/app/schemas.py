from datetime import datetime
from uuid import uuid4
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=lambda s: s.split("_")[0] + "".join(x.title() for x in s.split("_")[1:]),
        populate_by_name=True,
    )


class Register(CamelModel):
    email: EmailStr
    password: str = Field(min_length=10, max_length=200)
    display_name: str = Field(min_length=1, max_length=120)


class Login(CamelModel):
    email: EmailStr
    password: str


class Refresh(CamelModel):
    refresh_token: str


class Logout(CamelModel):
    refresh_token: str
    all_devices: bool = False


class ResetRequest(CamelModel):
    email: EmailStr


class ResetConfirm(CamelModel):
    email: EmailStr
    verification_code: str
    new_password: str = Field(min_length=10, max_length=200)


class Onboarding(CamelModel):
    display_name: str = Field(min_length=1, max_length=120)


class BookmarkIn(CamelModel):
    course_id: str
    bookmarked: bool


class CourseIds(CamelModel):
    ids: list[str] = Field(max_length=50)


class RecentlyViewedIn(CamelModel):
    course_id: str


class ProgressMutationIn(CamelModel):
    id: str = Field(max_length=100)
    lesson_id: str
    kind: str
    position_seconds: int = Field(ge=0)
    duration_seconds: int = Field(ge=0)
    completed: bool
    occurred_at: datetime
    base_revision: int = Field(ge=0)


class ProgressSync(CamelModel):
    mutations: list[ProgressMutationIn] = Field(max_length=100)


class Answer(CamelModel):
    question_id: str
    type: str
    selected_option_id: str | None = None
    selected_option_ids: list[str] | None = None
    selected_value: bool | None = None
    text_content: str | None = Field(default=None, max_length=10000)


class Submission(CamelModel):
    attempt_id: str
    answers: list[Answer] = Field(max_length=500)


class CertificateClaim(CamelModel):
    course_id: str


class RevocationIn(CamelModel):
    reason: str = Field(min_length=3, max_length=500)


# --- Phase 7B Commerce Schemas ---


class CouponValidateIn(CamelModel):
    code: str = Field(min_length=1, max_length=50)
    product_id: str | None = None


class TransactionVerifyIn(CamelModel):
    transaction_id: str = Field(min_length=1, max_length=120)
    provider: str
    provider_transaction_id: str = Field(min_length=1, max_length=255)
    receipt_payload: str | None = None
    amount_cents: int | None = None
    currency_code: str | None = None
    learner_id: str
    idempotency_key: str | None = None
    coupon_code: str | None = None


class RestoreTransactionItem(CamelModel):
    transaction_id: str
    provider: str
    provider_transaction_id: str
    receipt_payload: str | None = None


class RestorePurchasesIn(CamelModel):
    learner_id: str
    transactions: list[RestoreTransactionItem] = Field(default_factory=list)


class CancelSubscriptionIn(CamelModel):
    learner_id: str
    reason: str | None = Field(default=None, max_length=500)


class ChangeSubscriptionPlanIn(CamelModel):
    learner_id: str
    new_plan_id: str
    proration_mode: str | None = None


# --- Phase 8 Download Schemas ---


class DownloadAuthorizeIn(CamelModel):
    resource_type: str = "lesson"
    resource_id: str
    quality: str = "standard"  # dataSaver, standard, high


class DownloadRevalidateIn(CamelModel):
    resource_ids: list[str] = Field(max_length=100)


# --- Phase 9 Platform Experience Schemas ---


class NotificationItemOut(CamelModel):
    id: str
    type: str
    title: str
    body: str
    destination_type: str
    destination_payload: dict
    priority: str
    image_url: str | None = None
    metadata: dict = Field(default_factory=dict)
    read_at: datetime | None = None
    expires_at: datetime | None = None
    created_at: datetime


class NotificationListOut(CamelModel):
    items: list[NotificationItemOut]
    unread_count: int
    next_cursor: str | None = None


class NotificationPreferencesIn(CamelModel):
    email_course_updates: bool = True
    email_learning_reminders: bool = True
    email_marketing: bool = False
    push_course_updates: bool = True
    push_learning_reminders: bool = True
    push_live_classes: bool = True
    push_assessment_updates: bool = True
    push_certificate_updates: bool = True
    push_payment_events: bool = True
    in_app_course_updates: bool = True
    in_app_reminders: bool = True
    in_app_certificates: bool = True


class NotificationPreferencesOut(CamelModel):
    email_course_updates: bool = True
    email_learning_reminders: bool = True
    email_marketing: bool = False
    email_security_alerts: bool = True
    push_course_updates: bool = True
    push_learning_reminders: bool = True
    push_live_classes: bool = True
    push_assessment_updates: bool = True
    push_certificate_updates: bool = True
    push_payment_events: bool = True
    push_security_alerts: bool = True
    in_app_course_updates: bool = True
    in_app_reminders: bool = True
    in_app_certificates: bool = True


class PushTokenRegisterIn(CamelModel):
    token: str = Field(min_length=16, max_length=500)
    platform: Literal["android", "ios", "web"]
    device_name: str | None = Field(default=None, max_length=120)


class LearnerProfileOut(CamelModel):
    id: str
    email: str
    display_name: str
    avatar_url: str | None = None
    phone: str | None = None
    learning_interests: list[str] = Field(default_factory=list)
    language_preference: str = "en"
    member_since: datetime


class LearnerProfileUpdateIn(CamelModel):
    display_name: str | None = Field(default=None, min_length=1, max_length=120)
    phone: str | None = Field(default=None, max_length=30)
    learning_interests: list[str] | None = None
    language_preference: str | None = None
    avatar_url: str | None = Field(default=None, max_length=500)


class AvatarUploadIntentOut(CamelModel):
    upload_url: str
    public_url: str
    expires_in_seconds: int = 300
    max_bytes: int = 5 * 1024 * 1024
    allowed_content_types: list[str] = Field(
        default_factory=lambda: ["image/jpeg", "image/png", "image/webp"]
    )


class AvatarUpdateIn(CamelModel):
    avatar_url: str = Field(min_length=1, max_length=500)


class PasswordChangeIn(CamelModel):
    current_password: str
    new_password: str = Field(min_length=10, max_length=200)


class SessionOut(CamelModel):
    id: str
    device_name: str | None = None
    platform: str | None = None
    last_active_at: datetime
    created_at: datetime
    is_current: bool = False


class SessionListOut(CamelModel):
    sessions: list[SessionOut]


class AccountDeleteIn(CamelModel):
    password: str
    confirmation_text: str


class SyncedUserSettingsIn(CamelModel):
    theme_mode: str | None = None
    language: str | None = None
    autoplay_next_lesson: bool | None = None
    preferred_playback_speed: float | None = None
    captions_default_enabled: bool | None = None
    reduced_motion: bool | None = None
    high_contrast: bool | None = None
    download_quality: str | None = None
    download_wifi_only: bool | None = None


class SyncedUserSettingsOut(CamelModel):
    theme_mode: str = "system"
    language: str = "en"
    autoplay_next_lesson: bool = True
    preferred_playback_speed: float = 1.0
    captions_default_enabled: bool = False
    reduced_motion: bool = False
    high_contrast: bool = False
    download_quality: str = "standard"
    download_wifi_only: bool = True


# --- CMS Phase 1 Schemas ---


class CmsDashboardMetricsOut(CamelModel):
    total_users: int
    total_learners: int
    active_learners: int
    total_courses: int
    published_courses: int
    draft_courses: int
    archived_courses: int
    total_enrollments: int
    total_purchases: int
    active_subscriptions: int
    total_certificates_issued: int
    recent_completions: int


class CmsSystemReadinessWarningOut(CamelModel):
    code: str
    message: str


class CmsSystemReadinessOut(CamelModel):
    database: str
    cache: str
    migration_revision: str
    is_ready: bool
    warnings: list[CmsSystemReadinessWarningOut] = Field(default_factory=list)


class CmsRecentPurchaseOut(CamelModel):
    id: str
    order_id: str
    learner_id: str
    learner_email: str | None = None
    product_id: str
    product_type: str
    amount_cents: int | None = None
    currency_code: str | None = None
    status: str
    purchased_at: datetime


class CmsRecentActivityOut(CamelModel):
    id: str
    actor_id: str | None = None
    actor_email: str | None = None
    actor_name: str | None = None
    action: str
    target_entity: str
    target_id: str
    timestamp: datetime
    result: str = "success"
    reason: str | None = None
    metadata: dict = Field(default_factory=dict)


class CmsDashboardOut(CamelModel):
    metrics: CmsDashboardMetricsOut
    recent_purchases: list[CmsRecentPurchaseOut] = Field(default_factory=list)
    recent_activity: list[CmsRecentActivityOut] = Field(default_factory=list)
    system_readiness: CmsSystemReadinessOut


class CmsCourseSummaryOut(CamelModel):
    cover_reference: str | None = None
    curriculum_id: str | None = None
    standard_id: str | None = None
    stream_id: str | None = None
    subject_id: str | None = None
    id: str
    title: str
    subtitle: str
    level: str
    policy_kind: str
    status: str
    module_count: int
    lesson_count: int
    enrollment_count: int
    duration_seconds: int
    created_at: datetime
    published_at: datetime | None = None


class CmsCourseListOut(CamelModel):
    items: list[CmsCourseSummaryOut]
    total: int


class CmsCourseStatusUpdateIn(CamelModel):
    status: Literal["draft", "published", "archived", "unavailable"]
    reason: str | None = Field(default=None, max_length=500)


class CmsUserSummaryOut(CamelModel):
    id: str
    email: str
    display_name: str
    role: str
    is_active: bool
    onboarding_complete: bool
    enrollment_count: int
    created_at: datetime


class CmsUserListOut(CamelModel):
    items: list[CmsUserSummaryOut]
    total: int


class CmsAuditLogOut(CamelModel):
    id: str
    actor_id: str | None = None
    actor_email: str | None = None
    actor_name: str | None = None
    action: str
    target_entity: str
    target_id: str
    timestamp: datetime
    result: str = "success"
    reason: str | None = None
    data: dict = Field(default_factory=dict)


class CmsAuditLogListOut(CamelModel):
    items: list[CmsAuditLogOut]
    total: int
    page: int
    page_size: int


# --- CMS Phase 2: Content, Courses & Learning Management Schemas ---


class CmsCategoryOut(CamelModel):
    id: str
    name: str
    icon_name: str


class CmsCategoryCreateIn(CamelModel):
    name: str = Field(min_length=1, max_length=100)
    icon_name: str = Field(default="school", max_length=60)


class CmsLessonDetailOut(CamelModel):
    id: str
    module_id: str
    title: str
    position: int
    duration_seconds: int
    content_type: str
    content_ref: str
    is_preview: bool
    is_downloadable: bool
    policy_kind: str
    protection_policy: str
    created_at: datetime
    updated_at: datetime


class CmsLessonCreateIn(CamelModel):
    title: str = Field(min_length=1, max_length=200)
    duration_seconds: int = Field(default=0, ge=0)
    content_type: str = Field(default="video", max_length=30)
    content_ref: str = Field(
        default_factory=lambda: f"lesson-shell:{uuid4()}", min_length=1, max_length=255
    )
    is_preview: bool = False
    is_downloadable: bool = True
    policy_kind: str = "inherit"
    protection_policy: str = "blockCaptureWhereSupported"


class CmsLessonUpdateIn(CamelModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    duration_seconds: int | None = Field(default=None, ge=0)
    content_type: str | None = Field(default=None, max_length=30)
    content_ref: str | None = Field(default=None, min_length=1, max_length=255)
    is_preview: bool | None = None
    is_downloadable: bool | None = None
    policy_kind: str | None = None
    protection_policy: str | None = None


class CmsReorderLessonsIn(CamelModel):
    lesson_ids: list[str]


class CmsModuleDetailOut(CamelModel):
    id: str
    course_id: str
    title: str
    position: int
    policy_kind: str
    lessons: list[CmsLessonDetailOut] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


class CmsModuleCreateIn(CamelModel):
    title: str = Field(min_length=1, max_length=200)
    policy_kind: str = "inherit"


class CmsModuleUpdateIn(CamelModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    policy_kind: str | None = None


class CmsReorderModulesIn(CamelModel):
    module_ids: list[str]


class CmsQuestionOptionOut(CamelModel):
    id: str
    text: str
    hint: str | None = None
    position: int


class CmsQuestionOptionIn(CamelModel):
    id: str | None = None
    text: str = Field(min_length=1)
    hint: str | None = None
    position: int | None = None


class CmsQuestionDetailOut(CamelModel):
    id: str
    assessment_id: str
    type: str
    prompt: str
    points: int
    position: int
    explanation: str | None = None
    settings: dict = Field(default_factory=dict)
    options: list[CmsQuestionOptionOut] = Field(default_factory=list)
    grading_data: dict = Field(default_factory=dict)
    created_at: datetime
    updated_at: datetime


class CmsQuestionCreateIn(CamelModel):
    type: str
    prompt: str = Field(min_length=1)
    points: int = Field(default=1, ge=1)
    explanation: str | None = None
    settings: dict = Field(default_factory=dict)
    options: list[CmsQuestionOptionIn] = Field(default_factory=list)
    grading_data: dict = Field(default_factory=dict)


class CmsQuestionUpdateIn(CamelModel):
    type: str | None = None
    prompt: str | None = Field(default=None, min_length=1)
    points: int | None = Field(default=None, ge=1)
    explanation: str | None = None
    settings: dict | None = None
    options: list[CmsQuestionOptionIn] | None = None
    grading_data: dict | None = None


class CmsReorderQuestionsIn(CamelModel):
    question_ids: list[str]


class CmsAssessmentSummaryOut(CamelModel):
    id: str
    course_id: str
    title: str
    description: str
    passing_percentage: int
    time_limit_seconds: int | None = None
    max_attempts: int
    required_for_certificate: bool
    protection_policy: str
    status: str
    question_count: int
    created_at: datetime
    updated_at: datetime


class CmsAssessmentDetailOut(CamelModel):
    id: str
    course_id: str
    title: str
    description: str
    instructions: list[str] = Field(default_factory=list)
    passing_percentage: int
    time_limit_seconds: int | None = None
    max_attempts: int
    required_for_certificate: bool
    protection_policy: str
    status: str
    questions: list[CmsQuestionDetailOut] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


class CmsAssessmentCreateIn(CamelModel):
    title: str = Field(min_length=1, max_length=200)
    description: str = ""
    instructions: list[str] = Field(default_factory=list)
    passing_percentage: int = Field(default=70, ge=0, le=100)
    time_limit_seconds: int | None = Field(default=None, ge=1)
    max_attempts: int = Field(default=3, ge=1)
    required_for_certificate: bool = True
    protection_policy: str = "blockCaptureWhereSupported"
    status: str = "draft"


class CmsAssessmentUpdateIn(CamelModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    instructions: list[str] | None = None
    passing_percentage: int | None = Field(default=None, ge=0, le=100)
    time_limit_seconds: int | None = Field(default=None, ge=1)
    max_attempts: int | None = Field(default=None, ge=1)
    required_for_certificate: bool | None = None
    protection_policy: str | None = None
    status: str | None = None


class CmsCourseValidationItemOut(CamelModel):
    code: str
    message: str
    severity: Literal["error", "warning"]
    field: str | None = None


class CmsCourseValidationOut(CamelModel):
    is_valid: bool
    can_publish: bool
    errors: list[CmsCourseValidationItemOut] = Field(default_factory=list)
    warnings: list[CmsCourseValidationItemOut] = Field(default_factory=list)


class CmsCourseDetailOut(CamelModel):
    cover_reference: str | None = None
    curriculum_id: str | None = None
    standard_id: str | None = None
    stream_id: str | None = None
    subject_id: str | None = None
    id: str
    title: str
    subtitle: str
    description: str
    level: str
    language_code: str
    policy_kind: str
    protection_policy: str
    required_tier: str | None = None
    required_bundle_id: str | None = None
    status: str
    published_at: datetime | None = None
    rating: float
    rating_count: int
    duration_seconds: int
    learning_outcomes: list[str] = Field(default_factory=list)
    prerequisites: list[str] = Field(default_factory=list)
    categories: list[CmsCategoryOut] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    modules: list[CmsModuleDetailOut] = Field(default_factory=list)
    assessments: list[CmsAssessmentSummaryOut] = Field(default_factory=list)
    validation: CmsCourseValidationOut
    created_at: datetime
    updated_at: datetime


class CmsCourseCreateIn(CamelModel):
    curriculum_id: str | None = None
    standard_id: str | None = None
    stream_id: str | None = None
    subject_id: str | None = None
    title: str = Field(min_length=1, max_length=200)
    subtitle: str = Field(default="", max_length=300)
    description: str = ""
    level: str = "allLevels"
    language_code: str = "en"
    policy_kind: str = "free"
    protection_policy: str = "blockCaptureWhereSupported"
    required_tier: str | None = None
    category_ids: list[str] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    learning_outcomes: list[str] = Field(default_factory=list)
    prerequisites: list[str] = Field(default_factory=list)


class CmsCourseUpdateIn(CamelModel):
    curriculum_id: str | None = None
    standard_id: str | None = None
    stream_id: str | None = None
    subject_id: str | None = None
    title: str | None = Field(default=None, min_length=1, max_length=200)
    subtitle: str | None = Field(default=None, max_length=300)
    description: str | None = None
    level: str | None = None
    language_code: str | None = None
    policy_kind: str | None = None
    protection_policy: str | None = None
    required_tier: str | None = None
    category_ids: list[str] | None = None
    tags: list[str] | None = None
    learning_outcomes: list[str] | None = None
    prerequisites: list[str] | None = None


class CmsPublishCourseIn(CamelModel):
    reason: str | None = Field(default=None, max_length=500)
