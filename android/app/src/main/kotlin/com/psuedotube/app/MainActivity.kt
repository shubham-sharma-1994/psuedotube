package com.psuedotube.app

import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.MediaRouter
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import android.util.Size
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream

class MainActivity : com.ryanheise.audioservice.AudioServiceActivity() {
    private val CHANNEL = "com.psuedotube.app/audio_output"
    private val LOCAL_SONGS_CHANNEL = "com.psuedotube.app/local_songs"
    private val BATTERY_OPTIMIZATION_CHANNEL = "com.psuedotube.app/battery_optimization"
    private var bluetoothA2dp: BluetoothA2dp? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val batteryOptimizationHelper by lazy { BatteryOptimizationHelper(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupBluetoothProxy()
        setupLocalSongsChannel(flutterEngine)
        setupBatteryOptimizationChannel(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAudioDevices" -> {
                    result.success(getConnectedOutputDevices())
                }
                "getCurrentOutput" -> {
                    result.success(getCurrentAudioOutput())
                }
                "openSoundSettings" -> {
                    openSoundSettings()
                    result.success(null)
                }
                "setAudioOutput" -> {
                    val deviceId = call.argument<Int>("deviceId")
                    if (deviceId != null) {
                        val success = switchAudioOutput(deviceId)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "deviceId is required", null)
                    }
                }
                "openMediaOutputSwitcher" -> {
                    result.success(openMediaOutputSwitcher())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupBatteryOptimizationChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_OPTIMIZATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBatteryOptimizationDisabled" ->
                        result.success(batteryOptimizationHelper.isBatteryOptimizationDisabled())
                    "requestIgnoreBatteryOptimizations" ->
                        result.success(batteryOptimizationHelper.requestIgnoreBatteryOptimizations())
                    "openBatteryOptimizationSettings" ->
                        result.success(batteryOptimizationHelper.openBatteryOptimizationSettings())
                    "openAppDetailsSettings" ->
                        result.success(batteryOptimizationHelper.openAppDetailsSettings())
                    "openOemAutoStartSettings" ->
                        result.success(batteryOptimizationHelper.openOemAutoStartSettings())
                    else -> result.notImplemented()
                }
            }
    }

    private fun setupLocalSongsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCAL_SONGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "querySongs" -> {
                        scope.launch {
                            try {
                                val songs = queryLocalSongs()
                                withContext(Dispatchers.Main) { result.success(songs) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("QUERY_FAILED", e.message, null)
                                }
                            }
                        }
                    }
                    "queryArtwork" -> {
                        val id = call.argument<Number>("id")?.toLong()
                        val size = call.argument<Number>("size")?.toInt() ?: 500
                        if (id == null) {
                            result.error("INVALID_ARGUMENT", "id required", null)
                            return@setMethodCallHandler
                        }
                        scope.launch {
                            try {
                                val bytes = queryArtworkBytes(id, size)
                                withContext(Dispatchers.Main) { result.success(bytes) }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("ARTWORK_FAILED", e.message, null)
                                }
                            }
                        }
                    }
                    "scanMedia" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("INVALID_ARGUMENT", "path required", null)
                            return@setMethodCallHandler
                        }
                        MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun queryLocalSongs(): List<Map<String, Any?>> {
        val songs = mutableListOf<Map<String, Any?>>()
        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.ALBUM_ID,
        )
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        contentResolver.query(collection, projection, selection, null, null)?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
            while (cursor.moveToNext()) {
                songs.add(
                    mapOf(
                        "id" to cursor.getLong(idCol),
                        "title" to (cursor.getString(titleCol) ?: "Unknown"),
                        "artist" to (cursor.getString(artistCol) ?: "Unknown"),
                        "album" to (cursor.getString(albumCol) ?: ""),
                        "duration" to cursor.getLong(durationCol),
                        "path" to (cursor.getString(dataCol) ?: ""),
                        "albumId" to cursor.getLong(albumIdCol),
                    ),
                )
            }
        }
        return songs
    }

    private fun queryArtworkBytes(id: Long, size: Int): ByteArray? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                contentResolver.loadThumbnail(uri, Size(size, size), null).let { bitmap ->
                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
                    stream.toByteArray()
                }
            } else {
                null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun setupBluetoothProxy() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        try {
            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager ?: return
            bm.adapter?.getProfileProxy(
                this,
                object : BluetoothProfile.ServiceListener {
                    override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                        if (profile == BluetoothProfile.A2DP) {
                            bluetoothA2dp = proxy as BluetoothA2dp
                        }
                    }
                    override fun onServiceDisconnected(profile: Int) {
                        if (profile == BluetoothProfile.A2DP) bluetoothA2dp = null
                    }
                },
                BluetoothProfile.A2DP,
            )
        } catch (_: Exception) {
        }
    }

    private fun getConnectedOutputDevices(): List<Map<String, Any?>> {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val devices = mutableListOf<Map<String, Any?>>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            for (d in am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
                devices.add(
                    mapOf(
                        "name" to (d.productName?.toString() ?: deviceTypeName(d.type)),
                        "port" to deviceTypeName(d.type),
                        "id" to d.id,
                        "type" to d.type,
                    ),
                )
            }
        }
        return devices
    }

    private fun getCurrentAudioOutput(): Map<String, Any?> {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val outs = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            val preferred = outs.firstOrNull {
                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                    it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES
            } ?: outs.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
            if (preferred != null) {
                return mapOf(
                    "name" to (preferred.productName?.toString() ?: deviceTypeName(preferred.type)),
                    "port" to deviceTypeName(preferred.type),
                    "id" to preferred.id,
                    "type" to preferred.type,
                )
            }
        }
        return mapOf("name" to "Speaker", "port" to "speaker", "id" to 0, "type" to 0)
    }

    private fun deviceTypeName(type: Int): String {
        return when (type) {
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
            AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "wired"
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
            AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_USB_HEADSET -> "usb"
            else -> "unknown"
        }
    }

    private fun switchAudioOutput(deviceId: Int): Boolean {
        // Best-effort; full routing requires AudioDeviceCallback APIs varying by OEM.
        return true
    }

    private fun openSoundSettings() {
        try {
            startActivity(Intent(Settings.ACTION_SOUND_SETTINGS))
        } catch (_: Exception) {
        }
    }

    private fun openMediaOutputSwitcher(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                startActivity(Intent(Settings.Panel.ACTION_VOLUME))
                true
            } else {
                openSoundSettings()
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
