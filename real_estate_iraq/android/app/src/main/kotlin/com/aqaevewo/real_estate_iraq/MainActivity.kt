package com.aqaevewo.real_estate_iraq

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private val mediaChannel = "com.aqaevewo.real_estate_iraq/media_tools"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "trimVideo") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val input = call.argument<String>("inputPath") ?: ""
                    val output = call.argument<String>("outputPath") ?: ""
                    val startMs = (call.argument<Number>("startMs") ?: 0).toLong()
                    val endMs = (call.argument<Number>("endMs") ?: 0).toLong()
                    trimVideo(input, output, startMs, endMs)
                    result.success(output)
                } catch (e: Exception) {
                    result.error("trim_failed", e.message ?: "Video trim failed", null)
                }
            }
    }

    private fun trimVideo(inputPath: String, outputPath: String, startMs: Long, endMs: Long) {
        require(inputPath.isNotBlank()) { "Input path is empty" }
        require(outputPath.isNotBlank()) { "Output path is empty" }
        require(endMs > startMs + 100) { "Selected video range is too short" }

        val outFile = File(outputPath)
        outFile.parentFile?.mkdirs()
        if (outFile.exists()) outFile.delete()

        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            extractor.setDataSource(inputPath)
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            setOutputRotation(inputPath, muxer)

            val trackMap = HashMap<Int, Int>()
            var maxInputSize = 1024 * 1024
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("video/") || mime.startsWith("audio/")) {
                    extractor.selectTrack(i)
                    trackMap[i] = muxer.addTrack(format)
                    if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                        maxInputSize = maxOf(maxInputSize, format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE))
                    }
                }
            }
            require(trackMap.isNotEmpty()) { "No audio/video tracks found" }

            val startUs = startMs * 1000
            val endUs = endMs * 1000
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
            muxer.start()

            val buffer = ByteBuffer.allocate(maxInputSize)
            val info = MediaCodec.BufferInfo()
            while (true) {
                val trackIndex = extractor.sampleTrackIndex
                if (trackIndex < 0) break
                val outTrack = trackMap[trackIndex]
                if (outTrack == null) {
                    extractor.advance()
                    continue
                }

                val sampleTime = extractor.sampleTime
                if (sampleTime > endUs) break
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) break
                if (sampleTime >= startUs) {
                    info.set(0, sampleSize, sampleTime - startUs, extractor.sampleFlags)
                    muxer.writeSampleData(outTrack, buffer, info)
                }
                extractor.advance()
            }
        } finally {
            try {
                muxer?.stop()
            } catch (_: Exception) {
            }
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
            extractor.release()
        }
        require(outFile.exists() && outFile.length() > 1024) { "Trimmed file was not created" }
    }

    private fun setOutputRotation(inputPath: String, muxer: MediaMuxer) {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(inputPath)
            val rotation = retriever
                .extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            if (rotation == 90 || rotation == 180 || rotation == 270) {
                muxer.setOrientationHint(rotation)
            }
        } catch (_: Exception) {
        } finally {
            retriever.release()
        }
    }
}
