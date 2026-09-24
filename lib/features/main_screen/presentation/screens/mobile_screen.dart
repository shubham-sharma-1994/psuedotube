import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/models/ota_model.dart';
import '../../../../core/providers/player_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../library/presentation/screens/library_screen.dart';
import '../../../ota/data/providers/ota_provider.dart';
import '../../../ota/presentation/widgets/ota_bottomsheet.dart';
import '../../../player/presentation/screens/player_ui.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../../trending/presentation/screens/trending_screen.dart';
import '../widgets/audio_output_bottomsheet.dart';
import '../widgets/profile_menu.dart';
import 'full_player_screen.dart';

class MobileMainScreen extends StatefulWidget {
  const MobileMainScreen({super.key});

  @override
  State<MobileMainScreen> createState() => _MobileMainScreenState();
}

class _MobileMainScreenState extends State<MobileMainScreen> {
  final PersistentTabController _controller = PersistentTabController(
    initialIndex: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      if (settingsProvider.updateCheckEnabled) {
        Provider.of<OTAProvider>(context, listen: false).checkForUpdates();
      }
    });
  }

  void _openSearch() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => const SearchScreen(),
        fullscreenDialog: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OTAProvider>(
      builder: (context, otaProvider, child) {
        if (otaProvider.hasUpdate &&
            otaProvider.updateInfo != null &&
            !otaProvider.isUpdateUIShown &&
            !otaProvider.isOTAScreenActive) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            otaProvider.setUpdateUIShown(true);
            _showOTABottomSheet(context, otaProvider.updateInfo!);
          });
        }

        return Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            final accentColor = settingsProvider.accentColor;
            final theme = settingsProvider.themeMode == ThemeMode.dark
                ? AppTheme.darkTheme
                : AppTheme.lightTheme;

            final mq = MediaQuery.of(context);
            final double navIconScale = mq.textScaleFactor > 1.0
                ? (1.0 / mq.textScaleFactor).clamp(0.75, 1.0).toDouble()
                : 1.0;
            final double navTextCap = mq.textScaleFactor > 1.0
                ? 1.0
                : mq.textScaleFactor;
            final double navIconSize = AppDimens.iconXl * navIconScale;
            final inactiveColor =
                theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.55) ??
                    Colors.grey;

            return Theme(
              data: theme,
              child: SafeArea(
                top: false,
                child: PersistentTabView(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  controller: _controller,
                  tabs: [
                    // ── Home ──────────────────────────────────────────────
                    PersistentTabConfig(
                      screen: _TabWrapper(
                        key: const ValueKey('home_tab'),
                        titleKey: 'home',
                        showLogo: true,
                        onSearchTap: _openSearch,
                        child: const HomeScreen(),
                      ),
                      item: ItemConfig(
                        icon: Icon(Icons.home_rounded, size: navIconSize),
                        inactiveIcon: Icon(
                          Icons.home_outlined,
                          size: navIconSize,
                        ),
                        title: 'home'.tr(),
                        activeForegroundColor: accentColor,
                        inactiveForegroundColor: inactiveColor,
                      ),
                    ),
                    // ── Explore (charts / trending until full Explore) ────
                    PersistentTabConfig(
                      screen: _TabWrapper(
                        key: const ValueKey('explore_tab'),
                        titleKey: 'explore',
                        onSearchTap: _openSearch,
                        child: const TrendingScreen(),
                      ),
                      item: ItemConfig(
                        icon: Icon(Icons.explore_rounded, size: navIconSize),
                        inactiveIcon: Icon(
                          Icons.explore_outlined,
                          size: navIconSize,
                        ),
                        title: 'explore'.tr(),
                        activeForegroundColor: accentColor,
                        inactiveForegroundColor: inactiveColor,
                      ),
                    ),
                    // ── Library ───────────────────────────────────────────
                    PersistentTabConfig(
                      screen: _TabWrapper(
                        key: const ValueKey('library_tab'),
                        titleKey: 'library',
                        onSearchTap: _openSearch,
                        child: const LibraryScreen(),
                      ),
                      item: ItemConfig(
                        icon: Icon(
                          Icons.library_music_rounded,
                          size: navIconSize,
                        ),
                        inactiveIcon: Icon(
                          Icons.library_music_outlined,
                          size: navIconSize,
                        ),
                        title: 'library'.tr(),
                        activeForegroundColor: accentColor,
                        inactiveForegroundColor: inactiveColor,
                      ),
                    ),
                  ],
                  navBarBuilder: (navBarConfig) => Consumer<PlayerProvider>(
                    builder: (context, playerProvider, child) {
                      final hasPlayer =
                          playerProvider.currentSong != null ||
                          playerProvider.lastPlayedSong != null ||
                          playerProvider.currentLocalSong != null;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasPlayer)
                            Container(
                              decoration: BoxDecoration(
                                color: theme.appBarTheme.backgroundColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppDimens.radiusMd),
                                ),
                              ),
                              child: SizedBox(
                                height:
                                    AppDimens.miniPlayerHeight * navIconScale,
                                child: PlayerUI(
                                  showFullScreen: false,
                                  isEmbedded: true,
                                  onMinimize: () {},
                                  onExpand: () =>
                                      _showFullPlayerBottomSheet(context),
                                ),
                              ),
                            ),
                          MediaQuery(
                            data: mq.copyWith(textScaleFactor: navTextCap),
                            child: MediaQuery.removePadding(
                              context: context,
                              removeBottom: true,
                              child: Style2BottomNavBar(
                                navBarConfig: navBarConfig,
                                navBarDecoration: NavBarDecoration(
                                  color: theme.appBarTheme.backgroundColor,
                                  borderRadius: BorderRadius.zero,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppDimens.spacingSmMd,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, -2),
                                    ),
                                  ],
                                ),
                                itemAnimationProperties: const ItemAnimation(
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showOTABottomSheet(BuildContext context, OTAUpdateInfo updateInfo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OTABottomSheet(updateInfo: updateInfo),
    );
  }

  void _showFullPlayerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (context) {
        return _MobileFullPlayerResponsiveWrapper(
          child: const FullPlayerScreen(),
          onSwitchToDesktop: () {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (MediaQuery.of(context).size.width >= 600) {
                Navigator.of(context, rootNavigator: true).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const FullPlayerScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 1),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 350),
                    reverseTransitionDuration:
                        const Duration(milliseconds: 300),
                  ),
                );
              }
            });
          },
        );
      },
    );
  }
}

class _MobileFullPlayerResponsiveWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwitchToDesktop;

  const _MobileFullPlayerResponsiveWrapper({
    Key? key,
    required this.child,
    required this.onSwitchToDesktop,
  }) : super(key: key);

  @override
  State<_MobileFullPlayerResponsiveWrapper> createState() =>
      _MobileFullPlayerResponsiveWrapperState();
}

class _MobileFullPlayerResponsiveWrapperState
    extends State<_MobileFullPlayerResponsiveWrapper>
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
    if (!_hasSwitched && width >= 600) {
      _hasSwitched = true;
      widget.onSwitchToDesktop();
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

/// Shared chrome for each root tab: YTM top bar (logo / title + actions).
class _TabWrapper extends StatelessWidget {
  final Widget child;
  final String titleKey;
  final bool showLogo;
  final VoidCallback? onSearchTap;

  const _TabWrapper({
    super.key,
    required this.child,
    required this.titleKey,
    this.showLogo = false,
    this.onSearchTap,
  });

  Future<void> _showAudioOutputSheet(BuildContext context) async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    await showAudioOutputBottomSheet(
      context,
      isDarkMode: settingsProvider.themeMode == ThemeMode.dark,
      accentColor: settingsProvider.accentColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final accentColor = settingsProvider.accentColor;
    final mq = MediaQuery.of(context);
    final double scale = mq.textScaleFactor > 1.0
        ? (1.0 / mq.textScaleFactor).clamp(0.75, 1.0).toDouble()
        : 1.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // No drawer — profile menu replaces the hamburger.
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: AppDimens.spacingMd * scale,
        title: showLogo
            ? Text(
                'Noize',
                style: AppTextStyles.titleLg(isDarkMode: isDark).copyWith(
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              )
            : Text(
                titleKey.tr(),
                style: AppTextStyles.titleLg(isDarkMode: isDark).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          if (Platform.isAndroid)
            IconButton(
              icon: Icon(
                Icons.speaker_rounded,
                size: AppDimens.iconLg * scale,
              ),
              onPressed: () => _showAudioOutputSheet(context),
              tooltip: 'Audio Output',
            ),
          IconButton(
            icon: Icon(Icons.search_rounded, size: AppDimens.iconLg * scale),
            onPressed: onSearchTap,
            tooltip: 'search'.tr(),
          ),
          Padding(
            padding: EdgeInsets.only(right: AppDimens.spacingSm * scale),
            child: IconButton(
              onPressed: () => showProfileMenu(context),
              tooltip: 'Profile',
              icon: CircleAvatar(
                radius: 14 * scale,
                backgroundColor: accentColor.withValues(alpha: 0.2),
                child: ClipOval(
                  child: Image.asset(
                    'assets/default_artwork.png',
                    width: 28 * scale,
                    height: 28 * scale,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: child,
    );
  }
}
