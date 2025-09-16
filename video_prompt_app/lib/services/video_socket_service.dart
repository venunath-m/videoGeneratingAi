import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'video_service.dart';

class VideoSocketService extends ChangeNotifier {
  late IO.Socket socket;

  int current = 0;
  int total = 0;
  List<String> clips = []; // live clip paths

  final VideoService videoService;

  VideoSocketService(this.videoService);

  void connect() {
    socket = IO.io("http://localhost:3000", <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) => print("✅ Connected to server"));

    // ✅ Event generated updates
    socket.on("event-generated", (data) {
      current = data['current'] ?? 0;
      total = data['total'] ?? 0;

      final clipPath = data['clipPath'] ?? '';
      final thumbPath = data['thumbPath'] ?? '';
      final gifPath = data['gifPath'] ?? '';

      if (clipPath.isNotEmpty && videoService.videos.isNotEmpty) {
        final video = videoService.videos.last;

        // Store clip path
        video.eventClipPaths ??= [];
        video.eventClipPaths!.add(clipPath);
        clips.add(clipPath);

        // Store thumbnail
        if (thumbPath.isNotEmpty) {
          video.eventClipThumbs ??= [];
          video.eventClipThumbs!.add(thumbPath);
        }

        // Store GIF
        if (gifPath.isNotEmpty) {
          video.eventClipGifs ??= [];
          video.eventClipGifs!.add(gifPath);
        }
      }

      notifyListeners();
    });

    // ✅ Event extraction complete
    socket.on("event-complete", (data) {
      print("✅ Event extraction complete");
      // Optionally, you can do more here:
      // e.g., notifyListeners(), update UI, or show a SnackBar
    });

    socket.onDisconnect((_) => print("❌ Disconnected from server"));
  }

  void disconnect() {
    socket.disconnect();
  }

  void extractEvents(String videoPath) {
    // Reset progress & clips
    clips.clear();
    current = 0;
    total = 0;
    notifyListeners();

    socket.emit("extract-events", {"videoPath": videoPath});
  }

  double get progress => total == 0 ? 0 : current / total;
}
