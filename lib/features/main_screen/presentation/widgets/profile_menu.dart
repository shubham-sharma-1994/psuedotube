import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../downloads/presentation/screens/downloads_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../stats/presentation/screens/stats_screen.dart';

/// YTM-style profile menu opened from the top-bar avatar.
/// Migrates every entry that used to live in the hamburger drawer.
Future<void> showProfileMenu(BuildContext context) {
  final settings = Provider.of<SettingsProvider>(context, listen: false);
  final isDark = settings.themeMode == ThemeMode.dark;
  final accent = settings.accentColor;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: MainScreenColors.getElevatedSurfaceColor(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MainScreenColors.getDividerColor(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.2),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/default_artwork.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(
                  'Noize',
                  style: AppTextStyles.titleSm(isDarkMode: isDark),
                ),
                subtitle: Text(
                  'welcome'.tr(),
                  style: AppTextStyles.body2(isDarkMode: isDark),
                ),
              ),
              const Divider(),
              _tile(
                ctx,
                icon: Icons.settings_rounded,
                label: 'settings'.tr(),
                isDark: isDark,
                onTap: () => _push(ctx, const SettingsScreen()),
              ),
              _tile(
                ctx,
                icon: Icons.download_done_rounded,
                label: 'downloads'.tr(),
                isDark: isDark,
                onTap: () => _push(ctx, const DownloadsScreen()),
              ),
              _tile(
                ctx,
                icon: Icons.show_chart_rounded,
                label: 'stats'.tr(),
                isDark: isDark,
                onTap: () => _push(ctx, StatsScreen()),
              ),
              const Divider(),
              _tile(
                ctx,
                icon: Icons.language,
                label: 'Website',
                isDark: isDark,
                onTap: () => _launch('https://noizeapp.netlify.app/'),
              ),
              _tile(
                ctx,
                icon: Icons.telegram,
                label: 'Telegram',
                isDark: isDark,
                onTap: () => _launch('https://t.me/NoizeUpdates'),
              ),
              _tile(
                ctx,
                icon: Icons.code,
                label: 'GitHub',
                isDark: isDark,
                onTap: () => _launch(
                  'https://github.com/shubham-sharma-1994/psuedotube',
                ),
              ),
              _tile(
                ctx,
                icon: Icons.share_rounded,
                label: 'share_app'.tr(),
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(ctx);
                  await SharePlus.instance.share(
                    ShareParams(
                      text:
                          'Check out Noize - Your personal music companion!\nhttps://noizeapp.netlify.app/',
                      subject: 'Noize Music App',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _tile(
  BuildContext context, {
  required IconData icon,
  required String label,
  required bool isDark,
  required VoidCallback onTap,
}) {
  return ListTile(
    leading: Icon(icon, size: AppDimens.iconLg),
    title: Text(label, style: AppTextStyles.bodyMd(isDarkMode: isDark)),
    onTap: onTap,
  );
}

void _push(BuildContext context, Widget screen) {
  Navigator.pop(context);
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(builder: (_) => screen),
  );
}

Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
