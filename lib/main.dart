import 'package:flutter/material.dart';

import 'models/graph_document.dart';
import 'models/job.dart';
import 'screens/graph_canvas_screen.dart';
import 'screens/home_screen.dart';
import 'screens/new_job_screen.dart';
import 'services/bugman_portal_service_factory.dart';
import 'services/graph_repository.dart';
import 'services/graph_repository_factory.dart';
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
  late final GraphRepository _repository = createGraphRepository();
  late final _portalService = createBugManPortalService();
  late final String? _portalKey = _readPortalKey();
  late final Future<GraphDocument?>? _portalGraph =
      _portalKey == null ? null : _loadPortalGraph(_portalKey);
  final List<Job> _jobs = <Job>[];

  String? _readPortalKey() {
    final key = Uri.base.queryParameters['graph'];
    if (key == null || key.trim().isEmpty || !_portalService.isAvailable) {
      return null;
    }
    return key;
  }

  Future<GraphDocument?> _loadPortalGraph(String key) async {
    final package = await _portalService.loadGraph(key);
    await _repository.saveGraph(package.document, blobs: package.blobs);
    package.document.markClean();
    return package.document;
  }

  void _addJob(Job job) {
    setState(() => _jobs.insert(0, job));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BugMan Graphs',
      debugShowCheckedModeBanner: false,
      theme: buildBugManTheme(),
      home: _portalGraph == null
          ? HomeScreen(jobs: _jobs, repository: _repository)
          : FutureBuilder<GraphDocument?>(
              future: _portalGraph,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _PortalOpenError(message: snapshot.error.toString());
                }
                return GraphCanvasScreen(
                  document: snapshot.data!,
                  repository: _repository,
                );
              },
            ),
      routes: {
        NewJobScreen.routeName: (context) => NewJobScreen(onCreateJob: _addJob),
      },
      onGenerateRoute: (settings) {
        if (settings.name == GraphCanvasScreen.routeName) {
          final job = settings.arguments as Job;

          return MaterialPageRoute<void>(
            builder: (context) => GraphCanvasScreen(
              job: job,
              repository: _repository,
            ),
          );
        }

        return null;
      },
    );
  }
}

class _PortalOpenError extends StatelessWidget {
  const _PortalOpenError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BugMan Graphs')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text('This uploaded graph could not be opened.'),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
