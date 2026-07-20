import 'package:flutter/material.dart';

import '../models/job.dart';
import '../services/graph_repository.dart';
import '../theme/app_theme.dart';
import 'graph_canvas_screen.dart';
import 'new_job_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    this.jobs = const [],
    this.repository,
    super.key,
  });

  final List<Job> jobs;
  final GraphRepository? repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<SavedGraphSummary>> _savedGraphs = _loadGraphs();

  Future<List<SavedGraphSummary>> _loadGraphs() async {
    final repository = widget.repository;
    final saved = repository == null
        ? <SavedGraphSummary>[]
        : await repository.listGraphs();
    final savedIds = saved.map((item) => item.id).toSet();
    return [
      ...saved,
      for (final job in widget.jobs)
        if (!savedIds.contains(job.id))
          SavedGraphSummary(
            id: job.id,
            job: job,
            updatedAt: job.createdDate,
            isPersisted: false,
          ),
    ];
  }

  void _refresh() {
    setState(() {
      _savedGraphs = _loadGraphs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.red,
      appBar: AppBar(
        title: const Text('BugMan Graphs'),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(4),
          child: SizedBox(
            height: 4,
            child: ColoredBox(color: AppColors.red),
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<SavedGraphSummary>>(
          future: _savedGraphs,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return widget.jobs.isEmpty
                  ? const _EmptyJobsState()
                  : const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Saved graphs could not be loaded'),
                ),
              );
            }
            final graphs = snapshot.data ?? const <SavedGraphSummary>[];
            if (graphs.isEmpty) return const _EmptyJobsState();
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: graphs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final graph = graphs[index];
                return _JobCard(
                  job: graph.job,
                  onTap: () => _openGraph(graph),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).pushNamed(NewJobScreen.routeName);
          if (mounted) _refresh();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Job'),
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.white, width: 2),
        ),
      ),
    );
  }

  Future<void> _openGraph(SavedGraphSummary summary) async {
    final repository = widget.repository;
    if (repository == null || !summary.isPersisted) {
      await Navigator.of(context).pushNamed(
        GraphCanvasScreen.routeName,
        arguments: summary.job,
      );
    } else {
      final document = await repository.loadGraph(summary.id);
      if (!mounted) return;
      if (document == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved graph could not be opened')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => GraphCanvasScreen(
            document: document,
            repository: repository,
          ),
        ),
      );
    }
    if (mounted) _refresh();
  }
}

class _EmptyJobsState extends StatelessWidget {
  const _EmptyJobsState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final horizontalPadding = isCompact ? 16.0 : 32.0;
        final logoExtent = isCompact ? 240.0 : 360.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            104,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  (constraints.maxHeight - 128).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(
                      color: AppColors.wolfGrey,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3D000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isCompact ? 24 : 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          AppAssets.hollomanLogo,
                          key: const ValueKey('holloman-logo'),
                          width: logoExtent,
                          height: logoExtent,
                          fit: BoxFit.contain,
                          semanticLabel: 'Holloman Exterminators logo',
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No jobs yet',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppColors.black,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a job to start a new structure graph.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.wolfGrey,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final address = job.serviceAddress.trim();
    final chips = <Widget>[
      if (job.pestPacLocationNumber.trim().isNotEmpty)
        _JobChip(
          icon: Icons.location_searching,
          label: 'Location # ${job.pestPacLocationNumber}',
        ),
      if (job.pestPacBillToNumber.trim().isNotEmpty)
        _JobChip(
          icon: Icons.receipt_long_outlined,
          label: 'Bill-To # ${job.pestPacBillToNumber}',
        ),
      if (job.serviceType.trim().isNotEmpty)
        _JobChip(
          icon: Icons.bug_report_outlined,
          label: job.serviceType,
        ),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.wolfGrey, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(address),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JobChip extends StatelessWidget {
  const _JobChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
