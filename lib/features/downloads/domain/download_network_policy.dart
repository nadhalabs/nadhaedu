enum NetworkDownloadPreference { wifiOnly, allowCellular }

final class DownloadNetworkPolicy {
  const DownloadNetworkPolicy({
    this.preference = NetworkDownloadPreference.wifiOnly,
    this.warnOnLargeCellular = true,
    this.maxCellularSizeBytes = 50 * 1024 * 1024, // 50MB
  });

  factory DownloadNetworkPolicy.fromJson(Map<String, Object?> json) =>
      DownloadNetworkPolicy(
        preference: NetworkDownloadPreference.values.byName(
          json['preference'] as String? ??
              NetworkDownloadPreference.wifiOnly.name,
        ),
        warnOnLargeCellular: json['warnOnLargeCellular'] as bool? ?? true,
        maxCellularSizeBytes:
            json['maxCellularSizeBytes'] as int? ?? 50 * 1024 * 1024,
      );

  final NetworkDownloadPreference preference;
  final bool warnOnLargeCellular;
  final int maxCellularSizeBytes;

  DownloadNetworkPolicy copyWith({
    NetworkDownloadPreference? preference,
    bool? warnOnLargeCellular,
    int? maxCellularSizeBytes,
  }) => DownloadNetworkPolicy(
    preference: preference ?? this.preference,
    warnOnLargeCellular: warnOnLargeCellular ?? this.warnOnLargeCellular,
    maxCellularSizeBytes: maxCellularSizeBytes ?? this.maxCellularSizeBytes,
  );

  Map<String, Object?> toJson() => {
    'preference': preference.name,
    'warnOnLargeCellular': warnOnLargeCellular,
    'maxCellularSizeBytes': maxCellularSizeBytes,
  };
}
