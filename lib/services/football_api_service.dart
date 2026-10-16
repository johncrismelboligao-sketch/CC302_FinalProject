import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/football_match.dart';

class FootballApiService {
  static final _scoreboardUri = Uri.parse(
    'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard',
  );

  Future<List<FootballMatch>> fetchMatches() async {
    final response = await http
        .get(_scoreboardUri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Football API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final events = data['events'] as List<dynamic>? ?? const [];
    return events
        .map((event) => FootballMatch.fromJson(event as Map<String, dynamic>))
        .toList();
  }
}