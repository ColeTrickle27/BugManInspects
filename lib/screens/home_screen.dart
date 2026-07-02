import 'package:flutter/material.dart';

import '../models/job.dart';
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
      appBar: AppBar(
        title: const Text('BugMan Graphs'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: jobs.isEmpty
            ? const _EmptyJobsState()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: jobs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
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
      ),
    );
  }
}

class _EmptyJobsState extends StatelessWidget {
  const _EmptyJobsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No jobs yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a job to start a new structure graph.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
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
                job.customerName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(job.serviceAddress),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _JobChip(
                    icon: Icons.numbers,
                    label: job.pestPacAccountNumber,
                  ),
                  _JobChip(
                    icon: Icons.bug_report_outlined,
                    label: job.serviceType,
                  ),
                ],
              ),
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
