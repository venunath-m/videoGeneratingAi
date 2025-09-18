import 'dart:typed_data';

class VideoModel {
  final String? path; // Mobile/Desktop
  final Uint8List? bytes; // Web
  final String name;
  final String prompt;

  // Clip
  String? clipPath;
  Uint8List? clipBytes;
  String? clipPrompt;

  // Reel
  String? reelPath;
  Uint8List? reelBytes;
  String? reelPrompt;

  // YouTube-style clip
  String? youtubeClipPath;
  Uint8List? youtubeClipBytes;

  // Thumbnail & GIF
  String? thumbnailPath;
  Uint8List? thumbnailBytes;
  String? gifPath;
  Uint8List? gifBytes;

  // Resolutions
  List<String>? resolutionPaths; // server-generated resolutions
  Map<String, Uint8List>? resolutionBytes; // key = path, value = bytes (web)

  // Event Clips
  List<String>? eventClipPaths; // server-generated clips (mobile/desktop)
  Map<String, Uint8List>? eventClipBytes; // key = path, value = bytes (web)
  List<String>? eventClipThumbs;
  List<String>? eventClipGifs;

  String? shortVideoPath;       // server path
  Uint8List? shortVideoBytes;

  String? highlightTrimmedPath;
Uint8List? highlightTrimmedBytes;

  // ------------------- NEW: SHORT PROGRESS -------------------
  Map<String, double>? shortProgress; // key = short index or name, value = progress %

  final DateTime uploadedAt;

  VideoModel({
    this.path,
    this.bytes,
    required this.name,
    required this.prompt,
    this.clipPath,
    this.clipBytes,
    this.clipPrompt,
    this.reelPath,
    this.reelBytes,
    this.reelPrompt,
    this.youtubeClipPath,
    this.youtubeClipBytes,
    this.thumbnailPath,
    this.thumbnailBytes,
    this.gifPath,
    this.gifBytes,
    this.resolutionPaths,
    this.resolutionBytes,
    this.eventClipPaths,
    this.eventClipBytes,
    this.eventClipThumbs,
    this.eventClipGifs,
    this.shortVideoPath,
    this.shortVideoBytes,
    this.highlightTrimmedPath,
    this.highlightTrimmedBytes,
    this.shortProgress,      // add here
    required this.uploadedAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'prompt': prompt,
        'path': path,
        'clipPath': clipPath,
        'clipPrompt': clipPrompt,
        'reelPath': reelPath,
        'reelPrompt': reelPrompt,
        'youtubeClipPath': youtubeClipPath,
        'thumbnailPath': thumbnailPath,
        'gifPath': gifPath,
        'resolutionPaths': resolutionPaths,
        'eventClipPaths': eventClipPaths,
        'eventClipThumbs': eventClipThumbs,
        'eventClipGifs': eventClipGifs,
        'shortVideoPath': shortVideoPath,
        'shortVideoBytes': shortVideoBytes,
        'highlightTrimmedPath': highlightTrimmedPath,
        'shortProgress': shortProgress,  // include in JSON if needed
        'uploadedAt': uploadedAt.toIso8601String(),
      };
}
