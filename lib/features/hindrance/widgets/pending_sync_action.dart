import 'package:flutter/material.dart';
import 'package:hero_app/features/hindrance/data/pending_sync_manager.dart';

class PendingSyncAction extends StatelessWidget {
  const PendingSyncAction({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: PendingSyncManager.instance.jobs,
    builder: (context, jobs, _) {
      final pending = jobs.where((job) => job.state != 'COMPLETE').length;
      return IconButton(
        tooltip: pending == 0 ? 'Pending sync' : '$pending pending sync',
        onPressed: () => _showQueue(context),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.cloud_upload_outlined),
            if (pending > 0)
              Positioned(
                right: -7,
                top: -5,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFA000),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  child: Text(
                    pending > 9 ? '9+' : '$pending',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  static Future<void> _showQueue(BuildContext context) => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ValueListenableBuilder(
        valueListenable: PendingSyncManager.instance.jobs,
        builder: (context, jobs, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending sync',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              if (jobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No pending uploads.')),
                )
              else
                SizedBox(
                  height: (jobs.length * 125.0)
                      .clamp(125.0, MediaQuery.sizeOf(context).height * .55)
                      .toDouble(),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: jobs.length,
                    separatorBuilder: (_, _) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      final percent = (job.progress * 100).round();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${job.formType} · ${_stateLabel(job.state, job.phase)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text('$percent%'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value:
                                job.state == 'SYNCING' ||
                                    job.state == 'COMPLETE'
                                ? job.progress
                                : null,
                          ),
                          const SizedBox(height: 6),
                          if (job.currentFile != null) ...[
                            Text(
                              'Current file: ${job.currentFile}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            '${_formatBytes(job.sentBytes)} of ${_formatBytes(job.totalBytes)} transferred',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (job.files.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              job.files.join('  •  '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (job.error != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              job.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (PendingSyncManager.instance.canRetry(job.id))
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () =>
                                    PendingSyncManager.instance.retry(job.id),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retry sync'),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  static String _stateLabel(String state, String phase) {
    if (state == 'COMPLETE') return 'Complete';
    if (state == 'FAILED') return 'Needs retry';
    return switch (phase.toUpperCase()) {
      'CREATING_TASK' => 'Preparing task',
      'UPLOADING' => 'Uploading media',
      'SAVING' => 'Saving response',
      'SUBMITTING' => 'Submitting response',
      'COMPLETE' => 'Complete',
      'FAILED' || 'SYNC_FAILED' => 'Needs retry',
      'QUEUED' => 'Waiting to resume',
      _ => state == 'SYNCING' ? 'Syncing' : state,
    };
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
