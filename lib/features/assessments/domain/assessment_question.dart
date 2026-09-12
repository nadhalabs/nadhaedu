enum QuestionType { singleChoice, multipleChoice, trueFalse, textResponse }

final class QuestionOption {
  const QuestionOption({required this.id, required this.text, this.hint});

  final String id;
  final String text;
  final String? hint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionOption &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          hint == other.hint;

  @override
  int get hashCode => Object.hash(id, text, hint);
}

sealed class Question {
  const Question({
    required this.id,
    required this.prompt,
    required this.type,
    this.points = 1,
    this.explanationGuidance,
  });

  final String id;
  final String prompt;
  final QuestionType type;
  final int points;
  final String? explanationGuidance;
}

final class SingleChoiceQuestion extends Question {
  const SingleChoiceQuestion({
    required super.id,
    required super.prompt,
    required this.options,
    super.points = 1,
    super.explanationGuidance,
  }) : super(type: QuestionType.singleChoice);

  final List<QuestionOption> options;
}

final class MultipleChoiceQuestion extends Question {
  const MultipleChoiceQuestion({
    required super.id,
    required super.prompt,
    required this.options,
    this.minSelections = 1,
    this.maxSelections,
    super.points = 1,
    super.explanationGuidance,
  }) : super(type: QuestionType.multipleChoice);

  final List<QuestionOption> options;
  final int minSelections;
  final int? maxSelections;
}

final class TrueFalseQuestion extends Question {
  const TrueFalseQuestion({
    required super.id,
    required super.prompt,
    super.points = 1,
    super.explanationGuidance,
  }) : super(type: QuestionType.trueFalse);
}

final class TextResponseQuestion extends Question {
  const TextResponseQuestion({
    required super.id,
    required super.prompt,
    this.placeholder = 'Type your response here...',
    this.minWords = 1,
    this.maxWords = 500,
    super.points = 1,
    super.explanationGuidance,
  }) : super(type: QuestionType.textResponse);

  final String placeholder;
  final int minWords;
  final int maxWords;
}
