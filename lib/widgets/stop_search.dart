// lib/widgets/stop_search.dart

import 'package:flutter/material.dart';
import '../data/vizag_data.dart';
import '../utils/app_theme.dart';

class StopSearchField extends StatefulWidget {
  final String hint;
  final BusStop? value;
  final ValueChanged<BusStop> onSelected;
  final BusStop? exclude;

  const StopSearchField({
    super.key,
    required this.hint,
    required this.onSelected,
    this.value,
    this.exclude,
  });

  @override
  State<StopSearchField> createState() => _StopSearchFieldState();
}

class _StopSearchFieldState extends State<StopSearchField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<BusStop> _results = [];
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) _ctrl.text = widget.value!.name;
    _focus.addListener(() {
      if (!_focus.hasFocus) setState(() { _open = false; });
    });
  }

  @override
  void didUpdateWidget(StopSearchField old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      _ctrl.text = widget.value?.name ?? '';
    }
  }

  void _query(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _results = VizagStops.list.where((s) =>
        s.id != widget.exclude?.id &&
        (s.name.toLowerCase().contains(lower) ||
         s.nameTelugu.contains(q))
      ).take(6).toList();
      _open = q.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _focus.hasFocus
                    ? AppTheme.green.withValues(alpha: 0.5)
                    : AppTheme.border,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(
                  Icons.search,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppTheme.textMuted),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _query,
                ),
              ),
              if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    setState(() { _results = []; _open = false; });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.close, size: 14,
                        color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
        ),

        // Dropdown results
        if (_open && _results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(
              children: _results.asMap().entries.map((e) {
                final stop = e.value;
                final last = e.key == _results.length - 1;
                return GestureDetector(
                  onTap: () {
                    widget.onSelected(stop);
                    _ctrl.text = stop.name;
                    setState(() { _open = false; _results = []; });
                    _focus.unfocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      border: last
                          ? null
                          : const Border(
                              bottom: BorderSide(
                                color: AppTheme.border,
                                width: 0.5,
                              ),
                            ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stop.name,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500)),
                            Text(stop.nameTelugu,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }
}
