import 'package:flutter/material.dart';

class TimerWidget extends StatelessWidget {
  final String title;
  final String category;
  final String formattedTime;
  final bool isPaused;
  final VoidCallback onPause;
  final VoidCallback onStop;

  const TimerWidget({
    super.key,
    required this.title,
    required this.category,
    required this.formattedTime,
    required this.isPaused,
    required this.onPause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: isPaused ? Colors.orange.shade50 : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPaused ? Icons.pause_circle : Icons.play_circle,
                  color: isPaused ? Colors.orange : Colors.blue,
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
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (category.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(category, style: const TextStyle(fontSize: 13)),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              formattedTime,
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
                  onPressed: onPause,
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(isPaused ? '继续' : '暂停'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: onStop,
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
