import 'package:flutter/material.dart';

import 'models/job.dart';
import 'screens/graph_canvas_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_job_screen.dart';
import 'theme/app_theme.dart';

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
      theme: buildBugManTheme(),
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
