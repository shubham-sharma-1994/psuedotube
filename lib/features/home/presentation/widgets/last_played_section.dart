import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/player_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../data/services/home_screen_queue_service.dart';
import 'home_screen_helpers.dart';
import 'ytm_home_widgets.dart';

/// YTM "Listen again": two rows of compact cards built from play history.
class LastPlayedSection extends StatelessWidget {
  const LastPlayedSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final historyEnabled = context.select(
      (SettingsProvider p) => p.playbackHistoryEnabled,
    );
    final playerProvider = context.watch<PlayerProvider>();

    if (!historyEnabled ||
        playerProvider.isLoadingLastPlayedSongs ||
        playerProvider.lastPlayedSongs.isEmpty) {
      return const SizedBox.shrink();
    }

    final songs = List<Map<String, dynamic>>.from(
      playerProvider.lastPlayedSongs,
    );

    Future<void> playAt(int index) async {
      try {
        await HomeScreenQueueService(
          context,
        ).playAll('recently_played', currentIndex: index);
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackbar(context, 'Failed to play song');
        debugPrint('Error playing recently played: $e');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YtmShelfHeader(
          title: 'Listen again',
          leading: const YtmAvatar(size: 32),
        ),
        YtmCardShelf(
          rows: 2,
          cardSize: 104,
          items: [
            for (var i = 0; i < songs.length; i++)
              YtmCardData(
                title: songMapTitle(songs[i]),
                subtitle: songMapArtists(songs[i]),
                imageUrl: songs[i]['thumbnail']?.toString(),
                onTap: () => playAt(i),
                onLongPress: () => showSongMapOptions(context, songs[i]),
              ),
          ],
        ),
      ],
    );
  }
}
