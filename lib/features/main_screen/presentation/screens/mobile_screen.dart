import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/models/ota_model.dart';
import '../../../../core/providers/player_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../home/presentation/widgets/ytm_home_widgets.dart';
import '../../../library/presentation/screens/library_screen.dart';
import '../../../ota/data/providers/ota_provider.dart';
import '../../../ota/presentation/widgets/ota_bottomsheet.dart';
import '../../../player/presentation/screens/player_ui.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../../../explore/presentation/screens/explore_screen.dart';
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
            final theme = settingsProvider.themeMode == ThemeMode.dark
                ? AppTheme.darkTheme
                : AppTheme.lightTheme;

            final mq = MediaQuery.of(context);
            final textScale = mq.textScaler.scale(1);
            final double navIconScale = textScale > 1.0
                ? (1.0 / textScale).clamp(0.75, 1.0).toDouble()
                : 1.0;
            final double navTextCap = textScale > 1.0 ? 1.0 : textScale;

            return Theme(
              data: theme,
              child: PersistentTabView(
                backgroundColor: theme.scaffoldBackgroundColor,
                controller: _controller,
                tabs: [
                  PersistentTabConfig(
                    screen: _TabWrapper(
                      key: const ValueKey('home_tab'),
                      titleKey: 'home',
                      showLogo: true,
                      child: const HomeScreen(),
                    ),
                    item: ItemConfig(
                      icon: const Icon(Icons.home_filled),
                      inactiveIcon: const Icon(Icons.home_outlined),
                      title: 'home'.tr(),
                    ),
                  ),
                  PersistentTabConfig(
                    screen: _TabWrapper(
                      key: const ValueKey('explore_tab'),
                      titleKey: 'explore',
                      child: const ExploreScreen(),
                    ),
                    item: ItemConfig(
                      icon: const Icon(Icons.explore),
                      inactiveIcon: const Icon(Icons.explore_outlined),
                      title: 'Explore',
                    ),
                  ),
                  PersistentTabConfig(
                    screen: _TabWrapper(
                      key: const ValueKey('library_tab'),
                      titleKey: 'library',
                      child: const LibraryScreen(),
                    ),
                    item: ItemConfig(
                      icon: const Icon(Icons.bookmark),
                      inactiveIcon: const Icon(Icons.bookmark_border),
                      title: 'library'.tr(),
                    ),
                  ),
                ],
                navBarBuilder: (navBarConfig) => Consumer<PlayerProvider>(
                  builder: (context, playerProvider, child) {
                    final hasPlayer =
                        playerProvider.currentSong != null ||
                        playerProvider.lastPlayedSong != null ||
                        playerProvider.currentLocalSong != null;
                    final isDark = theme.brightness == Brightness.dark;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasPlayer)
                          ColoredBox(
                            color: isDark
                                ? YtmColors.bar
                                : theme.colorScheme.surface,
                            child: SizedBox(
                              height: 64,
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
                          data: mq.copyWith(
                            textScaler: TextScaler.linear(navTextCap),
                          ),
                          child: _YtmBottomNavBar(
                            config: navBarConfig,
                            isDark: isDark,
                            iconScale: navIconScale,
                            onSearch: _openSearch,
                            backgroundColor: isDark
                                ? YtmColors.bar
                                : theme.colorScheme.surface,
                          ),
                        ),
                      ],
                    );
                  },
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
                            position:
                                Tween<Offset>(
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
                    reverseTransitionDuration: const Duration(
                      milliseconds: 300,
                    ),
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

/// YTM bottom navigation: flat bar, filled icon for the selected tab,
/// white labels. "Search" opens the search screen instead of a tab.
class _YtmBottomNavBar extends StatelessWidget {
  final NavBarConfig config;
  final bool isDark;
  final double iconScale;
  final VoidCallback onSearch;
  final Color backgroundColor;

  const _YtmBottomNavBar({
    required this.config,
    required this.isDark,
    required this.iconScale,
    required this.onSearch,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final color = YtmColors.text(isDark);

    Widget entry({
      required Widget icon,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkResponse(
          onTap: onTap,
          radius: 32,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconTheme(
                data: IconThemeData(color: color, size: 26 * iconScale),
                child: icon,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.font(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget tab(int index) {
      final item = config.items[index];
      final selected = config.selectedIndex == index;
      return entry(
        icon: selected ? item.icon : item.inactiveIcon,
        label: item.title ?? '',
        selected: selected,
        onTap: () => config.onItemSelected(index),
      );
    }

    return Container(
      color: backgroundColor,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (var i = 0; i < config.items.length; i++) ...[
              // Search sits between Explore and Library, as in YT Music.
              if (i == config.items.length - 1)
                entry(
                  icon: const Icon(Icons.search),
                  label: 'search'.tr(),
                  selected: false,
                  onTap: onSearch,
                ),
              tab(i),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared chrome for each root tab: YTM top bar (logo / title + actions).
/// On Home the bar is transparent over the colour wash and turns solid
/// once the content scrolls underneath it.
class _TabWrapper extends StatefulWidget {
  final Widget child;
  final String titleKey;
  final bool showLogo;

  const _TabWrapper({
    super.key,
    required this.child,
    required this.titleKey,
    this.showLogo = false,
  });

  @override
  State<_TabWrapper> createState() => _TabWrapperState();
}

class _TabWrapperState extends State<_TabWrapper> {
  bool _scrolled = false;

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

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final scrolled = notification.metrics.pixels > 8;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overlay = widget.showLogo;
    final barColor = overlay && !_scrolled
        ? Colors.transparent
        : theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: overlay,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: barColor,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: YtmDimens.sidePadding,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
        title: widget.showLogo
            ? YtmLogo(isDark: isDark)
            : Text(
                widget.titleKey.tr(),
                style: AppTextStyles.font(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: YtmColors.text(isDark),
                ),
              ),
        actions: [
          if (Platform.isAndroid)
            IconButton(
              icon: const Icon(Icons.cast),
              color: YtmColors.text(isDark),
              onPressed: () => _showAudioOutputSheet(context),
              tooltip: 'Audio output',
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => showProfileMenu(context),
              tooltip: 'Profile',
              icon: const YtmAvatar(size: 30),
            ),
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    );
  }
}
