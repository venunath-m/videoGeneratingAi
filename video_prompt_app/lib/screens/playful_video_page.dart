import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:video_player/video_player.dart';

class PlayfulVideoPage extends StatefulWidget {
  @override
  _PlayfulVideoPageState createState() => _PlayfulVideoPageState();
}

class _PlayfulVideoPageState extends State<PlayfulVideoPage> {
  final _controller = TextEditingController();
  String? _videoUrl;
  double _progress = 0.0;
  String _statusMessage = "";
  bool _loading = false;
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();

    // Connect to socket.io
    socket = IO.io(
      "http://localhost:3000",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    // Listen for numeric progress
    socket.on("videoProgress", (data) {
      final prog = (data["progress"] as num).toDouble();
      setState(() {
        _progress = prog;
      });
    });

    // Listen for stage messages
    socket.on("videoStage", (data) {
      setState(() {
        _statusMessage = data["stage"] ?? "";
      });
    });

    // Listen for completion
    socket.on("videoCompleted", (data) {
      setState(() {
        _loading = false;
        _videoUrl = "http://localhost:3000${data['output']}";
        _progress = 1.0;
        _statusMessage = "✅ Done!";
      });
    });
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  Future<void> _generateVideo() async {
    final dio = Dio();
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _loading = true;
      _progress = 0.0;
      _videoUrl = null;
      _statusMessage = "Starting...";
    });

    try {
      final response = await dio.post(
        "http://localhost:3000/api/videos/playful",
        data: {"prompt": prompt},
      );

      if (response.statusCode != 200) {
        throw Exception("Backend error");
      }
    } catch (e) {
      print("🚨 Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating video")),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Playful Video Generator")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Enter prompt",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: _generateVideo,
              child: Text("Generate Video"),
            ),
            if (_loading) ...[
              SizedBox(height: 12),
              LinearProgressIndicator(value: _progress),
              SizedBox(height: 8),
              Text(
                _statusMessage.isEmpty
                    ? "${(_progress * 100).toStringAsFixed(0)}%"
                    : _statusMessage,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
            if (_videoUrl != null) ...[
              SizedBox(height: 20),
              Text("Preview:"),
              SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoPlayerWidget(url: _videoUrl!),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  VideoPlayerWidget({required this.url});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? VideoPlayer(_controller)
        : Center(child: CircularProgressIndicator());
  }
}
