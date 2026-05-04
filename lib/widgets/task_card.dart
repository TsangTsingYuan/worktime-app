import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/work_log.dart';

class TaskCard extends StatelessWidget {
  final WorkLog log;

  const TaskCard({super.key, required this.log});

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '$h小时$m分钟$s秒';
    if (m > 0) return '$m分钟$s秒';
    return '$s秒';
  }

  @override
  Widget build(BuildContext context) {
    final isOngoing = log.status == 0;
    final startTime =
        DateTime.fromMillisecondsSinceEpoch(log.startTime);
    final timeStr = DateFormat('HH:mm').format(startTime);
    final endStr = log.endTime != null
        ? DateFormat('HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(log.endTime!))
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: isOngoing ? Colors.orange : Colors.green,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(log.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOngoing
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOngoing ? Icons.hourglass_bottom : Icons.check_circle,
                              size: 13,
                              color: isOngoing ? Colors.orange.shade700 : Colors.green.shade700,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              isOngoing ? '进行中' : '已完成',
                              style: TextStyle(
                                fontSize: 11,
                                color: isOngoing ? Colors.orange.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$timeStr${endStr != null ? ' - $endStr' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      if (log.category.isNotEmpty)
                        Text(
                          log.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                            backgroundColor: Colors.blue.shade50,
                          ),
                        ),
                      const Spacer(),
                      Text(
                        _formatDuration(log.duration),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  if (log.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.notes,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
