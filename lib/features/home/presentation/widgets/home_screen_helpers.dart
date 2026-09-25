import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Thumbnail;

import '../../../../core/providers/queued_provider.dart';
import '../../data/services/home_screen_queue_service.dart';
import '../../../../core/models/song_model.dart';
import '../../../../shared/components/app_snackbar.dart';
import '../../../../shared/components/songs_options_bottomsheet.dart';

void handleSongTap(BuildContext context, Map<String, dynamic> song) {
  try {
    playSong(context, song);
  } catch (e) {
    showErrorSnackbar(context, 'unable_to_play_the_song_please_try_again'.tr());
    debugPrint('Error playing song: $e');
  }
}

Future<void> playSong(BuildContext context, Map<String, dynamic> song) async {
  try {
    final queueService = HomeScreenQueueService(context);
    final queueProvider = Provider.of<QueueProvider>(context, listen: false);

    await queueService.playAndQueueSongs(song);
    await queueProvider.saveQueue();
  } catch (e) {
    String errorMessage = 'failed_to_play_song_please_try_again'.tr();

    if (e.toString().contains('Video ID not found')) {
      errorMessage = 'invalid_song_data'.tr();
    } else if (e is VideoUnavailableException) {
      errorMessage = 'this_song_is_currently_unavailable'.tr();
    }

    showErrorSnackbar(context, errorMessage);
    debugPrint('Error playing song(home screen): $e');
  }
}

void showErrorSnackbar(BuildContext context, String message) {
  AppSnackBar.showError(context, message);
}

/// Artist names for a locally stored song map ('artists' list or 'artist').
String songMapArtists(Map<String, dynamic> song) {
  final artists = song['artists'];
  if (artists is List && artists.isNotEmpty) {
    final names = artists
        .map((a) => a is Map ? a['name']?.toString() ?? '' : a.toString())
        .where((n) => n.isNotEmpty)
        .join(', ');
    if (names.isNotEmpty) return names;
  }
  final artist = song['artist']?.toString() ?? '';
  return artist.isNotEmpty ? artist : 'unknown_artist'.tr();
}

String songMapTitle(Map<String, dynamic> song) {
  final title = song['title']?.toString() ?? '';
  return title.isNotEmpty ? title : 'unknown_title'.tr();
}

/// Duration stored in seconds; tolerates int, double or numeric strings.
Duration songMapDuration(Map<String, dynamic> song) {
  final raw = song['duration'];
  if (raw is num) return Duration(seconds: raw.toInt());
  if (raw is String) return Duration(seconds: int.tryParse(raw) ?? 0);
  return Duration.zero;
}

/// Opens the song options sheet for a locally stored song map.
void showSongMapOptions(BuildContext context, Map<String, dynamic> song) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final rawArtists = song['artists'];
  final artists = rawArtists is List && rawArtists.isNotEmpty
      ? rawArtists
            .whereType<Map>()
            .map(
              (a) => Artist(
                name: a['name']?.toString() ?? 'unknown_artist'.tr(),
                id: a['id']?.toString() ?? '',
              ),
            )
            .toList()
      : [
          Artist(
            name: song['artist']?.toString() ?? 'unknown_artist'.tr(),
            id: song['artistId']?.toString() ?? '',
          ),
        ];

  final songInfo = SongInfo(
    videoId: song['id']?.toString() ?? '',
    name: songMapTitle(song),
    artists: artists,
    thumbnails: [
      Thumbnail(
        url: song['thumbnail']?.toString() ?? 'assets/default_artwork.png',
        width: 1280,
        height: 720,
      ),
    ],
    duration: songMapDuration(song),
  );

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: SongOptionsBottomSheet(song: songInfo, isDarkMode: isDarkMode),
    ),
  );
}
