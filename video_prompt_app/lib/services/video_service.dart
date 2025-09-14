import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/video_model.dart';

class VideoService {
  final List<VideoModel> _videos = [];
  List<VideoModel> get videos => _videos;

  void addVideo(VideoModel video) {
    _videos.add(video);
  }

  /// Get bytes for a file path (web)
  Uint8List? getBytesFromPath(String path) {
    final video = _videos.firstWhere(
      (v) =>
          v.path == path ||
          v.clipPath == path ||
          v.reelPath == path ||
          (v.resolutionPaths?.contains(path) ?? false),
      orElse: () => throw Exception("No video found for path $path"),
    );

    if (video.path == path) return video.bytes;
    if (video.clipPath == path) return video.clipBytes;
    if (video.reelPath == path) return video.reelBytes;
    if (video.resolutionPaths?.contains(path) ?? false) {
      return video.resolutionBytes?[path];
    }

    return null;
  }

  /// Upload video to backend
  Future<void> uploadVideo(VideoModel video) async {
    try {
      final dio = Dio();
      FormData formData;

      if (kIsWeb && video.bytes != null) {
        formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(video.bytes!, filename: video.name),
          'prompt': video.prompt,
        });
      } else if (video.path != null) {
        formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(video.path!, filename: video.name),
          'prompt': video.prompt,
        });
      } else {
        throw Exception("No valid file data found");
      }

      final response = await dio.post(
        'http://localhost:3000/api/videos/upload',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      if (response.statusCode == 200) {
  final data = response.data;
  final outputs = data['outputs'];

  // Save server-generated paths
  video.clipPath = outputs['clip'];
  video.reelPath = outputs['reel'];
  video.youtubeClipPath = outputs['youtubeStyle'];
  video.thumbnailPath = outputs['thumbnail'];
  video.gifPath = outputs['gifPreview'];

  // Save resolution paths
  if (outputs['resolutions'] != null) {
    video.resolutionPaths = List<String>.from(outputs['resolutions']);
  }

  // For web, fetch bytes for download
  if (kIsWeb) {
    video.clipBytes = await _fetchBytes(dio, video.clipPath!);
    video.reelBytes = await _fetchBytes(dio, video.reelPath!);

    if (video.resolutionPaths != null) {
      video.resolutionBytes ??= {};
      for (var r in video.resolutionPaths!) {
        video.resolutionBytes![r] = await _fetchBytes(dio, r);
      }
    }
  }

  print("✅ Upload successful: ${video.name}");
}
 else {
        print("❌ Upload failed: ${response.statusCode}");
      }
    } catch (e) {
      print("🚨 Error uploading video: $e");
    }
  }

  /// Helper: fetch bytes from URL for web download
  Future<Uint8List> _fetchBytes(Dio dio, String url) async {
    final response =
        await dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(response.data!);
  }
}
