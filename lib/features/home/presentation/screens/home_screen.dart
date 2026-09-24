import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/providers/favorite_song_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../data/providers/home_screen_provider.dart';
import '../widgets/favorite_artists_section.dart';
import '../widgets/greeting_header.dart';
import '../widgets/home_sections.dart';
import '../widgets/last_played_section.dart';
import '../widgets/liked_songs_section.dart';
import '../widgets/mood_chips_row.dart';
import '../widgets/recent_playlists_section.dart';

/// YouTube Music-style Home: mood chips, greeting, horizontal shelves.
/// Stats and Explore/trending live elsewhere (Profile / Explore tab).
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  @override
  Widget build(BuildContext context) {
    final accentColor = context.select((SettingsProvider p) => p.accentColor);

    return RefreshIndicator(
      color: accentColor,
      onRefresh: () => _onRefresh(context),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.spacingSm),
          ),
          const SliverToBoxAdapter(child: MoodChipsRow()),
          const (SliverToBoxAdapter(child: GreetingHeader())),
          (SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.spacingSm),
          )),
          const SliverToBoxAdapter(child: RecentPlaylistsSection()),
          const SliverToBoxAdapter(child: LastPlayedSection()),
          const (SliverToBoxAdapter(child: LikedSongsSection())),
          const SliverToBoxAdapter(child: FavoriteArtistsSection()),
          const SliverToBoxAdapter(child: HomeSections()),
          (SliverToBoxAdapter(
            child: SizedBox(height: AppDimens.paddingXl),
          )),
        ],
      ),
    );
  }
}
