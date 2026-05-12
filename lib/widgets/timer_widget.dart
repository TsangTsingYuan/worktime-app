import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';

class TimerWidget extends StatelessWidget {
  final int workLogId;
  final ValueChanged<int> onStop;

  const TimerWidget({
    super.key,
    required this.workLogId,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimerProvider>();
    final timer = provider.getTimer(workLogId);
    if (timer == null) return const SizedBox.shrink();

    final isPaused = timer.status == TimerStatus.paused;
    final color = isPaused ? Colors.orange : Colors.blue;

    return Card(
      margin: const EdgeInsets.all(16),
      color: (isPaused ? Colors.orange.shade50 : Colors.blue.shade50),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPaused ? Icons.pause_circle : Icons.play_circle,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isPaused ? '已暂停' : '工作中',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isPaused ? Colors.orange.shade700 : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              timer.taskTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (timer.taskCategory.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(timer.taskCategory, style: const TextStyle(fontSize: 13)),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              timer.formattedTime,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: isPaused
                      ? () => provider.resume(workLogId)
                      : () => provider.pause(workLogId),
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(isPaused ? '继续' : '暂停'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () => onStop(workLogId),
                  icon: const Icon(Icons.stop, color: Colors.red),
                  label: const Text('结束', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
