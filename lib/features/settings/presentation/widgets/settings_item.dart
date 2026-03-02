import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';

class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDarkMode;
  final Color accentColor;

  const SettingsItem({
    Key? key,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    required this.isDarkMode,
    required this.accentColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity(vertical: -2, horizontal: -2),
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppDimens.paddingSm,
        vertical: AppDimens.paddingXs,
      ),
      minLeadingWidth: AppDimens.iconLg,
      horizontalTitleGap: AppDimens.spacingSm,
      leading: Container(
        padding: EdgeInsets.all(AppDimens.paddingXs),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
        child: Icon(icon, color: accentColor, size: AppDimens.iconMd),
      ),
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyMd(
          isDarkMode: isDarkMode,
        ).copyWith(fontWeight: AppTextStyles.weightMedium),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDarkMode;
  final Color accentColor;

  const SettingsSectionHeader({
    Key? key,
    required this.title,
    required this.icon,
    required this.isDarkMode,
    required this.accentColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.paddingXs,
        AppDimens.spacingXxl,
        AppDimens.paddingXs,
        AppDimens.spacingMd,
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: AppDimens.iconMdLg),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.titleSm(
              isDarkMode: isDarkMode,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
