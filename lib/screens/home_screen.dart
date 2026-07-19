import 'package:flutter/material.dart';

import '../models/job.dart';
import '../theme/app_theme.dart';
import 'graph_canvas_screen.dart';
import 'new_job_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.jobs,
    super.key,
  });

  final List<Job> jobs;

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
        child: jobs.isEmpty
            ? const _EmptyJobsState()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: jobs.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final job = jobs[index];

                  return _JobCard(job: job);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed(NewJobScreen.routeName);
        },
        icon: const Icon(Icons.add),
        label: const Text('New Job'),
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.white, width: 2),
        ),
      ),
    );
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
  const _JobCard({required this.job});

  final Job job;

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
        onTap: () {
          Navigator.of(context).pushNamed(
            GraphCanvasScreen.routeName,
            arguments: job,
          );
        },
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
