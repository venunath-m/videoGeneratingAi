import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class VideoSocketService extends ChangeNotifier {
  late IO.Socket socket;

  int current = 0;
  int total = 0;
  List<String> clips = [];

  void connect() {
    socket = IO.io("http://localhost:3000", <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) => print("Connected to server"));

    socket.on("event-progress", (data) {
      current = data['current'] ?? 0;
      total = data['total'] ?? 0;
      String clipPath = data['clipPath'] ?? '';
      if (clipPath.isNotEmpty) clips.add(clipPath);

      notifyListeners();
    });

    socket.onDisconnect((_) => print("Disconnected from server"));
  }

  void disconnect() {
    socket.disconnect();
  }

  void extractEvents(String videoPath) {
    socket.emit("extract-events", {"videoPath": videoPath});
  }

  double get progress => total == 0 ? 0 : current / total;
}
