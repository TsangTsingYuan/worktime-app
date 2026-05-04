import 'package:flutter/material.dart';

class SimpleBarChart extends StatelessWidget {
  final Map<String, int> data;
  final int total;

  const SimpleBarChart({super.key, required this.data, required this.total});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 36, color: Colors.grey),
              SizedBox(height: 8),
              Text('暂无数据'),
            ],
          ),
        ),
      );
    }

    final entries = data.entries.toList();
    final maxVal = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final colors = [Colors.blue, Colors.green, Colors.orange,
        Colors.purple, Colors.teal, Colors.red];

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: entries.asMap().entries.map((e) {
          final i = e.key;
          final entry = e.value;
          final ratio = maxVal > 0 ? entry.value / maxVal : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Container(
                      alignment: Alignment.topCenter,
                      child: Text(
                        '${entry.value ~/ 60}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    flex: (ratio * 100).round(),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: colors[i % colors.length],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(entry.key, style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
