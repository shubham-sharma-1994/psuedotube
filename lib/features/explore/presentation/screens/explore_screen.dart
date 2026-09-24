import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../trending/presentation/screens/trending_screen.dart';

/// YTM Explore tab: Charts lead (country + Top 100 Global via [TrendingScreen]).
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accentColor = context.select((SettingsProvider p) => p.accentColor);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.paddingLg,
            AppDimens.paddingMd,
            AppDimens.paddingLg,
            AppDimens.spacingSm,
          ),
          child: Text(
            'Charts',
            style: AppTextStyles.titleLg().copyWith(
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.paddingLg),
          child: Text(
            'Top songs by country and global charts',
            style: AppTextStyles.caption(isDarkMode: isDarkMode).copyWith(
              color: (isDarkMode ? Colors.white : Colors.black)
                  .withValues(alpha: 0.55),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spacingSm),
        const Expanded(child: TrendingScreen()),
      ],
    );
  }
}
