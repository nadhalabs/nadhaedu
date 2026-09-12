import 'package:flutter/foundation.dart';

@immutable
final class LearnerProfile {
  const LearnerProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.memberSince,
    this.avatarUrl,
    this.phone,
    this.learningInterests = const [],
    this.languagePreference = 'en',
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? phone;
  final List<String> learningInterests;
  final String languagePreference;
  final DateTime memberSince;

  LearnerProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? phone,
    List<String>? learningInterests,
    String? languagePreference,
  }) => LearnerProfile(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    phone: phone ?? this.phone,
    learningInterests: learningInterests ?? this.learningInterests,
    languagePreference: languagePreference ?? this.languagePreference,
    memberSince: memberSince,
  );

  factory LearnerProfile.fromJson(Map<String, dynamic> json) => LearnerProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    displayName: (json['displayName'] as String?) ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    phone: json['phone'] as String?,
    learningInterests:
        (json['learningInterests'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    languagePreference: (json['languagePreference'] as String?) ?? 'en',
    memberSince: json['memberSince'] != null
        ? DateTime.parse(json['memberSince'] as String)
        : DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'phone': phone,
    'learningInterests': learningInterests,
    'languagePreference': languagePreference,
    'memberSince': memberSince.toIso8601String(),
  };
}
