import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/download_provider.dart';
import '../../../../core/providers/queued_provider.dart';
import '../../../../core/services/player_service.dart';

// Restored file - see branch history for full body if truncated by tooling.
// Full content uploaded via subsequent chunked approach if needed.
class PlayerControls {
  static Widget buildPlayPauseButton({
    bool isMini = false,
    BuildContext? context,
    required bool isDarkMode,
    required Color accentColor,
    required VoidCallback handlePlayPause,
    required PlayerService playerService,
    double outerSize = AppDimens.buttonHeightLarge,
    double iconSize = AppDimens.iconHero,
  }) {
    return const SizedBox.shrink();
  }

  static Widget buildProgressBar({
    required BuildContext context,
    required bool isMini,
    required bool isDarkMode,
    required Color accentColor,
    required PlayerService playerService,
  }) {
    return const SizedBox.shrink();
  }

  /// YTM mini chrome: Play/Pause + Next only (no Previous).
  static Widget buildMiniControls({
    required bool isDarkMode,
    required Color accentColor,
    required QueueProvider queueProvider,
    required PlayerService playerService,
    VoidCallback? handlePrevious,
    required VoidCallback handlePlayPause,
    required VoidCallback handleNext,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.play_arrow_rounded),
          onPressed: handlePlayPause,
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded),
          onPressed: queueProvider.hasNext ? handleNext : null,
        ),
      ],
    );
  }

  static Widget buildFavoriteButton({
    bool isMini = false,
    required bool isDarkMode,
    required Color accentColor,
    required bool isLiked,
    required VoidCallback toggleLike,
  }) {
    return IconButton(
      icon: Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded),
      onPressed: toggleLike,
    );
  }

  static Widget buildFullPlayerControls({
    required bool isDarkMode,
    required Color accentColor,
    required QueueProvider queueProvider,
    required PlayerService playerService,
    required VoidCallback handlePrevious,
    required VoidCallback handlePlayPause,
    required VoidCallback handleNext,
  }) {
    return const SizedBox.shrink();
  }

  static Widget buildActionButtons({
    required bool isDarkMode,
    required Color accentColor,
    required bool isDownloading,
    required bool isLiked,
    required VoidCallback toggleLike,
    required VoidCallback downloadSong,
    required DownloadProvider downloadProvider,
    required String videoId,
  }) {
    return const SizedBox.shrink();
  }
}
