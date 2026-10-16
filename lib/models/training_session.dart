class TrainingSession {
  final int id;
  final String title;
  final String type;
  final int durationMin;
  final String location;
  bool completed;

  TrainingSession({
    required this.id,
    required this.title,
    required this.type,
    required this.durationMin,
    required this.location,
    required this.completed,
  });

  static const _drills = <(String, String, int)>[
    ('Passing & Receiving', 'Technical', 45),
    ('Dribbling Circuit', 'Technical', 40),
    ('Shooting Accuracy', 'Attacking', 50),
    ('Small-Sided Games', 'Tactical', 60),
    ('Defensive Positioning', 'Tactical', 55),
    ('Speed & Agility', 'Fitness', 35),
    ('Endurance Run', 'Fitness', 45),
    ('Set Pieces', 'Tactical', 40),
    ('Goalkeeper Reflexes', 'Technical', 30),
    ('Mindset & Recovery', 'Mental', 25),
  ];
  static const _places = [
    'Main Pitch',
    'Training Ground B',
    'Indoor Court',
    'Track',
  ];

  /// Maps a JSONPlaceholder "todo" into a training session.
  /// id/userId/completed come from the API; drill details are derived from the id.
  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final drill = _drills[(id - 1) % _drills.length];
    return TrainingSession(
      id: id,
      title: drill.$1,
      type: drill.$2,
      durationMin: drill.$3,
      location: _places[(json['userId'] as int) % _places.length],
      completed: json['completed'] as bool,
    );
  }
}