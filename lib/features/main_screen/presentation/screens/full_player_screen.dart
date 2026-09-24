import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/settings_provider.dart';
import '../../../player/presentation/screens/player_ui.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final animationType = Provider.of<SettingsProvider>(
      context,
      listen: true,
    ).animationType;
    // YTM default: true black static. Optional animation backgrounds only when enabled.
    final bg = animationType == 'Default'
        ? const Color(0xFF000000)
        : const Color(0xFF040404);
    return Scaffold(
      backgroundColor: bg,
      body: PlayerUI(
        showFullScreen: true,
        isBottomSheet: true,
        onMinimize: () => Navigator.of(context).pop(),
        onExpand: () {},
      ),
    );
  }
}
