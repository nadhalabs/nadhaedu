import 'package:flutter/foundation.dart';

@immutable
final class NotificationPreferences {
  const NotificationPreferences({
    this.emailCourseUpdates = true,
    this.emailLearningReminders = true,
    this.emailMarketing = false,
    this.emailSecurityAlerts = true,
    this.pushCourseUpdates = true,
    this.pushLearningReminders = true,
    this.pushLiveClasses = true,
    this.pushAssessmentUpdates = true,
    this.pushCertificateUpdates = true,
    this.pushPaymentEvents = true,
    this.pushSecurityAlerts = true,
    this.inAppCourseUpdates = true,
    this.inAppReminders = true,
    this.inAppCertificates = true,
  });

  final bool emailCourseUpdates;
  final bool emailLearningReminders;
  final bool emailMarketing;
  final bool emailSecurityAlerts; // Non-suppressible
  final bool pushCourseUpdates;
  final bool pushLearningReminders;
  final bool pushLiveClasses;
  final bool pushAssessmentUpdates;
  final bool pushCertificateUpdates;
  final bool pushPaymentEvents;
  final bool pushSecurityAlerts; // Non-suppressible
  final bool inAppCourseUpdates;
  final bool inAppReminders;
  final bool inAppCertificates;

  NotificationPreferences copyWith({
    bool? emailCourseUpdates,
    bool? emailLearningReminders,
    bool? emailMarketing,
    bool? pushCourseUpdates,
    bool? pushLearningReminders,
    bool? pushLiveClasses,
    bool? pushAssessmentUpdates,
    bool? pushCertificateUpdates,
    bool? pushPaymentEvents,
    bool? inAppCourseUpdates,
    bool? inAppReminders,
    bool? inAppCertificates,
  }) => NotificationPreferences(
    emailCourseUpdates: emailCourseUpdates ?? this.emailCourseUpdates,
    emailLearningReminders:
        emailLearningReminders ?? this.emailLearningReminders,
    emailMarketing: emailMarketing ?? this.emailMarketing,
    emailSecurityAlerts: emailSecurityAlerts,
    pushCourseUpdates: pushCourseUpdates ?? this.pushCourseUpdates,
    pushLearningReminders: pushLearningReminders ?? this.pushLearningReminders,
    pushLiveClasses: pushLiveClasses ?? this.pushLiveClasses,
    pushAssessmentUpdates: pushAssessmentUpdates ?? this.pushAssessmentUpdates,
    pushCertificateUpdates:
        pushCertificateUpdates ?? this.pushCertificateUpdates,
    pushPaymentEvents: pushPaymentEvents ?? this.pushPaymentEvents,
    pushSecurityAlerts: pushSecurityAlerts,
    inAppCourseUpdates: inAppCourseUpdates ?? this.inAppCourseUpdates,
    inAppReminders: inAppReminders ?? this.inAppReminders,
    inAppCertificates: inAppCertificates ?? this.inAppCertificates,
  );

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        emailCourseUpdates: json['emailCourseUpdates'] as bool? ?? true,
        emailLearningReminders: json['emailLearningReminders'] as bool? ?? true,
        emailMarketing: json['emailMarketing'] as bool? ?? false,
        emailSecurityAlerts: json['emailSecurityAlerts'] as bool? ?? true,
        pushCourseUpdates: json['pushCourseUpdates'] as bool? ?? true,
        pushLearningReminders: json['pushLearningReminders'] as bool? ?? true,
        pushLiveClasses: json['pushLiveClasses'] as bool? ?? true,
        pushAssessmentUpdates: json['pushAssessmentUpdates'] as bool? ?? true,
        pushCertificateUpdates: json['pushCertificateUpdates'] as bool? ?? true,
        pushPaymentEvents: json['pushPaymentEvents'] as bool? ?? true,
        pushSecurityAlerts: json['pushSecurityAlerts'] as bool? ?? true,
        inAppCourseUpdates: json['inAppCourseUpdates'] as bool? ?? true,
        inAppReminders: json['inAppReminders'] as bool? ?? true,
        inAppCertificates: json['inAppCertificates'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
    'emailCourseUpdates': emailCourseUpdates,
    'emailLearningReminders': emailLearningReminders,
    'emailMarketing': emailMarketing,
    'emailSecurityAlerts': emailSecurityAlerts,
    'pushCourseUpdates': pushCourseUpdates,
    'pushLearningReminders': pushLearningReminders,
    'pushLiveClasses': pushLiveClasses,
    'pushAssessmentUpdates': pushAssessmentUpdates,
    'pushCertificateUpdates': pushCertificateUpdates,
    'pushPaymentEvents': pushPaymentEvents,
    'pushSecurityAlerts': pushSecurityAlerts,
    'inAppCourseUpdates': inAppCourseUpdates,
    'inAppReminders': inAppReminders,
    'inAppCertificates': inAppCertificates,
  };
}
