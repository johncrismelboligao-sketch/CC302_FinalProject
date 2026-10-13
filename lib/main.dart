import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ============================================================
// Football Training Session - CC 302 Final Project
// Single-file version: everything lives in main.dart
// ============================================================

// ---------- theme.dart ----------

class AppColors {
  static const bg = Color(0xFF0B1620);
  static const surface = Color(0xFF111F2B);
  static const card = Color(0xFF162532);
  static const border = Color(0xFF243746);
  static const accent = Color(0xFF4FE3A0);
  static const muted = Color(0xFF9FB0BD);
  static const disabled = Color(0xFF5E7080);
  static const danger = Color(0xFFFF6B6B);
}

ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.black,
      surface: AppColors.surface,
    ),
    textTheme: base.textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.card,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}

// ---------- models/training_session.dart ----------
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

// ---------- services/api_service.dart ----------

class ApiService {
  static const _baseUrl = 'https://jsonplaceholder.typicode.com';

  Future<List<TrainingSession>> fetchSessions() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/todos?_limit=12'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => TrainingSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteSession(int id) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl/todos/$id'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Delete failed: ${response.statusCode}');
    }
  }
}

// ---------- controllers/session_controller.dart ----------

/// Shared state for Home, Profile and List screens.
class SessionController extends ChangeNotifier {
  final ApiService _api;
  SessionController([ApiService? api]) : _api = api ?? ApiService();

  final List<TrainingSession> _sessions = [];
  bool _isLoading = false;
  String? _error;
  bool _showCompletedInSchedule = false;
  bool _confirmBeforeDelete = true;

  List<TrainingSession> get sessions => List.unmodifiable(_sessions);
  List<TrainingSession> get upcoming =>
      _sessions.where((s) => !s.completed).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get showCompletedInSchedule => _showCompletedInSchedule;
  bool get confirmBeforeDelete => _confirmBeforeDelete;

  int get total => _sessions.length;
  int get completedCount => _sessions.where((s) => s.completed).length;
  int get completedMinutes => _sessions
      .where((s) => s.completed)
      .fold(0, (sum, s) => sum + s.durationMin);

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.fetchSessions();
      _sessions
        ..clear()
        ..addAll(result);
    } catch (_) {
      _error = 'Could not load sessions. Check your connection and try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Removes a session and returns its old index (for Undo).
  int remove(TrainingSession s) {
    final index = _sessions.indexOf(s);
    if (index == -1) return -1;
    _sessions.removeAt(index);
    notifyListeners();
    _api.deleteSession(s.id).catchError((_) {});
    return index;
  }

  void restore(TrainingSession s, int index) {
    _sessions.insert(index.clamp(0, _sessions.length), s);
    notifyListeners();
  }

  void toggleCompleted(TrainingSession s) {
    s.completed = !s.completed;
    notifyListeners();
  }

  void setShowCompletedInSchedule(bool value) {
    _showCompletedInSchedule = value;
    notifyListeners();
  }

  void setConfirmBeforeDelete(bool value) {
    _confirmBeforeDelete = value;
    notifyListeners();
  }

  void resetProgress() {
    for (final session in _sessions) {
      session.completed = false;
    }
    notifyListeners();
  }
}

// ---------- widgets/app_bottom_nav.dart ----------

class NavItemData {
  final IconData icon;
  final String label;
  final bool enabled;
  const NavItemData(this.icon, this.label, {this.enabled = true});
}

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<NavItemData> items;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(
                  data: items[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = !data.enabled
        ? AppColors.disabled
        : selected
        ? AppColors.accent
        : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: data.enabled ? data.label : '${data.label}, coming soon',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.icon, size: selected ? 30 : 26, color: color),
              const SizedBox(height: 2),
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 3,
                width: selected ? 28 : 0,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- widgets/state_views.dart ----------

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String message;
  const EmptyView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sports_soccer,
              size: 48,
              color: AppColors.disabled,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- widgets/section_header.dart ----------

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------- widgets/stat_card.dart ----------

class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.accent),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

// ---------- widgets/session_card.dart ----------

IconData iconForType(String type) {
  switch (type) {
    case 'Fitness':
      return Icons.directions_run_rounded;
    case 'Tactical':
      return Icons.dashboard_customize_rounded;
    case 'Attacking':
      return Icons.sports_score_rounded;
    case 'Mental':
      return Icons.psychology_rounded;
    default:
      return Icons.sports_soccer_rounded;
  }
}

