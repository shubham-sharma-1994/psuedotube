import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../features/settings/presentation/screens/settings_screen.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';

import 'package:provider/provider.dart';

import '../../../favorite_artist/presentation/screens/favorite_artist_screen.dart';
import '../widgets/audio_output_bottomsheet.dart';

import '../../../downloads/presentation/screens/downloads_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/player_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../player/presentation/screens/player_ui.dart';
import '../../../library/presentation/screens/library_screen.dart';
import '../../../playlists/presentation/screens/playlists_screen.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../../stats/presentation/screens/stats_screen.dart';
import '../../../trending/presentation/screens/trending_screen.dart';

class DesktopMainScreen extends StatefulWidget {
  const DesktopMainScreen({super.key});

  @override
  State<DesktopMainScreen> createState() => _DesktopMainScreenState();
}

class _DesktopMainScreenState extends State<DesktopMainScreen> {
  int _currentIndex = 0;
  final GlobalKey<NavigatorState> _innerNavKey = GlobalKey<NavigatorState>();

  late TextStyle _titleStyle;
  late TextStyle _selectedLabelStyle;
  late TextStyle _unselectedLabelStyle;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),

    const TrendingScreen(),

    const PlaylistScreen(),
    const LibraryScreen(),
    const FavoriteArtistsScreen(),

    const SettingsScreen(),
    const DownloadsScreen(),
    StatsScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStyles();
  }

  Future<void> _showAudioOutputSheet() async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final isDarkMode = settingsProvider.themeMode == ThemeMode.dark;
    final accentColor = settingsProvider.accentColor;
    await showAudioOutputBottomSheet(
      context,
      isDarkMode: isDarkMode,
      accentColor: accentColor,
    );
  }

  void _updateStyles() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDarkMode = settingsProvider.themeMode == ThemeMode.dark;

    _titleStyle = AppTextStyles.headingLg(isDarkMode: isDarkMode);

    _selectedLabelStyle = AppTextStyles.caption(isDarkMode: isDarkMode)
        .copyWith(
          fontWeight: FontWeight.w600,
          color: settingsProvider.accentColor,
        );

    _unselectedLabelStyle = AppTextStyles.finePrint(isDarkMode: isDarkMode)
        .copyWith(
          color: MainScreenColors.getTextColor(isDarkMode).withOpacity(0.5),
        );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final isDarkMode = settingsProvider.themeMode == ThemeMode.dark;
    final playerProvider = Provider.of<PlayerProvider>(context);
    final hasPlayer =
        playerProvider.currentSong != null ||
        playerProvider.lastPlayedSong != null;

    return WillPopScope(
      onWillPop: () async {
        if (_innerNavKey.currentState != null &&
            _innerNavKey.currentState!.canPop()) {
          _innerNavKey.currentState!.pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: MainScreenColors.getBackgroundColor(isDarkMode),
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: AppDimens.iconSplash + AppDimens.spacingXs,
                    decoration: BoxDecoration(
                      color: MainScreenColors.getSurfaceColor(
                        isDarkMode,
                      ).withOpacity(0.95),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: AppDimens.elevationHigh,
                          offset: const Offset(AppDimens.spacingXxs, 0),
                        ),
                      ],
                    ),
                    child: NavigationRail(
                      leading: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isDarkMode ? Icons.light_mode : Icons.dark_mode,
                              color: MainScreenColors.getTextColor(isDarkMode),
                            ),
                            onPressed: () {
                              settingsProvider.toggleTheme();
                            },
                            tooltip: 'Toggle Theme',
                          ),
                          const SizedBox(height: AppDimens.spacingS),
                        ],
                      ),
                      trailing: Platform.isAndroid
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.speaker_rounded,
                                    color: MainScreenColors.getTextColor(
                                      isDarkMode,
                                    ),
                                  ),
                                  onPressed: _showAudioOutputSheet,
                                  tooltip: 'Audio Output',
                                ),
                                const SizedBox(height: AppDimens.spacingS),
                              ],
                            )
                          : null,
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (index) {
                        if (_innerNavKey.currentState?.canPop() ?? false) {
                          _innerNavKey.currentState!.popUntil(
                            (route) => route.isFirst,
                          );
                        }
                        setState(() => _currentIndex = index);
                      },
                      labelType: NavigationRailLabelType.selected,
                      backgroundColor: Colors.transparent,
                      selectedIconTheme: IconThemeData(
                        color: settingsProvider.accentColor,
                        size: AppDimens.iconXl,
                      ),
                      unselectedIconTheme: IconThemeData(
                        color: MainScreenColors.getTextColor(
                          isDarkMode,
                        ).withOpacity(0.6),
                        size: AppDimens.iconLg,
                      ),
                      selectedLabelTextStyle: _selectedLabelStyle.copyWith(
                        fontSize: AppTextStyles.fontSizeCaption,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelTextStyle: _unselectedLabelStyle.copyWith(
                        fontSize: AppTextStyles.fontSizeSm,
                      ),
                      destinations: [
                        NavigationRailDestination(
                          icon: Icon(Icons.home),
                          label: Text('home'.tr()),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.search),
                          label: Text('search'.tr()),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.trending_up),
                          label: Text('trending'.tr()),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.playlist_play),
                          label: Text('playlists'.tr()),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.library_music_outlined),
                          label: Text('library'.tr()),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.person_outline),
                          label: Text('artists'.tr()),
                        ),

                        NavigationRailDestination(
                          icon: Icon(Icons.settings),
                          label: Text('settings'.tr()),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.download_done_sharp),
                          label: Text('downloads'.tr()),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.show_chart),
                          label: Text('stats'.tr()),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Navigator(
                      key: _innerNavKey,
                      onGenerateRoute: (RouteSettings settings) {
                        return MaterialPageRoute(
                          settings: settings,
                          builder: (context) => Padding(
                            padding: const EdgeInsets.all(AppDimens.paddingLg),
                            child: IndexedStack(
                              index: _currentIndex,
                              children: _screens,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (hasPlayer)
              SizedBox(
                height: AppDimens.miniPlayerHeightWide,
                child: PlayerUI(
                  showFullScreen: false,
                  isEmbedded: true,
                  onMinimize: () {},
                  onExpand: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            _DesktopFullPlayerResponsiveWrapper(
                              child: const FullPlayerScreen(),
                              onSwitchToMobile: (wrapperContext) {
                                if (Navigator.of(wrapperContext).canPop()) {
                                  Navigator.of(wrapperContext).pop();
                                }
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (MediaQuery.of(wrapperContext).size.width <
                                      AppDimens.breakpointMobile) {
                                    showModalBottomSheet(
                                      context: wrapperContext,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      enableDrag: true,
                                      builder: (context) => SafeArea(
                                        child: SizedBox(
                                          height: MediaQuery.of(
                                            context,
                                          ).size.height,
                                          child: const FullPlayerScreen(),
                                        ),
                                      ),
                                    );
                                  }
                                });
                              },
                            ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopFullPlayerResponsiveWrapper extends StatefulWidget {
  final Widget child;
  final void Function(BuildContext wrapperContext) onSwitchToMobile;

  const _DesktopFullPlayerResponsiveWrapper({
    Key? key,
    required this.child,
    required this.onSwitchToMobile,
  }) : super(key: key);

  @override
  State<_DesktopFullPlayerResponsiveWrapper> createState() =>
      _DesktopFullPlayerResponsiveWrapperState();
}

class _DesktopFullPlayerResponsiveWrapperState
    extends State<_DesktopFullPlayerResponsiveWrapper>
    with WidgetsBindingObserver {
  bool _hasSwitched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    final width = MediaQuery.of(context).size.width;
    if (!_hasSwitched && width < AppDimens.breakpointMobile) {
      _hasSwitched = true;
      widget.onSwitchToMobile(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040404),
      body: PlayerUI(
        showFullScreen: true,
        isBottomSheet: true,
        onMinimize: () => Navigator.of(context).pop(),
        onExpand: () {},
      ),
    );
  }
}
