import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class VideoProcessingService {
  /// Generate a clip from a video
  /// [inputPath] - original video path
  /// [outputPath] - output clip path
  /// [start] - start duration
  /// [duration] - clip duration
  Future<File?> generateClip({
    required String inputPath,
    required String outputPath,
    Duration start = const Duration(seconds: 0),
    Duration duration = const Duration(seconds: 10),
  }) async {
    final startSeconds = start.inSeconds;
    final durationSeconds = duration.inSeconds;

    // FFmpeg command to cut a clip
    final command =
        '-i "$inputPath" -ss $startSeconds -t $durationSeconds -c copy "$outputPath"';

    try {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return File(outputPath);
      } else {
        print("FFmpeg failed with return code: $returnCode");
        return null;
      }
    } catch (e) {
      print("Error generating clip: $e");
      return null;
    }
  }
}
