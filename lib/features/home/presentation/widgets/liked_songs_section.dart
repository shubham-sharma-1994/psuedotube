import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/favorite_song_provider.dart';
import '../../data/services/home_screen_queue_service.dart';
import 'home_screen_helpers.dart';
import 'ytm_home_widgets.dart';

/// Liked songs as a YTM song-list shelf with a "Play all" action.
class LikedSongsSection extends StatelessWidget {
  const LikedSongsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final favoriteSongProvider = context.watch<FavoriteSongProvider>();

    if (favoriteSongProvider.isLoadingLikedSongs ||
        favoriteSongProvider.likedSongs.isEmpty) {
      return const SizedBox.shrink();
    }

    final songs = List<Map<String, dynamic>>.from(
      favoriteSongProvider.likedSongs,
    );

    Future<void> playAt(int index) async {
      try {
        await HomeScreenQueueService(
          context,
        ).playAll('liked_songs', currentIndex: index);
      } catch (e) {
        if (!context.mounted) return;
        showErrorSnackbar(context, 'Failed to play song');
        debugPrint('Error playing liked songs: $e');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YtmShelfHeader(
          title: 'liked_songs'.tr(),
          actionLabel: 'Play all',
          onAction: () => playAt(0),
        ),
        YtmSongGrid(
          items: [
            for (var i = 0; i < songs.length; i++)
              YtmSongRowData(
                title: songMapTitle(songs[i]),
                subtitle: songMapArtists(songs[i]),
                imageUrl: songs[i]['thumbnail']?.toString(),
                onTap: () => playAt(i),
                onMore: () => showSongMapOptions(context, songs[i]),
              ),
          ],
        ),
      ],
    );
  }
}
