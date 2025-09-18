import 'package:flutter/material.dart';
import 'screens/upload_screen.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Prompt App',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const UploadScreen(),
    );
  }
}
