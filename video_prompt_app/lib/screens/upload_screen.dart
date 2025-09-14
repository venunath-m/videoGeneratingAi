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
  bool _autoPreviewLatest = true; // default ON
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

  if (_progress >= 1.0 &&
      _videoService.videos.isNotEmpty &&
      _videoService.videos.last.eventClipPaths != null &&
      _videoService.videos.last.eventClipPaths!.isNotEmpty) {
    final video = _videoService.videos.last;
    final clips = video.eventClipPaths!;
    final thumbs = video.eventClipThumbs ?? [];
    final gifs = video.eventClipGifs ?? [];
    final latestIndex = clips.length - 1;

    final latestClip = clips[latestIndex];
    final latestGif = latestIndex < gifs.length ? gifs[latestIndex] : null;
    final latestThumb = latestIndex < thumbs.length ? thumbs[latestIndex] : null;

    final count = clips.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$count event clips generated!")),
    );

    // 👇 Only preview automatically if toggle is ON
    if (_autoPreviewLatest) {
      if (latestGif != null && latestGif.isNotEmpty) {
        // Preview GIF if exists
        _startPreview(path: latestGif, name: "${video.name} - GIF Clip $count");
      } else if (latestClip.isNotEmpty) {
        // Otherwise preview video clip
        _startPreview(path: latestClip, name: "${video.name} - Event Clip $count");
      } else if (latestThumb != null && latestThumb.isNotEmpty) {
        // Fallback: preview thumbnail as static image (optional)
        // You can implement _startPreviewImage(latestThumb) if needed
      }
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

  void _extractEvents() {
  if (_videoService.videos.isEmpty) return;
  final video = _videoService.videos.last;
  if ((video.path ?? "").isEmpty && (video.bytes ?? Uint8List(0)).isEmpty) return;

  setState(() {
    _progress = 0.01;
  });

  // Reset SocketService state
  _socketService.clips.clear();
  _socketService.current = 0;
  _socketService.total = 0;

  _socketService.extractEvents(video.path ?? "");
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

    // Ask for optional clip prompt
    final clipPrompt = await _askClipPrompt();
    video.clipPrompt = clipPrompt;

    // Generate preview clip (if not web)
    if (!kIsWeb && video.path != null) {
      final tempClipPath = "${Directory.systemTemp.path}/clip_preview.mp4";
      final clip = await _videoProcessor.generateClip(
        inputPath: video.path!,
        outputPath: tempClipPath,
        start: const Duration(seconds: 0),
        duration: const Duration(seconds: 10),
      );

      if (clip != null) {
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
      final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes ?? File(path).readAsBytesSync()]));
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
    final total = _videoService.videos.length;
    for (int i = 0; i < total; i++) {
      final video = _videoService.videos[i];
      await _videoService.uploadVideo(video);

      setState(() {
        _progress = (i + 1) / total;
      });
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("All videos uploaded!")));
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
            TextField(
              controller: _promptController,
              decoration: InputDecoration(
                labelText: "Enter Prompt",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.text_snippet),
              ),
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
                        if (video.eventClipPaths != null) {
                          for (
                            var i = 0;
                            i < video.eventClipPaths!.length;
                            i++
                          ) {
                            outputs.add({
                              'name': 'Event Clip ${i + 1}',
                              'path': video.eventClipPaths![i],
                              'color': Colors.redAccent,
                            });
                          }
                        }

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
                          onChanged: (val) {
                            setState(() {
                              _autoPreviewLatest = val;
                            });
                          },
                        ),
                        const Text("Auto-preview latest clip"),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ElevatedButton.icon(
                      onPressed: _extractEvents,
                      icon: const Icon(Icons.local_movies),
                      label: const Text("Extract Main Events"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_progress > 0) ...[
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

                      // 👇 Live list of event clips
                      if (_socketService.clips.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Generated Clips:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ..._socketService.clips.map((clipPath) {
                              final fileName = clipPath.split('/').last;
                              return ListTile(
                                leading: const Icon(
                                  Icons.movie,
                                  color: Colors.redAccent,
                                ),
                                title: Text(fileName),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.green,
                                  ),
                                  onPressed: () => _startPreview(
                                    path: clipPath,
                                    name: fileName,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                    ],
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
