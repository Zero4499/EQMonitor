package net.yumnumm.eqmonitor

import android.app.Notification
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "sbs.ourstv.quakepush/permissions"

    /** 提示音播放的日志 tag，真机上可用 `adb logcat -s QuakePushSound` 直接看结果。 */
    private val soundTag = "QuakePushSound"

    /** 分级提示音播放器：同一时刻只保留一个，连续告警时后一条顶掉前一条。 */
    private var alertPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestIgnoreBatteryOptimizations" -> {
                        result.success(requestIgnoreBatteryOptimizations())
                    }
                    "openNotificationSettings" -> {
                        openNotificationSettings()
                        result.success(null)
                    }
                    "openAppDetailsSettings" -> {
                        openAppDetails()
                        result.success(null)
                    }
                    "openAutostartSettings" -> {
                        openAutostartSettings()
                        result.success(null)
                    }
                    "openChannelSettings" -> {
                        openChannelSettings(call.argument<String>("channelId"))
                        result.success(null)
                    }
                    "focusProtocolVersion" -> {
                        result.success(focusProtocolVersion())
                    }
                    "hasFocusPermission" -> {
                        result.success(hasFocusPermission())
                    }
                    "showIslandNotification" -> {
                        result.success(
                            showIslandNotification(
                                channelId = call.argument<String>("channelId"),
                                title = call.argument<String>("title") ?: "",
                                body = call.argument<String>("body") ?: "",
                                tag = call.argument<String>("tag"),
                                alert = call.argument<Boolean>("alert") ?: false,
                                accentColor = call.argument<String>("accentColor"),
                            ),
                        )
                    }
                    "playAlertSound" -> {
                        result.success(
                            playAlertSound(
                                soundName = call.argument<String>("sound") ?: "",
                                channelId = call.argument<String>("channelId"),
                                alert = call.argument<Boolean>("alert") ?: false,
                            ),
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * 播放 res/raw 里的分级提示音。
     *
     * 渠道声音交给系统播放时，国产 ROM 常常不认 `android.resource://` 自定义铃声
     * （HyperOS 还会在渠道设置里显示「声音：无」），导致通知静默。这里改成 App
     * 自己用 MediaPlayer 播，保证一定出声：
     * - 普通事件走 USAGE_NOTIFICATION，尊重静音 / 勿扰；
     * - 警报级（M7+ / 海啸警报）走 USAGE_ALARM，按闹钟音量出声。
     * 应用通知被关、或该渠道被用户关掉时不播。
     */
    private fun playAlertSound(soundName: String, channelId: String?, alert: Boolean): Boolean {
        if (soundName.isBlank()) {
            Log.w(soundTag, "skip: blank sound name")
            return false
        }
        return try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!nm.areNotificationsEnabled()) {
                Log.w(soundTag, "skip: app notifications disabled")
                return false
            }
            if (!channelId.isNullOrBlank()) {
                val channel = nm.getNotificationChannel(channelId)
                if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) {
                    Log.w(soundTag, "skip: channel $channelId is blocked by user")
                    return false
                }
            }
            val resId = resources.getIdentifier(soundName, "raw", packageName)
            if (resId == 0) {
                Log.w(soundTag, "skip: raw/$soundName not found in resources")
                return false
            }
            alertPlayer?.runCatching { release() }
            alertPlayer = null
            val attributes = AudioAttributes.Builder()
                .setUsage(
                    if (alert) AudioAttributes.USAGE_ALARM else AudioAttributes.USAGE_NOTIFICATION,
                )
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            val player = MediaPlayer()
            player.setAudioAttributes(attributes)
            // 优先用未压缩 raw 的 fd 直接播；有些构建会把音频压进 apk，
            // 这时 openRawResourceFd 会给 null，回退到解出缓存文件再播。
            val viaFd = runCatching {
                val afd = resources.openRawResourceFd(resId)
                    ?: throw IllegalStateException("openRawResourceFd returned null")
                try {
                    player.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                } finally {
                    afd.close()
                }
            }
            if (viaFd.isFailure) {
                Log.w(soundTag, "fd path failed: ${viaFd.exceptionOrNull()?.message}")
                val viaFile = runCatching {
                    val target = File(cacheDir, "alert_$soundName.mp3")
                    if (!target.exists() || target.length() == 0L) {
                        resources.openRawResource(resId).use { input ->
                            target.outputStream().use { out -> input.copyTo(out) }
                        }
                    }
                    player.setDataSource(target.absolutePath)
                }
                if (viaFile.isFailure) {
                    Log.w(soundTag, "cache file path failed: ${viaFile.exceptionOrNull()?.message}")
                    player.release()
                    return false
                }
            }
            player.prepare()
            player.setOnCompletionListener { mp ->
                mp.release()
                if (alertPlayer === mp) alertPlayer = null
            }
            player.setOnErrorListener { mp, what, extra ->
                Log.w(soundTag, "player error what=$what extra=$extra")
                mp.release()
                if (alertPlayer === mp) alertPlayer = null
                true
            }
            player.start()
            alertPlayer = player
            Log.i(
                soundTag,
                "playing raw/$soundName resId=$resId alert=$alert " +
                    "usage=${if (alert) "ALARM" else "NOTIFICATION"}",
            )
            true
        } catch (e: Exception) {
            Log.w(soundTag, "play failed: ${e.message}", e)
            false
        }
    }

    /** 申请电池优化白名单，否则国产 ROM 会在后台把进程杀掉导致收不到推送。 */
    private fun requestIgnoreBatteryOptimizations(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (powerManager.isIgnoringBatteryOptimizations(packageName)) {
            return true
        }
        return try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                .setData(Uri.parse("package:$packageName"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            // 部分 ROM 没有这个入口，退回到应用详情页
            try {
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.parse("package:$packageName"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                true
            } catch (ignored: Exception) {
                false
            }
        }
    }

    private fun openNotificationSettings() {
        try {
            startActivity(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (ignored: Exception) {
            // ignore
        }
    }

    /** 打开某一条具体通知渠道的系统设置页。 */
    private fun openChannelSettings(channelId: String?) {
        if (channelId.isNullOrBlank()) {
            openNotificationSettings()
            return
        }
        try {
            startActivity(
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (ignored: Exception) {
            openNotificationSettings()
        }
    }

    /** 打开本应用的系统详情页（权限 / 电池 / 通知等汇总入口）。 */
    private fun openAppDetails() {
        try {
            startActivity(
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        } catch (ignored: Exception) {
            // ignore
        }
    }

    /**
     * 焦点通知 / 超级岛协议版本：
     * 0 不支持，1 OS1 模板，2 OS2 焦点通知，3 OS3 超级岛。非小米 ROM 返回 0。
     */
    private fun focusProtocolVersion(): Int = try {
        Settings.System.getInt(contentResolver, "notification_focus_protocol", 0)
    } catch (e: Exception) {
        0
    }

    /** 查询本应用是否被允许显示焦点通知 / 超级岛；非小米 ROM 或未授权返回 false。 */
    private fun hasFocusPermission(): Boolean {
        return try {
            val uri = Uri.parse("content://miui.statusbar.notification.public")
            val extras = Bundle().apply { putString("package", packageName) }
            val bundle = contentResolver.call(uri, "canShowFocus", null, extras)
            bundle?.getBoolean("canShowFocus", false) ?: false
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 以原生 NotificationManager 发一条带超级岛参数的通知。
     *
     * 仅在 OS3 超级岛协议（版本 3）且焦点通知权限已开通时才投递岛通知；
     * 其余情况返回 false，由 Dart 侧回退到普通渠道通知。岛模板为最小图文模版：
     * 大岛 A 区文字信息，小岛回退应用图标；未在小米平台开通服务 / 设备未进白名单时，
     * 系统会自动降级为普通通知，不影响告警送达。
     */
    private fun showIslandNotification(
        channelId: String?,
        title: String,
        body: String,
        tag: String?,
        alert: Boolean,
        accentColor: String?,
    ): Boolean {
        return try {
            if (focusProtocolVersion() < 3 || !hasFocusPermission()) {
                return false
            }
            val channel = channelId?.takeIf { it.isNotBlank() } ?: "global_alert_v2"
            val accent = accentColor?.takeIf { it.isNotBlank() } ?: "#D62828"
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val textInfo = JSONObject()
                .put("frontTitle", "")
                .put("title", title)
                .put("content", body)
                .put("useHighLight", false)
            val imageTextLeft = JSONObject()
                .put("type", 1)
                .put("textInfo", textInfo)
            val bigIslandArea = JSONObject().put("imageTextInfoLeft", imageTextLeft)
            val smallIslandArea = JSONObject()
            val paramIsland = JSONObject()
                .put("islandProperty", 1)
                .put("bigIslandArea", bigIslandArea)
                .put("smallIslandArea", smallIslandArea)
            val baseInfo = JSONObject()
                .put("title", title)
                .put("content", body)
                .put("colorTitle", accent)
                .put("type", 2)
            val paramV2 = JSONObject()
                .put("business", "quake_warning")
                .put("enableFloat", true)
                .put("updatable", true)
                .put("ticker", title)
                .put("aodTitle", title)
                .put("param_island", paramIsland)
                .put("baseInfo", baseInfo)
            val islandParams = JSONObject().put("param_v2", paramV2).toString()

            val iconRes = resources.getIdentifier(
                "ic_notification_icon",
                "drawable",
                packageName,
            )
            val builder = Notification.Builder(this, channel)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(if (iconRes != 0) iconRes else applicationInfo.icon)
                .setAutoCancel(!alert)
                .setOngoing(alert)
                .setPriority(
                    if (alert) Notification.PRIORITY_MAX else Notification.PRIORITY_HIGH,
                )
            if (alert) {
                builder.setCategory(Notification.CATEGORY_ALARM)
            }
            val notification = builder.build()
            notification.extras.putString("miui.focus.param", islandParams)

            val id = (tag ?: "$title-$body").hashCode() and 0x7fffffff
            nm.notify(id, notification)
            true
        } catch (e: Exception) {
            false
        }
    }

    /**
     * 跳小米/澎湃 OS 的后台自启动管理页；ROM 没有这个入口时退回应用详情页。
     * 自启动与电池「无限制」一起开，才能保证 App 被杀后还能收到推送。
     */
    private fun openAutostartSettings() {
        val launched = try {
            startActivity(
                Intent().setComponent(
                    ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity",
                    ),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (e: Exception) {
            false
        }
        if (!launched) {
            openAppDetails()
        }
    }
}
