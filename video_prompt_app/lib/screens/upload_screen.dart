import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../models/video_model.dart';
import '../services/video_processing_service.dart';
import '../services/video_service.dart';
import '../services/video_socket_service.dart';
import 'package:video_prompt_app/screens/playful_video_page.dart';
import 'dart:html' as html;

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final VideoProcessingService _videoProcessor = VideoProcessingService();
  final VideoService _videoService = VideoService();
  late final VideoSocketService _socketService;
  final TextEditingController _promptController = TextEditingController();
  bool _autoPreviewLatest = true;
  VideoPlayerController? _videoPlayerController;
  String? _previewName;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _socketService = VideoSocketService(_videoService);
    _socketService.connect();
    _socketService.addListener(_updateProgress);
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _promptController.dispose();
    _socketService.removeListener(_updateProgress);
    _socketService.disconnect();
    super.dispose();
  }

  void _updateProgress() {
    setState(() {
      _progress = _socketService.progress;
    });

    if (_videoService.videos.isEmpty) return;

    final video = _videoService.videos.last;
    final clips = video.eventClipPaths ?? [];
    final thumbs = video.eventClipThumbs ?? [];
    final gifs = video.eventClipGifs ?? [];

    if (clips.isEmpty) return;

    final latestIndex = clips.length - 1;
    final latestClip = clips[latestIndex];
    final latestGif = latestIndex < gifs.length ? gifs[latestIndex] : null;
    final latestThumb = latestIndex < thumbs.length
        ? thumbs[latestIndex]
        : null;

    if (_autoPreviewLatest) {
      if (latestGif != null && latestGif.isNotEmpty) {
        _startPreview(
          path: latestGif,
          name: "${video.name} - GIF Clip ${latestIndex + 1}",
        );
      } else if (latestClip.isNotEmpty) {
        _startPreview(
          path: latestClip,
          name: "${video.name} - Event Clip ${latestIndex + 1}",
        );
      }
    }
  }

  Future<String?> _askClipPrompt() async {
    String? clipPrompt;
    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text("Enter Clip Prompt"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Optional prompt for this clip",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                clipPrompt = controller.text.trim();
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
    return clipPrompt;
  }

  void _downloadFile(String path, String fileName) {
    final bytes = _videoService.getBytesFromPath(path);
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot download, file not found.")),
      );
      return;
    }
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'video/mp4');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final savePath = "${Directory.systemTemp.path}/$fileName";
      File(savePath).writeAsBytesSync(bytes);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("File saved at: $savePath")));
    }
  }

  void _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.isNotEmpty) {
      final pickedFile = result.files.single;
      final prompt = _promptController.text.trim();

      VideoModel video;
      if (kIsWeb) {
        video = VideoModel(
          bytes: pickedFile.bytes,
          name: pickedFile.name,
          prompt: prompt,
          uploadedAt: DateTime.now(),
        );
      } else {
        video = VideoModel(
          path: pickedFile.path,
          name: pickedFile.name,
          prompt: prompt,
          uploadedAt: DateTime.now(),
        );
      }

      _videoService.addVideo(video);
      _promptController.clear();

      final clipPrompt = await _askClipPrompt();
      video.clipPrompt = clipPrompt;

      if (!kIsWeb && video.path != null && File(video.path!).existsSync()) {
  final tempClipPath = "${Directory.systemTemp.path}/clip_preview.mp4";
  final clip = await _videoProcessor.generateClip(
    inputPath: video.path!,
    outputPath: tempClipPath,
    start: const Duration(seconds: 0),
    duration: const Duration(seconds: 10),
  );
  if (clip != null && clip.existsSync()) {
    video.clipPath = clip.path;
    _startPreview(path: clip.path, name: "Clip Preview");
  } else {
    _startPreview(path: video.path!, name: video.name);
  }
} else {
  _startPreview(bytes: video.bytes, name: video.name);
}

    }
  }

  void _startPreview({String? path, Uint8List? bytes, String? name}) {
    _videoPlayerController?.dispose();

    if (path != null) {
      if (kIsWeb) {
        final url = html.Url.createObjectUrlFromBlob(
          html.Blob([bytes ?? File(path).readAsBytesSync()]),
        );
        _videoPlayerController = VideoPlayerController.network(url)
          ..initialize().then((_) {
            setState(() {
              _previewName = name;
              _videoPlayerController!.play();
              _videoPlayerController!.setLooping(true);
            });
          });
      } else {
        _videoPlayerController = VideoPlayerController.file(File(path))
          ..initialize().then((_) {
            setState(() {
              _previewName = name;
              _videoPlayerController!.play();
              _videoPlayerController!.setLooping(true);
            });
          });
      }
    } else if (bytes != null) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
      _videoPlayerController = VideoPlayerController.network(url)
        ..initialize().then((_) {
          setState(() {
            _previewName = name;
            _videoPlayerController!.play();
            _videoPlayerController!.setLooping(true);
          });
        });
    }
  }

  void _uploadVideos() async {
  if (_videoService.videos.isEmpty) return;

  final dio = Dio();
  final totalVideos = _videoService.videos.length;
  double overallProgress = 0;

  // Build single FormData for all videos
  final formData = FormData();
  for (var video in _videoService.videos) {
    if (kIsWeb && video.bytes != null) {
      formData.files.add(MapEntry(
        'file',
        MultipartFile.fromBytes(video.bytes!, filename: video.name),
      ));
    } else if (video.path != null && File(video.path!).existsSync()) {
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(video.path!, filename: video.name),
      ));
    } else {
      print("⚠️ Skipping ${video.name}: no valid file found");
    }
  }

  if (formData.files.isEmpty) return;

  try {
    final response = await dio.post(
      'http://localhost:3000/api/videos/upload',
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
      onSendProgress: (sent, total) {
        setState(() {
          overallProgress = total > 0 ? sent / total : 0;
          _progress = overallProgress;
        });
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;

      for (var video in _videoService.videos) {
        video.clipPath = data['original']?[0] ?? video.path;
        video.reelPath = data['highlight'] ?? video.path;

        if (kIsWeb) {
          video.clipBytes = await _fetchBytesSafe(dio, video.clipPath!);
          video.reelBytes = await _fetchBytesSafe(dio, video.reelPath!);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("All videos uploaded successfully!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: ${response.statusCode}")),
      );
    }
  } catch (e) {
    print("🚨 Error uploading videos: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error uploading videos: $e")),
    );
  } finally {
    setState(() => _progress = 0);
  }
}

