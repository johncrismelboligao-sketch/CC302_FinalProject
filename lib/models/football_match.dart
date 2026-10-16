class FootballMatch {
  final String homeTeam;
  final String awayTeam;
  final int? homeScore;
  final int? awayScore;
  final DateTime startTime;
  final String status;
  final bool isLive;

  const FootballMatch({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.startTime,
    required this.status,
    required this.isLive,
  });

  factory FootballMatch.fromJson(Map<String, dynamic> json) {
    final competitions = json['competitions'] as List<dynamic>? ?? const [];
    if (competitions.isEmpty) {
      throw const FormatException('Match has no competition details');
    }

    final competition = competitions.first as Map<String, dynamic>;
    final competitors = competition['competitors'] as List<dynamic>? ?? const [];
    final home = _competitorFor(competitors, 'home');
    final away = _competitorFor(competitors, 'away');
    final statusType =
        ((competition['status'] as Map<String, dynamic>?)?['type']
            as Map<String, dynamic>?) ??
        const {};

    return FootballMatch(
      homeTeam: (home['team'] as Map<String, dynamic>)['displayName'] as String,
      awayTeam: (away['team'] as Map<String, dynamic>)['displayName'] as String,
      homeScore: int.tryParse(home['score']?.toString() ?? ''),
      awayScore: int.tryParse(away['score']?.toString() ?? ''),
      startTime: DateTime.parse(json['date'] as String),
      status:
          statusType['shortDetail'] as String? ??
          statusType['description'] as String? ??
          'Scheduled',
      isLive: statusType['state'] == 'in',
    );
  }

  static Map<String, dynamic> _competitorFor(
    List<dynamic> competitors,
    String homeAway,
  ) {
    for (final item in competitors) {
      final competitor = item as Map<String, dynamic>;
      if (competitor['homeAway'] == homeAway) return competitor;
    }
    throw FormatException('Match is missing its $homeAway team');
  }
}