import 'package:equatable/equatable.dart';

/// One gamified mission, e.g. "Find Earth".
class Mission extends Equatable {
  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.targetPlanetId,
    this.startPoint,
    this.direction,
    this.hints = const [],
    this.completed = false,
  });

  final int id;
  final String title;
  final String description;
  final String targetPlanetId;
  final String? startPoint;
  final String? direction;

  /// Clues in increasing order of bluntness, given away one at a time.
  ///
  /// The first entry is what the mission dialog shows on open. Each further
  /// entry is a bigger nudge for a child who has already read the first one
  /// and still has not spotted the target, so the dialog only reveals the next
  /// clue when asked rather than unprompted. Never empty in practice, but an
  /// empty list is handled rather than assumed away.
  final List<String> hints;

  final bool completed;

  Mission copyWith({bool? completed}) => Mission(
    id: id,
    title: title,
    description: description,
    targetPlanetId: targetPlanetId,
    startPoint: startPoint,
    direction: direction,
    hints: hints,
    completed: completed ?? this.completed,
  );

  @override
  List<Object?> get props => [id, completed];
}
