import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/favorite_song_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/utils/palette_generator.dart';
import '../../data/providers/home_screen_provider.dart';
import '../widgets/favorite_artists_section.dart';
import '../widgets/home_sections.dart';
import '../widgets/last_played_section.dart';
import '../widgets/liked_songs_section.dart';
import '../widgets/mood_chips_row.dart';
import '../widgets/recent_playlists_section.dart';
import '../widgets/ytm_home_widgets.dart';

/// YouTube Music-style Home: colour wash behind the top bar, mood chips,
/// "Quick picks" song list, then horizontal card shelves.
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _defaultWash = Color(0xFF3A4E6E);

  String? _washSourceUrl;
  Color _washColor = _defaultWash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<FavoriteSongProvider>(
        context,
        listen: false,
      ).loadLikedSongs();
    });
  }

  Future<void> _onRefresh(BuildContext context) async {
    final homeScreenProvider = Provider.of<HomeScreenProvider>(
      context,
      listen: false,
    );
    await homeScreenProvider.refreshData();
  }

  /// Artwork of the first "Quick picks" item drives the colour wash, like YTM.
  static String? _washUrlFrom(HomeScreenProvider provider) {
    final sections = provider.homeSections;
    if (sections.isEmpty) return null;
    final index = HomeSections.quickPicksIndex(sections);
    final section = sections[index >= 0 ? index : 0];
    final List contents = section.contents as List;
    if (contents.isEmpty) return null;
    return HomeSections.thumbnailOf(contents.first);
  }

  void _maybeUpdateWash(String? url) {
    if (url == _washSourceUrl) return;
    _washSourceUrl = url;
    if (url == null || !url.startsWith('http')) {
      if (_washColor != _defaultWash) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _washColor = _defaultWash);
        });
      }
      return;
    }
    ColorPaletteService.generatePalette(url).then((color) {
      if (!mounted || _washSourceUrl != url) return;
      setState(() => _washColor = _tame(color));
    });
  }

  /// Keep the wash muted so white text stays readable.
  static Color _tame(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.25, 0.6))
        .withLightness(hsl.lightness.clamp(0.32, 0.5))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.select((SettingsProvider p) => p.accentColor);
    final washUrl = context.select(_washUrlFrom);
    _maybeUpdateWash(washUrl);

    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: YtmHomeBackdrop(
              key: ValueKey(_washColor),
              color: _washColor,
              height: topInset + 420,
            ),
          ),
        ),
        RefreshIndicator(
          color: accentColor,
          edgeOffset: topInset,
          onRefresh: () => _onRefresh(context),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: topInset + 8)),
              const SliverToBoxAdapter(child: MoodChipsRow()),
              const SliverToBoxAdapter(
                child: HomeSections(part: HomeSectionsPart.quickPicks),
              ),
              const SliverToBoxAdapter(child: LastPlayedSection()),
              const SliverToBoxAdapter(child: RecentPlaylistsSection()),
              const SliverToBoxAdapter(
                child: HomeSections(part: HomeSectionsPart.rest),
              ),
              const SliverToBoxAdapter(child: LikedSongsSection()),
              const SliverToBoxAdapter(child: FavoriteArtistsSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ],
    );
  }
}
