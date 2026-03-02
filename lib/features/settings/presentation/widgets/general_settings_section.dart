import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../ota/data/providers/ota_provider.dart';
import '../screens/manage_data_screen.dart';
import 'settings_item.dart';
import '../screens/language_selection_screen.dart';
import 'custom_dropdown.dart';
import '../screens/crash_logs_screen.dart';
import '../../../../shared/components/app_snackbar.dart';

class GeneralSettingsSection extends StatelessWidget {
  const GeneralSettingsSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<
      SettingsProvider,
      ({bool isDarkMode, Color accentColor, String language})
    >(
      selector: (context, settingsProvider) => (
        isDarkMode: settingsProvider.themeMode == ThemeMode.dark,
        accentColor: settingsProvider.accentColor,
        language: settingsProvider.language,
      ),
      builder: (context, themeData, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsSectionHeader(
              title: 'general_settings'.tr(),
              icon: Icons.settings,
              isDarkMode: themeData.isDarkMode,
              accentColor: themeData.accentColor,
            ),

            Container(
              decoration: BoxDecoration(
                color: themeData.isDarkMode
                    ? MainScreenColors.darkSurfaceColor
                    : MainScreenColors.lightSurfaceColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                border: Border.all(
                  color: themeData.isDarkMode
                      ? Colors.white.withOpacity(AppDimens.opacitySubtle)
                      : Colors.black.withOpacity(AppDimens.opacitySubtle),
                  width: AppDimens.borderWidthThin,
                ),
              ),
              child: Column(
                children: [
                  Consumer<SettingsProvider>(
                    builder: (context, settingsProvider, child) {
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        if (Platform.isAndroid || Platform.isIOS) {
                          try {
                            PermissionStatus status =
                                await Permission.notification.status;
                            if (!status.isGranted &&
                                settingsProvider.notificationsEnabled) {
                              settingsProvider.notificationsEnabled = false;
                            }
                          } catch (e) {
                            debugPrint(
                              'Notification permission check failed: $e',
                            );

                            if (!Platform.isAndroid && !Platform.isIOS) {
                              settingsProvider.notificationsEnabled = false;
                            }
                          }
                        }
                      });

                      Future<void> _handleNotificationToggle(bool value) async {
                        if (!value) {
                          settingsProvider.notificationsEnabled = false;
                          return;
                        }

                        if (Platform.isAndroid || Platform.isIOS) {
                          try {
                            PermissionStatus status =
                                await Permission.notification.status;

                            if (status.isGranted) {
                              settingsProvider.notificationsEnabled = true;
                            } else {
                              PermissionStatus requestStatus = await Permission
                                  .notification
                                  .request();

                              if (requestStatus.isGranted) {
                                settingsProvider.notificationsEnabled = true;
                              } else {
                                settingsProvider.notificationsEnabled = false;
                                AppSnackBar.showWarning(
                                  context,
                                  'Notification permission is required to enable notifications'
                                      .tr(),
                                  action: SnackBarAction(
                                    label: 'Settings'.tr(),
                                    onPressed: openAppSettings,
                                  ),
                                );
                              }
                            }
                          } on MissingPluginException catch (e) {
                            debugPrint(
                              'Notification permission API not available: $e',
                            );
                            settingsProvider.notificationsEnabled = true;
                          } catch (e) {
                            debugPrint(
                              'Error while checking/requesting notification permission: $e',
                            );
                            settingsProvider.notificationsEnabled = false;
                          }
                        } else {
                          settingsProvider.notificationsEnabled = true;
                        }
                      }

                      return SettingsItem(
                        icon: Icons.notifications,
                        title: 'notifications_card_title'.tr(),
                        trailing: Switch(
                          value: settingsProvider.notificationsEnabled,
                          onChanged: _handleNotificationToggle,
                          activeColor: themeData.accentColor,
                        ),
                        isDarkMode: themeData.isDarkMode,
                        accentColor: themeData.accentColor,
                      );
                    },
                  ),

                  Divider(
                    height: 1,
                    thickness: 1,
                    color: themeData.isDarkMode
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.06),
                  ),

                  Consumer<SettingsProvider>(
                    builder: (context, settingsProvider, child) {
                      return SettingsItem(
                        icon: Icons.language,
                        title: 'language_card_title'.tr(),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              settingsProvider.language,
                              style:
                                  AppTextStyles.bodyMd(
                                    isDarkMode: themeData.isDarkMode,
                                  ).copyWith(
                                    color: MainScreenColors.getTextColor(
                                      themeData.isDarkMode,
                                    ).withOpacity(0.6),
                                  ),
                            ),
                            SizedBox(width: AppDimens.spacingSm),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: AppDimens.iconXs,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LanguageSelectionScreen(),
                            ),
                          );
                        },
                        isDarkMode: themeData.isDarkMode,
                        accentColor: themeData.accentColor,
                      );
                    },
                  ),

                  Divider(
                    height: 1,
                    thickness: 1,
                    color: themeData.isDarkMode
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.06),
                  ),

                  Consumer<SettingsProvider>(
                    builder: (context, settingsProvider, child) {
                      return SettingsItem(
                        icon: Icons.update,
                        title: 'update_channel'.tr(),
                        trailing: CustomDropdown<String>(
                          value: settingsProvider.updateChannel,
                          items: const ['stable', 'beta'],
                          onChanged: (value) {
                            if (value != null) {
                              settingsProvider.updateChannel = value;
                              final otaProvider = Provider.of<OTAProvider>(
                                context,
                                listen: false,
                              );
                              otaProvider.setUpdateChannel(value);
                              otaProvider.checkForUpdates();
                            }
                          },
                          isDarkMode: themeData.isDarkMode,
                          accentColor: themeData.accentColor,
                        ),
                        isDarkMode: themeData.isDarkMode,
                        accentColor: themeData.accentColor,
                      );
                    },
                  ),

                  Divider(
                    height: AppDimens.dividerHeight,
                    thickness: AppDimens.borderWidthThin,
                    color: themeData.isDarkMode
                        ? Colors.white.withOpacity(AppDimens.opacitySubtle)
                        : Colors.black.withOpacity(AppDimens.opacitySubtle),
                  ),

                  SettingsItem(
                    icon: Icons.storage,
                    title: 'manage_data'.tr(),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: AppDimens.iconXs,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageDataScreen(),
                        ),
                      );
                    },
                    isDarkMode: themeData.isDarkMode,
                    accentColor: themeData.accentColor,
                  ),

                  Divider(
                    height: AppDimens.dividerHeight,
                    thickness: AppDimens.borderWidthThin,
                    color: themeData.isDarkMode
                        ? Colors.white.withOpacity(AppDimens.opacitySubtle)
                        : Colors.black.withOpacity(AppDimens.opacitySubtle),
                  ),

                  SettingsItem(
                    icon: Icons.bug_report,
                    title: 'crash_logs_title'.tr(),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: AppDimens.iconXs,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CrashLogsScreen(),
                        ),
                      );
                    },
                    isDarkMode: themeData.isDarkMode,
                    accentColor: themeData.accentColor,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
