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
    this.hint,
    this.completed = false,
  });

  final int id;
  final String title;
  final String description;
  final String targetPlanetId;
  final String? startPoint;
  final String? direction;
  final String? hint;
  final bool completed;

  Mission copyWith({bool? completed}) => Mission(
        id: id,
        title: title,
        description: description,
        targetPlanetId: targetPlanetId,
        startPoint: startPoint,
        direction: direction,
        hint: hint,
        completed: completed ?? this.completed,
      );

  @override
  List<Object?> get props => [id, completed];
}
