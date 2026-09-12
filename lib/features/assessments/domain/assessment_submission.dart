sealed class QuestionAnswer {
  const QuestionAnswer({required this.questionId});
  final String questionId;

  bool get isAnswered;
}

final class SingleChoiceAnswer extends QuestionAnswer {
  const SingleChoiceAnswer({
    required super.questionId,
    required this.selectedOptionId,
  });
  final String? selectedOptionId;

  @override
  bool get isAnswered =>
      selectedOptionId != null && selectedOptionId!.isNotEmpty;
}

final class MultipleChoiceAnswer extends QuestionAnswer {
  const MultipleChoiceAnswer({
    required super.questionId,
    required this.selectedOptionIds,
  });
  final Set<String> selectedOptionIds;

  @override
  bool get isAnswered => selectedOptionIds.isNotEmpty;
}

final class TrueFalseAnswer extends QuestionAnswer {
  const TrueFalseAnswer({
    required super.questionId,
    required this.selectedValue,
  });
  final bool? selectedValue;

  @override
  bool get isAnswered => selectedValue != null;
}

final class TextResponseAnswer extends QuestionAnswer {
  const TextResponseAnswer({
    required super.questionId,
    required this.textContent,
  });
  final String textContent;

  @override
  bool get isAnswered => textContent.trim().isNotEmpty;
}

final class AssessmentSubmission {
  const AssessmentSubmission({
    required this.assessmentId,
    required this.attemptId,
    required this.durationTaken,
    required this.answers,
    required this.idempotencyKey,
    required this.submittedAt,
  });

  final String assessmentId;
  final String attemptId;
  final Duration durationTaken;
  final Map<String, QuestionAnswer> answers;
  final String idempotencyKey;
  final DateTime submittedAt;
}
