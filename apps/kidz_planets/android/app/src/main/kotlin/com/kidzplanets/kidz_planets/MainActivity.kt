package com.kidzplanets.kidz_planets

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val TV_CHANNEL = "kidz_planets/tv"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TV_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method == "isTelevision") {
                result.success(isTelevision())
            } else {
                result.notImplemented()
            }
        }
    }

    /// True when running on Android TV / Google TV.
    ///
    /// Either signal counts: the UiModeManager reports
    /// [Configuration.UI_MODE_TYPE_TELEVISION] on most TVs, while some
    /// dongles and operator boxes keep a mobile uiMode but still carry the
    /// leanback system feature (the same feature the Play Store filters on).
    /// Anything else — phones, tablets, emulators without TV mode — resolves
    /// to false.
    private fun isTelevision(): Boolean {
        if (packageManager.hasSystemFeature("android.software.leanback")) {
            return true
        }
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        if (uiModeManager != null &&
            uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
        ) {
            return true
        }
        return resources.configuration.uiMode and
            Configuration.UI_MODE_TYPE_MASK == Configuration.UI_MODE_TYPE_TELEVISION
    }
}
