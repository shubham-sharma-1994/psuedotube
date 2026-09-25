package com.psuedotube.app

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

/**
 * Helpers for OEM battery / background restrictions so media playback survives.
 */
class BatteryOptimizationHelper(private val activity: Activity) {

    fun isBatteryOptimizationDisabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(activity.packageName)
    }

    @SuppressLint("BatteryLife")
    fun requestIgnoreBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (isBatteryOptimizationDisabled()) return true
        return try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${activity.packageName}")
            }
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.w(TAG, "requestIgnoreBatteryOptimizations failed", e)
            openBatteryOptimizationSettings()
        }
    }

    fun openBatteryOptimizationSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.w(TAG, "openBatteryOptimizationSettings failed", e)
            openAppDetailsSettings()
        }
    }

    fun openAppDetailsSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${activity.packageName}")
            }
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.w(TAG, "openAppDetailsSettings failed", e)
            false
        }
    }

    fun openOemAutoStartSettings(): Boolean {
        val intents = listOf(
            // Xiaomi / MIUI
            Intent().setComponent(
                ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity",
                ),
            ),
            // Huawei
            Intent().setComponent(
                ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                ),
            ),
            Intent().setComponent(
                ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity",
                ),
            ),
            // Oppo / ColorOS
            Intent().setComponent(
                ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                ),
            ),
            Intent().setComponent(
                ComponentName(
                    "com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity",
                ),
            ),
            // Vivo
            Intent().setComponent(
                ComponentName(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
                ),
            ),
            Intent().setComponent(
                ComponentName(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                ),
            ),
            // Samsung
            Intent().setComponent(
                ComponentName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity",
                ),
            ),
            // OnePlus
            Intent().setComponent(
                ComponentName(
                    "com.oneplus.security",
                    "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
                ),
            ),
        )
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                return true
            } catch (_: Exception) {
                // try next OEM intent
            }
        }
        return openAppDetailsSettings()
    }

    companion object {
        private const val TAG = "BatteryOptHelper"
    }
}
