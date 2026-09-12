final class CourseStorageUsage {
  const CourseStorageUsage({
    required this.courseId,
    required this.courseTitle,
    required this.bytesUsed,
    required this.taskCount,
    required this.completedCount,
  });

  final String courseId;
  final String courseTitle;
  final int bytesUsed;
  final int taskCount;
  final int completedCount;
}

final class StorageSummary {
  const StorageSummary({
    required this.totalBytesUsed,
    required this.availableDeviceBytes,
    required this.totalDeviceBytes,
    required this.courses,
    required this.totalTasksCount,
    required this.completedTasksCount,
  });

  final int totalBytesUsed;
  final int availableDeviceBytes;
  final int totalDeviceBytes;
  final List<CourseStorageUsage> courses;
  final int totalTasksCount;
  final int completedTasksCount;

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(d >= 10 || i == 0 ? 0 : 1)} ${suffixes[i]}';
  }
}