/// Helper for web: fetch bytes safely
Future<Uint8List?> _fetchBytesSafe(Dio dio, String url) async {
  if (url.isEmpty) return null;
  try {
    final resp = await dio.get<List<int>>(url,
        options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(resp.data!);
  } catch (e) {
    print("⚠️ Failed to fetch bytes for $url: $e");
    return null;
  }
}



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Video"),
        backgroundColor: Colors.amberAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    backgroundColor: Colors.deepPurpleAccent,
  ),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayfulVideoPage()),
    );
  },
  icon: const Icon(Icons.movie_creation),
  label: const Text("Go to Playful Video Generator"),
),
const SizedBox(height: 16),

            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.amberAccent,
              ),
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library),
              label: const Text("Pick Video"),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_videoPlayerController != null &&
                        _videoPlayerController!.value.isInitialized)
                      Column(
                        children: [
                          Text(
                            "Preview: $_previewName",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio:
                                  _videoPlayerController!.value.aspectRatio,
                              child: VideoPlayer(_videoPlayerController!),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    Column(
                      children: _videoService.videos.map((video) {
                        final outputs = <Map<String, dynamic>>[];

                        if (video.path != null)
                          outputs.add({
                            'name': 'Original',
                            'path': video.path,
                            'color': Colors.blue,
                          });
                        if (video.clipPath != null)
                          outputs.add({
                            'name': 'Clip',
                            'path': video.clipPath,
                            'color': Colors.orange,
                          });
                        if (video.reelPath != null)
                          outputs.add({
                            'name': 'Reel',
                            'path': video.reelPath,
                            'color': Colors.green,
                          });
                        if (video.resolutionPaths != null) {
                          for (var r in video.resolutionPaths!) {
                            outputs.add({
                              'name': 'Resolution ${r.split('_').last}',
                              'path': r,
                              'color': Colors.purple,
                            });
                          }
                        }
                        if (video.eventClipPaths != null &&
                            video.eventClipPaths!.isNotEmpty) {
                          for (
                            var i = 0;
                            i < video.eventClipPaths!.length;
                            i++
                          ) {
                            final clipPath = video.eventClipPaths![i];
                            final thumb =
                                (video.eventClipThumbs != null &&
                                    i < video.eventClipThumbs!.length)
                                ? video.eventClipThumbs![i]
                                : null;
                            final gif =
                                (video.eventClipGifs != null &&
                                    i < video.eventClipGifs!.length)
                                ? video.eventClipGifs![i]
                                : null;

                            outputs.add({
                              'name': 'Event Clip ${i + 1}',
                              'path': clipPath,
                              'thumb': thumb,
                              'gif': gif,
                              'color': Colors.redAccent,
                            });
                          }
                        } // ✅ you missed this curly brace

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ExpansionTile(
                            title: Text(
                              video.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            children: outputs.map((o) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 16,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: o['color'],
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        o['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            Icons.play_arrow,
                                            color: o['color'],
                                          ),
                                          onPressed: () => _startPreview(
                                            path: o['path'],
                                            name:
                                                "${video.name} - ${o['name']}",
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.download,
                                            color: Colors.indigo,
                                          ),
                                          onPressed: () => _downloadFile(
                                            o['path'],
                                            "${o['name']}_${video.name}",
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.amberAccent,
                      ),
                      onPressed: _uploadVideos,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text("Upload All Videos"),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Switch(
                          value: _autoPreviewLatest,
                          activeColor: Colors.orange,
                          onChanged: (val) =>
                              setState(() => _autoPreviewLatest = val),
                        ),
                        const Text("Auto-preview latest clip"),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_progress > 0)
                      Column(
                        children: [
                          const Text(
                            "Extracting events...",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              LinearProgressIndicator(
                                value: _progress,
                                minHeight: 16,
                                backgroundColor: Colors.grey[300],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.orange,
                                ),
                              ),
                              Text(
                                "${(_progress * 100).toStringAsFixed(0)}%",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_socketService.clips.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Generated Clips:",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ..._socketService.clips.asMap().entries.map((
                                  entry,
                                ) {
                                  final index = entry.key;
                                  final clipPath = entry.value;
                                  final video = _videoService.videos.last;
                                  final thumb =
                                      (video.eventClipThumbs != null &&
                                          index < video.eventClipThumbs!.length)
                                      ? video.eventClipThumbs![index]
                                      : null;
                                  final gif =
                                      (video.eventClipGifs != null &&
                                          index < video.eventClipGifs!.length)
                                      ? video.eventClipGifs![index]
                                      : null;
                                  final displayName = "Clip ${index + 1}";
                                  return Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: ListTile(
                                      leading: gif != null
                                          ? Image.network(
                                              gif,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                            )
                                          : thumb != null
                                          ? Image.network(
                                              thumb,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(
                                              Icons.movie,
                                              color: Colors.redAccent,
                                              size: 40,
                                            ),
                                      title: Text(displayName),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.play_arrow,
                                              color: Colors.green,
                                            ),
                                            onPressed: () => _startPreview(
                                              path: gif ?? clipPath,
                                              name:
                                                  "${video.name} - $displayName",
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.download,
                                              color: Colors.indigo,
                                            ),
                                            onPressed: () => _downloadFile(
                                              clipPath,
                                              "${video.name}_$displayName",
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
