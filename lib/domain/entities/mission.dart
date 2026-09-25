import 'package:equatable/equatable.dart';

/// One gamified mission, e.g. "Find Earth".
class Mission extends Equatable {
  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.targetPlanetId,
    this.completed = false,
  });

  final int id;
  final String title;
  final String description;
  final String targetPlanetId;
  final bool completed;

  Mission copyWith({bool? completed}) => Mission(
        id: id,
        title: title,
        description: description,
        targetPlanetId: targetPlanetId,
        completed: completed ?? this.completed,
      );

  @override
  List<Object?> get props => [id, completed];
}
