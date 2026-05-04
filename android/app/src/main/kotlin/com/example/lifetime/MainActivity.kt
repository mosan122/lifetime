package com.example.lifetime

import android.media.MediaScannerConnection
import android.os.Environment
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
  private val channelName = "lifetime/media_scanner"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getMediaRoot" -> {
            try {
              val base = Environment.getExternalStorageDirectory().absolutePath
              val root = "$base/Android/media/${applicationContext.packageName}/LifeTime/Media"
              result.success(root)
            } catch (e: Exception) {
              result.error("getMediaRoot_failed", e.message, null)
            }
          }
          "scanFile" -> {
            val path = call.argument<String>("path")
            if (path == null || path.isBlank()) {
              result.error("invalid_args", "path is required", null)
              return@setMethodCallHandler
            }
            try {
              MediaScannerConnection.scanFile(
                applicationContext,
                arrayOf(path),
                null,
                null
              )
              result.success(null)
            } catch (e: Exception) {
              result.error("scanFile_failed", e.message, null)
            }
          }
          else -> result.notImplemented()
        }
      }
  }
}
