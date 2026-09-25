import 'package:dart_ytmusic_api/types.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/song_model.dart';
import '../../../../core/utils/content_router.dart';
import '../../../../shared/components/songs_options_bottomsheet.dart';
import '../../data/providers/home_screen_provider.dart';
import 'home_screen_helpers.dart';
import 'home_screen_shimmer.dart';
import 'ytm_home_widgets.dart';

/// Which of the InnerTube home shelves to render. Home shows the
/// "Quick picks" shelf first, then local shelves, then everything else.
enum HomeSectionsPart { quickPicks, rest }

class HomeSections extends StatelessWidget {
  final HomeSectionsPart part;

  const HomeSections({Key? key, this.part = HomeSectionsPart.rest})
    : super(key: key);

  /// Map InnerTube section titles toward YTM-style shelf labels.
  static String displayTitle(String raw) {
    final t = raw.trim();
    final lower = t.toLowerCase();
    if (lower.contains('quick pick')) return 'Quick picks';
    if (lower.contains('forgotten')) return 'Forgotten favourites';
    if (lower.contains('new release') || lower.contains('new album')) {
      return 'New releases';
    }
    if (lower.contains('mixed for you') || lower.contains('mix for you')) {
      return 'Mixed for you';
    }
    if (lower.contains('recommended')) return 'Recommended';
    if (lower.contains('listen again')) return 'Listen again';
    return t;
  }

  static bool _isQuickPicks(dynamic section) =>
      section.title.toString().toLowerCase().contains('quick pick');

  static bool _isPlayable(dynamic item) =>
      item is SongDetailed || item is VideoDetailed;

  /// Index of the section rendered as the leading "Quick picks" list, or -1.
  static int quickPicksIndex(List<dynamic> sections) {
    final byTitle = sections.indexWhere(_isQuickPicks);
    if (byTitle >= 0) return byTitle;
    // Anonymous sessions often lack "Quick picks"; promote the first
    // song-only shelf so Home still opens with a song list like YTM.
    return sections.indexWhere(
      (s) =>
          s.contents.length >= YtmDimens.quickPickRows &&
          (s.contents as List).every(_isPlayable),
    );
  }

  /// Thumbnail URL for any InnerTube item, tolerating empty lists.
  static String? thumbnailOf(dynamic item) {
    try {
      final List thumbs = item.thumbnails as List;
      if (thumbs.isEmpty) return null;
      return thumbs.last.url as String?;
    } catch (_) {
      return null;
    }
  }

  static String _artistName(dynamic item) {
    try {
      return (item.artist?.name as String?)?.trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  static String _subtitleFor(dynamic item) {
    final artist = _artistName(item);
    if (item is SongDetailed) {
      final album = item.album?.name.trim() ?? '';
      return [artist, album].where((s) => s.isNotEmpty).join(' • ');
    }
    if (item is VideoDetailed) return artist;
    if (item is AlbumDetailed) {
      final type = item.type.isNotEmpty && item.type.toUpperCase() != 'ALBUM'
          ? _titleCase(item.type)
          : 'Album';
      return [type, artist].where((s) => s.isNotEmpty).join(' • ');
    }
    if (item is PlaylistDetailed) {
      return ['Playlist', artist].where((s) => s.isNotEmpty).join(' • ');
    }
    if (item is ArtistDetailed) return 'Artist';
    return artist;
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static String _videoIdOf(dynamic item) {
    if (item is SongDetailed) return item.videoId;
    if (item is VideoDetailed) return item.videoId;
    return '';
  }

  static void _play(BuildContext context, dynamic item) {
    final videoId = _videoIdOf(item);
    if (videoId.isEmpty) {
      showErrorSnackbar(context, 'Unable to play this song');
      return;
    }
    playSong(context, {
      'id': videoId,
      'title': item.name,
      'artist': _artistName(item),
      'thumbnail': thumbnailOf(item),
    });
  }

  static void _showSongOptions(BuildContext context, dynamic item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final artistId = (() {
      try {
        return (item.artist?.artistId as String?) ?? '';
      } catch (_) {
        return '';
      }
    })();
    final durationSeconds = (() {
      try {
        return (item.duration as int?) ?? 0;
      } catch (_) {
        return 0;
      }
    })();
    final songInfo = SongInfo(
      videoId: _videoIdOf(item),
      name: item.name as String,
      artists: [Artist(name: _artistName(item), id: artistId)],
      thumbnails: [
        Thumbnail(url: thumbnailOf(item) ?? '', width: 544, height: 544),
      ],
      duration: Duration(seconds: durationSeconds),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: SongOptionsBottomSheet(song: songInfo, isDarkMode: isDark),
      ),
    );
  }

  static void _open(BuildContext context, dynamic item) {
    if (_isPlayable(item)) {
      _play(context, item);
      return;
    }
    if (item is AlbumDetailed ||
        item is PlaylistDetailed ||
        item is ArtistDetailed) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ContentRouter(content: item)),
      );
    }
  }

  static YtmSongRowData _songRow(BuildContext context, dynamic item) {
    return YtmSongRowData(
      title: item.name as String,
      subtitle: _subtitleFor(item),
      imageUrl: thumbnailOf(item),
      onTap: () => _open(context, item),
      onMore: _isPlayable(item) ? () => _showSongOptions(context, item) : null,
    );
  }

  static YtmCardData _card(BuildContext context, dynamic item) {
    return YtmCardData(
      title: item.name as String,
      subtitle: _subtitleFor(item),
      imageUrl: thumbnailOf(item),
      circle: item is ArtistDetailed,
      onTap: () => _open(context, item),
      onLongPress: _isPlayable(item)
          ? () => _showSongOptions(context, item)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeScreenProvider>();

    if (provider.isHomeSectionsLoading) {
      return part == HomeSectionsPart.quickPicks
          ? ShimmerLoading.buildShimmerList()
          : const SizedBox.shrink();
    }

    final sections = provider.homeSections
        .where((s) => (s.contents as List).isNotEmpty)
        .toList();
    final qpIndex = quickPicksIndex(sections);

    if (part == HomeSectionsPart.quickPicks) {
      if (qpIndex < 0) return const SizedBox.shrink();
      final section = sections[qpIndex];
      final items = (section.contents as List)
          .where((c) => c != null)
          .map((c) => _songRow(context, c))
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YtmShelfHeader(
            title: 'Quick picks',
            leading: const YtmAvatar(size: 32),
          ),
          YtmSongGrid(items: items),
        ],
      );
    }

    final rest = [
      for (var i = 0; i < sections.length; i++)
        if (i != qpIndex) sections[i],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in rest) ...[
          YtmShelfHeader(title: displayTitle(section.title)),
          YtmCardShelf(
            items: (section.contents as List)
                .where((c) => c != null)
                .map((c) => _card(context, c))
                .toList(),
          ),
        ],
      ],
    );
  }
}
