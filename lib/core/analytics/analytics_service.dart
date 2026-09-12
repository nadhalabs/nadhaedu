abstract interface class AnalyticsService {
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const {},
  });
}

final class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  Future<void> track(
    String event, {
    Map<String, Object?> properties = const {},
  }) async {}
}
