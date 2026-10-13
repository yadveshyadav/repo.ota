package com.infocrats.hero_app

import android.content.Intent
import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.infocrats.hero/ota_installer"
    private val EVIDENCE_CHANNEL = "com.infocrats.hero/evidence_export"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(context.packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallPermissionSettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${context.packageName}")
                            )
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR_OPENING_SETTINGS", e.localizedMessage, null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath.isNullOrEmpty()) {
                        result.error("INVALID_PATH", "APK file path cannot be empty", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val file = File(filePath)
                        if (!file.exists() || file.length() == 0L) {
                            result.error("FILE_NOT_FOUND", "APK file does not exist or is empty", null)
                            return@setMethodCallHandler
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !context.packageManager.canRequestPackageInstalls()) {
                            val settingsIntent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${context.packageName}")
                            )
                            settingsIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(settingsIntent)
                            result.error("PERMISSION_REQUIRED", "Installation permission is required", null)
                            return@setMethodCallHandler
                        }

                        val apkUri: Uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )

                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }

                        context.startActivity(installIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_FAILED", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EVIDENCE_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "exportBytes" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                            ?: throw IllegalArgumentException("File bytes are missing")
                        val uri = exportToDownloads(
                            bytes = bytes,
                            sourcePath = null,
                            relativePath = call.argument<String>("relativePath"),
                            fileName = call.argument<String>("fileName"),
                            mimeType = call.argument<String>("mimeType"),
                        )
                        result.success(mapOf("uri" to uri.toString()))
                    }
                    "exportFile" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                            ?: throw IllegalArgumentException("Source file path is missing")
                        val uri = exportToDownloads(
                            bytes = null,
                            sourcePath = sourcePath,
                            relativePath = call.argument<String>("relativePath"),
                            fileName = call.argument<String>("fileName"),
                            mimeType = call.argument<String>("mimeType"),
                        )
                        result.success(mapOf("uri" to uri.toString()))
                    }
                    "deleteExport" -> {
                        val uri = call.argument<String>("uri")
                        result.success(uri != null && contentResolver.delete(Uri.parse(uri), null, null) > 0)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("EVIDENCE_EXPORT_FAILED", error.localizedMessage ?: "Could not export evidence", null)
            }
        }
    }

    private fun exportToDownloads(
        bytes: ByteArray?,
        sourcePath: String?,
        relativePath: String?,
        fileName: String?,
        mimeType: String?,
    ): Uri {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw IllegalStateException("Public evidence folders require Android 10 or newer")
        }
        val safeRelativePath = relativePath
            ?.split("/")
            ?.filter { it.isNotBlank() && it != "." && it != ".." }
            ?.joinToString("/")
            ?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("Report folder path is missing")
        val safeName = fileName
            ?.replace(Regex("[^A-Za-z0-9._-]"), "_")
            ?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("File name is missing")
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, safeName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType ?: "application/octet-stream")
            put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$safeRelativePath")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Android could not create the public evidence file")
        try {
            contentResolver.openOutputStream(uri, "w")?.use { output ->
                if (sourcePath != null) {
                    File(sourcePath).inputStream().use { input -> input.copyTo(output) }
                } else {
                    output.write(bytes ?: ByteArray(0))
                }
                output.flush()
            } ?: throw IllegalStateException("Android could not open the public evidence file")
            val published = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
            contentResolver.update(uri, published, null, null)
            return uri
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }
}
