import 'package:flutter/material.dart';

import '../../../core/widgets/section_card.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        children: [
          SectionCard(
            title: 'Performance snapshot',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Engagement is trending up this week.'),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    _MetricTile(label: 'Reach', value: '124k'),
                    SizedBox(width: 16),
                    _MetricTile(label: 'Clicks', value: '8.2k'),
                    SizedBox(width: 16),
                    _MetricTile(label: 'CTR', value: '2.4%'),
                  ],
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Next steps',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Connect accounts to pull live analytics.'),
                SizedBox(height: 8),
                Text('Schedule A/B copy tests for the weekend.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
