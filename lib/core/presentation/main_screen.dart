import 'package:flutter/material.dart';
import 'package:opennutritracker/features/recording/presentation/recording_page.dart';

/// The fork's entry point deliberately needs no body profile.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) => const RecordingPage();
}
