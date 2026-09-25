import 'package:flutter/material.dart';

import '../../../search/presentation/screens/search_screen.dart';
import 'ytm_home_widgets.dart';

/// Mood / category chips at the top of Home (YTM style). Tapping a chip
/// opens Search with that mood already searched.
class MoodChipsRow extends StatelessWidget {
  const MoodChipsRow({super.key});

  static const _moods = <String>[
    'Podcasts',
    'Relax',
    'Romance',
    'Energise',
    'Feel good',
    'Workout',
    'Party',
    'Commute',
    'Sad',
    'Focus',
    'Sleep',
  ];

  void _openMood(BuildContext context, String mood) {
    final query = mood == 'Podcasts' ? 'podcasts' : '$mood songs';
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(initialQuery: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return YtmChipsRow(
      labels: _moods,
      onSelected: (mood) => _openMood(context, mood),
    );
  }
}