class SessionCard extends StatelessWidget {
  final TrainingSession session;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  const SessionCard({
    super.key,
    required this.session,
    this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(iconForType(session.type), color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: session.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: session.completed ? AppColors.muted : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.type} • ${session.durationMin} min • ${session.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (onToggle != null)
            IconButton(
              tooltip: session.completed ? 'Mark as not done' : 'Mark as done',
              onPressed: onToggle,
              icon: Icon(
                session.completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: session.completed ? AppColors.accent : AppColors.muted,
              ),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Delete session',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- widgets/quick_access_card.dart ----------

class QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const QuickAccessCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- screens/home_screen.dart ----------

class HomeScreen extends StatelessWidget {
  final SessionController controller;
  final ValueChanged<int> onNavigate;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _HeroBanner(),
            const SectionHeader('Quick access'),
            QuickAccessCard(
              icon: Icons.person_rounded,
              title: 'Profile',
              subtitle: 'Your Info & Progress',
              onTap: () => onNavigate(0),
            ),
            const SizedBox(height: 12),
            QuickAccessCard(
              icon: Icons.list_rounded,
              title: 'List',
              subtitle: 'Training Sessions',
              onTap: () => onNavigate(1),
            ),
            const SectionHeader('Overview'),
            ..._buildOverview(),
          ],
        );
      },
    );
  }

  List<Widget> _buildOverview() {
    if (controller.isLoading && controller.sessions.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (controller.error != null && controller.sessions.isEmpty) {
      return [
        SizedBox(
          height: 220,
          child: ErrorView(
            message: controller.error!,
            onRetry: controller.load,
          ),
        ),
      ];
    }
    final upcoming = controller.upcoming.take(3).toList();
    return [
      Row(
        children: [
          Expanded(
            child: StatCard(
              icon: Icons.event_note_rounded,
              value: '${controller.total}',
              label: 'Sessions',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.check_circle_rounded,
              value: '${controller.completedCount}',
              label: 'Completed',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.timer_rounded,
              value: '${controller.completedMinutes}',
              label: 'Minutes',
            ),
          ),
        ],
      ),
      const SectionHeader('Up next'),
      if (upcoming.isEmpty)
        const SizedBox(
          height: 140,
          child: EmptyView(message: 'All sessions done. Great work!'),
        )
      else
        for (final s in upcoming)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SessionCard(session: s),
          ),
    ];
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 250,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Put your photo at assets/images/hero.jpg
            Image.asset(
              'assets/images/hero.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF14402F), AppColors.bg],
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.bg.withOpacity(0.95),
                    AppColors.bg.withOpacity(0.2),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.sports_soccer,
                    size: 44,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: Colors.white,
                      ),
                      children: const [
                        TextSpan(text: 'Football\n'),
                        TextSpan(
                          text: 'Training',
                          style: TextStyle(color: AppColors.accent),
                        ),
                        TextSpan(text: ' Session'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Better Skills. Stronger Mind.\nGreater Goals.',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- screens/profile_screen.dart ----------

class ProfileScreen extends StatelessWidget {
  final SessionController controller;
  const ProfileScreen({super.key, required this.controller});

  static const _skills = [
    ('Passing', 0.80),
    ('Dribbling', 0.70),
    ('Shooting', 0.65),
    ('Stamina', 0.85),
    ('Defending', 0.55),
  ];

  static const _info = [
    (Icons.shield_rounded, 'Team', 'City Youth FC'),
    (Icons.cake_rounded, 'Age', '19 years'),
    (Icons.height_rounded, 'Height', '178 cm'),
    (Icons.directions_walk_rounded, 'Preferred foot', 'Right'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final progress = controller.total == 0
            ? 0.0
            : controller.completedCount / controller.total;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.surface,
                    child: Icon(
                      Icons.person_rounded,
                      size: 52,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'John Crismel J. Boligao',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Chip(
                    label: const Text('Defender • #2'),
                    backgroundColor: AppColors.accent.withOpacity(0.15),
                    side: BorderSide.none,
                    labelStyle: const TextStyle(color: AppColors.accent),
                  ),
                ],
              ),
            ),
            const SectionHeader('Progress'),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.check_circle_rounded,
                    value: '${controller.completedCount}/${controller.total}',
                    label: 'Sessions done',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.timer_rounded,
                    value: '${controller.completedMinutes}',
                    label: 'Minutes trained',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: AppColors.border,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).round()}% of sessions completed',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SectionHeader('Skills'),
            for (final s in _skills)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        s.$1,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: s.$2,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${(s.$2 * 100).round()}'),
                  ],
                ),
              ),
            const SectionHeader('Player info'),
            for (final i in _info)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(i.$1, color: AppColors.accent),
                title: Text(
                  i.$2,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                subtitle: Text(
                  i.$3,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ---------- screens/list_screen.dart ----------

class ListScreen extends StatefulWidget {
  final SessionController controller;
  const ListScreen({super.key, required this.controller});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  String _query = '';

  Future<void> _confirmDelete(TrainingSession s) async {
    if (widget.controller.confirmBeforeDelete) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete session?'),
          content: Text('"${s.title}" will be removed from your list.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    final index = widget.controller.remove(s);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${s.title}"'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => widget.controller.restore(s, index),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final q = _query.trim().toLowerCase();
        final items = c.sessions
            .where(
              (s) =>
                  s.title.toLowerCase().contains(q) ||
                  s.type.toLowerCase().contains(q),
            )
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search drills or type',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildBody(c, items)),
          ],
        );
      },
    );
  }

  Widget _buildBody(SessionController c, List<TrainingSession> items) {
    if (c.isLoading && c.sessions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.error != null && c.sessions.isEmpty) {
      return ErrorView(message: c.error!, onRetry: c.load);
    }
    if (items.isEmpty) {
      return EmptyView(
        message: _query.isEmpty
            ? 'No training sessions yet.'
            : 'No sessions match "$_query".',
      );
    }
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final s = items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SessionCard(
              session: s,
              onToggle: () => c.toggleCompleted(s),
              onDelete: () => _confirmDelete(s),
            ),
          );
        },
      ),
    );
  }
}

