import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dart_ytmusic_api/dart_ytmusic_api.dart';

import '../../../favorite_artist/presentation/screens/favorite_artist_screen.dart';
import '../../../../core/providers/favorite_artist_provider.dart';
import '../../../artist/presentation/screens/artist_content.dart';
import 'ytm_home_widgets.dart';

class FavoriteArtistsSection extends StatelessWidget {
  const FavoriteArtistsSection({Key? key}) : super(key: key);

  void _openArtistDetail(BuildContext context, Map<String, dynamic> artist) {
    final artistDetailed = ArtistDetailed(
      artistId: artist['artistId']?.toString() ?? '',
      name: artist['name']?.toString() ?? '',
      thumbnails: [
        ThumbnailFull(
          url: artist['thumbnailUrl']?.toString() ?? '',
          width: 0,
          height: 0,
        ),
      ],
      type: '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArtistContent(artist: artistDetailed),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FavoriteArtistProvider>();

    if (provider.isFavoriteArtistsLoading || provider.favoriteArtists.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        YtmShelfHeader(
          title: 'favorite_artists'.tr(),
          actionLabel: 'More',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FavoriteArtistsScreen(),
            ),
          ),
        ),
        YtmCardShelf(
          cardSize: 128,
          items: [
            for (final artist in provider.favoriteArtists)
              YtmCardData(
                title: artist['name']?.toString() ?? 'unknown_artist'.tr(),
                subtitle: 'Artist',
                imageUrl: artist['thumbnailUrl']?.toString(),
                circle: true,
                onTap: () => _openArtistDetail(context, artist),
              ),
          ],
        ),
      ],
    );
  }
}
