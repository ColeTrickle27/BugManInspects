import 'package:flutter/material.dart';

import 'models/job.dart';
import 'screens/graph_canvas_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_job_screen.dart';

void main() {
  runApp(const BugManGraphsApp());
}

class BugManGraphsApp extends StatefulWidget {
  const BugManGraphsApp({super.key});

  @override
  State<BugManGraphsApp> createState() => _BugManGraphsAppState();
}

class _BugManGraphsAppState extends State<BugManGraphsApp> {
  final List<Job> _jobs = <Job>[];

  void _addJob(Job job) {
    setState(() {
      _jobs.insert(0, job);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BugMan Graphs',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6F4E),
          primary: const Color(0xFF2F6F4E),
          secondary: const Color(0xFFBC8A3D),
          surface: const Color(0xFFF8F8F4),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8F4),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      routes: {
        '/': (context) => HomeScreen(jobs: _jobs),
        NewJobScreen.routeName: (context) => NewJobScreen(onCreateJob: _addJob),
      },
      onGenerateRoute: (settings) {
        if (settings.name == GraphCanvasScreen.routeName) {
          final job = settings.arguments as Job;

          return MaterialPageRoute<void>(
            builder: (context) => GraphCanvasScreen(job: job),
          );
        }

        return null;
      },
    );
  }
}
