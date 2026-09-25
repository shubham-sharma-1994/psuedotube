import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../../../core/providers/player_provider.dart';
import 'ytm_home_widgets.dart';
import '../../../playlist_album_content/presentation/screens/playlist_album_content_screen.dart';

class RecentPlaylistsSection extends StatefulWidget {
  const RecentPlaylistsSection({Key? key}) : super(key: key);

  @override
  State<RecentPlaylistsSection> createState() => _RecentPlaylistsSectionState();
}

class _RecentPlaylistsSectionState extends State<RecentPlaylistsSection> {
  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final recentPlaylists = playerProvider.recentPlaylists;

    if (playerProvider.isLoadingLastPlayedSongs || recentPlaylists.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YtmShelfHeader(title: 'recently_played_playlist'.tr()),
        YtmCardShelf(
          items: [
            for (final playlist in recentPlaylists)
              YtmCardData(
                title: playlist['name']?.toString() ?? 'Unknown Playlist',
                subtitle: playlist['isPlaylist'] == false
                    ? 'Album'
                    : 'Playlist',
                imageUrl: (playlist['thumbnailUrl'] ?? playlist['thumbnail'])
                    ?.toString(),
                onTap: () => _openPlaylist(context, playlist),
              ),
          ],
        ),
      ],
    );
  }

  void _openContentDetail(BuildContext context, Map<String, dynamic> content) {
    final bool isPlaylist = content['isPlaylist'] == null
        ? true
        : content['isPlaylist'] == true;

    final formattedContent = isPlaylist
        ? PlaylistDetailed(
            playlistId: content['playlistId'] ?? '',
            name: content['name'] ?? content['title'] ?? '',
            artist: ArtistBasic(name: ''),
            thumbnails: [
              ThumbnailFull(
                url: content['thumbnailUrl'] ?? content['thumbnail'] ?? '',
                width: 1280,
                height: 720,
              ),
            ],
            type: 'Playlist',
          )
        : AlbumDetailed(
            playlistId: content['playlistId'] ?? '',
            albumId: content['playlistId'] ?? '',
            name: content['name'] ?? content['title'] ?? '',
            artist: ArtistBasic(name: content['artist'] ?? ''),
            thumbnails: [
              ThumbnailFull(
                url: content['thumbnailUrl'] ?? content['thumbnail'] ?? '',
                width: 1280,
                height: 720,
              ),
            ],
            type: 'Album',
          );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistAlbumContent(content: formattedContent),
      ),
    );
  }

  void _openPlaylist(BuildContext context, Map<String, dynamic> playlist) {
    _openContentDetail(context, playlist);
  }
}
