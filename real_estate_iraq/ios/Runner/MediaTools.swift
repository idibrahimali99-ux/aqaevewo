import AVFoundation
import Flutter
import UIKit

/// قص/تحويل فيديو الآيفون إلى MP4 (H.264) قبل الرفع.
/// أندرويد لديه نفس القناة في MainActivity؛ بدون هذا يفشل نشر الريلز على iOS.
enum MediaToolsPlugin {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.aqartown.app/media_tools",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "trimVideo" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let inputPath = args["inputPath"] as? String, !inputPath.isEmpty,
            let outputPath = args["outputPath"] as? String, !outputPath.isEmpty
      else {
        result(FlutterError(code: "bad_args", message: "مسار الفيديو ناقص", details: nil))
        return
      }
      let startMs = int64Arg(args["startMs"])
      let endMs = int64Arg(args["endMs"])
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          try exportMp4(
            inputPath: inputPath,
            outputPath: outputPath,
            startMs: startMs,
            endMs: endMs
          )
          DispatchQueue.main.async { result(outputPath) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "trim_failed",
              message: error.localizedDescription,
              details: nil
            ))
          }
        }
      }
    }
  }

  private static func int64Arg(_ value: Any?) -> Int64 {
    if let n = value as? NSNumber { return n.int64Value }
    if let i = value as? Int { return Int64(i) }
    if let d = value as? Double { return Int64(d) }
    return 0
  }

  private static func fileURL(from path: String) -> URL {
    if path.hasPrefix("file://"), let url = URL(string: path) {
      return url
    }
    return URL(fileURLWithPath: path)
  }

  private static func exportMp4(
    inputPath: String,
    outputPath: String,
    startMs: Int64,
    endMs: Int64
  ) throws {
    let inputURL = fileURL(from: inputPath)
    let outputURL = fileURL(from: outputPath)
    try FileManager.default.createDirectory(
      at: outputURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    if FileManager.default.fileExists(atPath: outputURL.path) {
      try FileManager.default.removeItem(at: outputURL)
    }

    let asset = AVURLAsset(url: inputURL)
    let duration = asset.duration
    let durationMs = duration.seconds.isFinite ? Int64(duration.seconds * 1000) : 0
    var start = max(0, startMs)
    var end = endMs
    if end <= start + 100 {
      start = 0
      end = max(durationMs, start + 200)
    }
    if durationMs > 0 {
      end = min(end, durationMs)
    }
    if end <= start + 100 {
      throw NSError(
        domain: "MediaTools",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "مدة الفيديو المحددة قصيرة جداً"]
      )
    }

    let preferred = [
      AVAssetExportPreset1920x1080,
      AVAssetExportPreset1280x720,
      AVAssetExportPresetMediumQuality,
      AVAssetExportPresetHighestQuality,
      AVAssetExportPresetLowQuality,
    ]
    let compatible = AVAssetExportSession.exportPresets(compatibleWith: asset)
    guard let preset = preferred.first(where: { compatible.contains($0) }) ?? compatible.first,
          let session = AVAssetExportSession(asset: asset, presetName: preset)
    else {
      throw NSError(
        domain: "MediaTools",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "تعذر تحويل فيديو الآيفون إلى MP4"]
      )
    }

    session.outputURL = outputURL
    session.outputFileType = .mp4
    session.shouldOptimizeForNetworkUse = true
    session.timeRange = CMTimeRange(
      start: CMTime(value: start, timescale: 1000),
      duration: CMTime(value: end - start, timescale: 1000)
    )

    let done = DispatchSemaphore(value: 0)
    session.exportAsynchronously { done.signal() }
    done.wait()

    if session.status != .completed {
      let message = session.error?.localizedDescription ?? "فشل تحويل الفيديو"
      throw NSError(
        domain: "MediaTools",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: message]
      )
    }

    let size = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.int64Value ?? 0
    if size < 1024 {
      throw NSError(
        domain: "MediaTools",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "ملف الفيديو الناتج فارغ"]
      )
    }
  }
}
