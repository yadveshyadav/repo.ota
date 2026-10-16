package com.infocrats.hero_app

import android.content.Intent
import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.provider.MediaStore
import androidx.core.content.FileProvider
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.infocrats.hero/ota_installer"
    private val EVIDENCE_CHANNEL = "com.infocrats.hero/evidence_export"
    private val VIDEO_CHANNEL = "com.infocrats.hero/video_compression"

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
                    "saveDraftBackup" -> {
                        val relativePath = call.argument<String>("relativePath")
                            ?: throw IllegalArgumentException("Report folder path is missing")
                        val payload = call.argument<String>("payload")
                            ?: throw IllegalArgumentException("Draft payload is missing")
                        val uri = writeDownloadFile(
                            relativePath = relativePath,
                            fileName = "_draft.json",
                            mimeType = "application/json",
                            bytes = payload.toByteArray(Charsets.UTF_8),
                        )
                        result.success(uri.toString())
                    }
                    "listDraftBackups" -> result.success(listDraftBackups())
                    "readExportedFile" -> {
                        val relativePath = call.argument<String>("relativePath")
                            ?: throw IllegalArgumentException("Evidence folder path is missing")
                        val fileName = call.argument<String>("fileName")
                            ?: throw IllegalArgumentException("Evidence file name is missing")
                        result.success(readDownloadFile(relativePath, fileName))
                    }
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIDEO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "compressVideo" -> compressVideo(call.argument<String>("inputPath"), call.argument<String>("outputPath"), result)
                "supportedFpsRanges" -> supportedFpsRanges(call.argument<String>("cameraId"), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun supportedFpsRanges(cameraId: String?, result: MethodChannel.Result) {
        if (cameraId.isNullOrBlank()) {
            result.success(emptyList<List<Int>>())
            return
        }
        try {
            val manager = getSystemService(CAMERA_SERVICE) as android.hardware.camera2.CameraManager
            val ranges = manager.getCameraCharacteristics(cameraId)
                .get(android.hardware.camera2.CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
                .orEmpty()
                .map { listOf(it.lower, it.upper) }
            result.success(ranges)
        } catch (error: Exception) {
            result.success(emptyList<List<Int>>())
        }
    }

    @OptIn(UnstableApi::class)
    private fun compressVideo(inputPath: String?, outputPath: String?, result: MethodChannel.Result) {
        val input = inputPath?.let(::File)
        val output = outputPath?.let(::File)
        if (input == null || !input.isFile || input.length() == 0L || output == null) {
            result.error("INVALID_VIDEO", "The source video is missing or empty", null)
            return
        }
        if (output.exists() && !output.delete()) {
            result.error("OUTPUT_UNAVAILABLE", "Could not prepare the compressed video file", null)
            return
        }

        try {
            val retriever = android.media.MediaMetadataRetriever()
            retriever.setDataSource(input.absolutePath)
            val width = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
            val height = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
            val sourceDurationMs = retriever.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            retriever.release()
            if (width <= 0 || height <= 0 || sourceDurationMs <= 0L) {
                result.error("INVALID_VIDEO", "Video dimensions could not be read", null)
                return
            }
            if (minOf(width, height) <= 1080 && input.length() <= 8L * 1024L * 1024L) {
                result.success(mapOf(
                    "path" to input.absolutePath,
                    "sizeBytes" to input.length(),
                    "width" to width,
                    "height" to height,
                    "durationMs" to sourceDurationMs,
                    "unchanged" to true,
                ))
                return
            }

            val encoderFactory = DefaultEncoderFactory.Builder(applicationContext)
                .setEnableFallback(true)
                .setRequestedVideoEncoderSettings(
                    VideoEncoderSettings.Builder().setBitrate(10_000_000).build(),
                )
                .setRequestedAudioEncoderSettings(
                    AudioEncoderSettings.Builder().setBitrate(96_000).build(),
                )
                .build()
            val transformer = Transformer.Builder(applicationContext)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoderFactory)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: androidx.media3.transformer.Composition, exportResult: androidx.media3.transformer.ExportResult) {
                        try {
                            if (!output.isFile || output.length() == 0L) {
                                throw IllegalStateException("Encoder produced an empty video")
                            }
                            val metadata = android.media.MediaMetadataRetriever()
                            metadata.setDataSource(output.absolutePath)
                            val outWidth = metadata.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 0
                            val outHeight = metadata.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 0
                            val durationMs = metadata.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                            metadata.release()
                            if (outWidth <= 0 || outHeight <= 0 || durationMs <= 0L) {
                                throw IllegalStateException("Compressed video could not be validated")
                            }
                            if (minOf(outWidth, outHeight) > 1080) {
                                throw IllegalStateException("Compressed video exceeds the 1080p limit")
                            }
                            val durationToleranceMs = maxOf(1000L, sourceDurationMs / 50L)
                            if (kotlin.math.abs(durationMs - sourceDurationMs) > durationToleranceMs) {
                                throw IllegalStateException("Compressed video duration does not match the original")
                            }
                            result.success(mapOf(
                                "path" to output.absolutePath,
                                "sizeBytes" to output.length(),
                                "width" to outWidth,
                                "height" to outHeight,
                                "durationMs" to durationMs,
                                "unchanged" to false,
                            ))
                        } catch (error: Exception) {
                            output.delete()
                            result.error("VIDEO_VALIDATION_FAILED", error.localizedMessage, null)
                        }
                    }

                    override fun onError(
                        composition: androidx.media3.transformer.Composition,
                        exportResult: androidx.media3.transformer.ExportResult,
                        exportException: androidx.media3.transformer.ExportException,
                    ) {
                        output.delete()
                        result.error("VIDEO_COMPRESSION_FAILED", exportException.localizedMessage, null)
                    }
                })
                .build()

            val videoEffects = if (minOf(width, height) > 1080) {
                listOf(Presentation.createForShortSide(1080))
            } else {
                emptyList()
            }
            val editedItem = EditedMediaItem.Builder(MediaItem.fromUri(android.net.Uri.fromFile(input)))
                .setEffects(Effects(emptyList(), videoEffects))
                .build()
            transformer.start(editedItem, output.absolutePath)
        } catch (error: Exception) {
            output.delete()
            result.error("VIDEO_COMPRESSION_FAILED", error.localizedMessage, null)
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

    private fun normalizeDownloadPath(path: String): String = path
        .split("/")
        .filter { it.isNotBlank() && it != "." && it != ".." }
        .joinToString("/")
        .takeIf { it.isNotBlank() }
        ?: throw IllegalArgumentException("Report folder path is missing")

    private fun writeDownloadFile(
        relativePath: String,
        fileName: String,
        mimeType: String,
        bytes: ByteArray,
    ): Uri {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw IllegalStateException("Public evidence folders require Android 10 or newer")
        }
        val safePath = normalizeDownloadPath(relativePath)
        val safeName = fileName.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} = ? AND ${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
        val existing = contentResolver.query(
            collection,
            projection,
            selection,
            arrayOf("${Environment.DIRECTORY_DOWNLOADS}/$safePath/", safeName),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) Uri.withAppendedPath(collection, cursor.getLong(0).toString()) else null
        }
        val uri = existing ?: contentResolver.insert(collection, ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, safeName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/$safePath")
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }) ?: throw IllegalStateException("Android could not create the draft backup")
        try {
            contentResolver.openOutputStream(uri, "w")?.use { output ->
                output.write(bytes)
                output.flush()
            } ?: throw IllegalStateException("Android could not write the draft backup")
            contentResolver.update(uri, ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }, null, null)
            return uri
        } catch (error: Exception) {
            if (existing == null) contentResolver.delete(uri, null, null)
            throw error
        }
    }

    private fun listDraftBackups(): List<Map<String, String>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return emptyList()
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection = "${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
        return contentResolver.query(collection, projection, selection, arrayOf("_draft.json"), null)
            ?.use { cursor ->
                val backups = mutableListOf<Map<String, String>>()
                while (cursor.moveToNext()) {
                    val uri = Uri.withAppendedPath(collection, cursor.getLong(0).toString())
                    runCatching {
                        val payload = contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }
                        if (!payload.isNullOrBlank()) backups.add(mapOf("payload" to payload))
                    }
                }
                backups
            } ?: emptyList()
    }

    private fun readDownloadFile(relativePath: String, fileName: String): ByteArray? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val safePath = normalizeDownloadPath(relativePath)
        val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection = "${MediaStore.MediaColumns.RELATIVE_PATH} = ? AND ${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
        val uri = contentResolver.query(
            collection,
            projection,
            selection,
            arrayOf("${Environment.DIRECTORY_DOWNLOADS}/$safePath/", fileName),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) Uri.withAppendedPath(collection, cursor.getLong(0).toString()) else null
        } ?: return null
        return contentResolver.openInputStream(uri)?.use { it.readBytes() }
    }
}