// ---------- screens/schedule_screen.dart ----------

class ScheduleScreen extends StatelessWidget {
  final SessionController controller;
  const ScheduleScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final sessions = controller.showCompletedInSchedule
            ? controller.sessions
            : controller.upcoming;
        if (controller.isLoading && controller.sessions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error != null && controller.sessions.isEmpty) {
          return ErrorView(
            message: controller.error!,
            onRetry: controller.load,
          );
        }
        if (sessions.isEmpty) {
          return const EmptyView(message: 'No sessions scheduled yet.');
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const SectionHeader('Upcoming training'),
              for (final session in sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SessionCard(
                    session: session,
                    onToggle: () => controller.toggleCompleted(session),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- screens/settings_screen.dart ----------

class SettingsScreen extends StatelessWidget {
  final SessionController controller;
  const SettingsScreen({super.key, required this.controller});

  Future<void> _confirmReset(BuildContext context) async {
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset training progress?'),
        content: const Text('All completed sessions will be marked upcoming.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (reset == true) controller.resetProgress();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SectionHeader('Training'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show completed sessions'),
            subtitle: const Text('Include completed sessions in Schedule'),
            value: controller.showCompletedInSchedule,
            onChanged: controller.setShowCompletedInSchedule,
          ),
          const SectionHeader('Safety'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Confirm before deleting'),
            subtitle: const Text('Ask before removing a training session'),
            value: controller.confirmBeforeDelete,
            onChanged: controller.setConfirmBeforeDelete,
          ),
          const SectionHeader('Progress'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restart_alt_rounded),
            title: const Text('Reset training progress'),
            subtitle: const Text('Mark every session as upcoming'),
            onTap: () => _confirmReset(context),
          ),
        ],
      ),
    );
  }
}

// ---------- screens/main_shell.dart ----------

/// Holds the AppBar, bottom navigation and the app pages.
/// Nav order: Profile, List, HOME (center), Schedule, Settings.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _controller = SessionController();
  int _navIndex = 2; // start on Home (center)

  static const _items = [
    NavItemData(Icons.person_rounded, 'Profile'),
    NavItemData(Icons.list_rounded, 'List'),
    NavItemData(Icons.home_rounded, 'Home'),
    NavItemData(Icons.calendar_month_rounded, 'Schedule'),
    NavItemData(Icons.settings_rounded, 'Settings'),
  ];
  static const _titles = [
    'My Profile',
    'Training Sessions',
    'Football Training',
    'Schedule',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() => _navIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_navIndex])),
      body: IndexedStack(
        index: _navIndex,
        children: [
          ProfileScreen(controller: _controller),
          ListScreen(controller: _controller),
          HomeScreen(controller: _controller, onNavigate: _onNavTap),
          ScheduleScreen(controller: _controller),
          SettingsScreen(controller: _controller),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _navIndex,
        items: _items,
        onTap: _onNavTap,
      ),
    );
  }
}

// ---------- main.dart ----------

void main() => runApp(const FootballTrainingApp());

class FootballTrainingApp extends StatelessWidget {
  const FootballTrainingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Football Training Session',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const MainShell(),
    );
  }
}
