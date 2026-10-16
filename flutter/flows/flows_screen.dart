// The flows menu: Sign-up × Step-up, filtered by region. Same choices as web/views/menu.ejs.
import 'package:flutter/material.dart' hide Flow;

import 'flows.dart';

const _groups = {'sign-up': 'Sign-up', 'step-up': 'Step-up'};
const _regions = {'all': 'All', 'global': 'Global', 'brazil': 'Brazil', 'mexico': 'Mexico'};

class FlowsScreen extends StatefulWidget {
  const FlowsScreen({super.key, required this.flows, required this.onPick});

  final List<Flow> flows;
  final ValueChanged<Flow> onPick;

  @override
  State<FlowsScreen> createState() => _FlowsScreenState();
}

class _FlowsScreenState extends State<FlowsScreen> {
  String group = 'sign-up';
  String region = 'all';

  @override
  Widget build(BuildContext context) {
    final shown = filterFlows(widget.flows, group, region);
    return Column(
      children: [
        DefaultTabController(
          length: _groups.length,
          child: TabBar(
            onTap: (i) => setState(() => group = _groups.keys.elementAt(i)),
            tabs: [for (final label in _groups.values) Tab(text: label)],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              for (final MapEntry(:key, :value) in _regions.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(value),
                    selected: key == region,
                    onSelected: (_) => setState(() => region = key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Padding(padding: const EdgeInsets.all(16), child: Text('No $group flows for this region.'))
              : ListView.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    title: Text(shown[i].id, style: const TextStyle(fontFamily: 'monospace')),
                    subtitle: Text('${shown[i].region} · ${shown[i].capabilities.join(' · ')}'),
                    onTap: () => widget.onPick(shown[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
