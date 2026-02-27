import 'package:flutter/material.dart';
import 'package:widgetbook/widgetbook.dart';

import '../src/dropdown_chip.dart';
import '../src/dropdown_sheet.dart';

WidgetbookComponent dropdownSheetComponent() {
  return WidgetbookComponent(
    name: 'DropdownSheet',
    useCases: [
      WidgetbookUseCase(
        name: 'Playground',
        builder: (context) {
          final title = context.knobs.string(
            label: 'Title',
            initialValue: 'Select option',
          );

          final optionCount = context.knobs.int.slider(
            label: 'Option count',
            initialValue: 5,
            min: 2,
            max: 20,
          );

          final preSelectedIndex = context.knobs.int.slider(
            label: 'Pre-selected index',
            initialValue: 0,
            min: 0,
            max: 19,
          );

          return _DropdownSheetPlayground(
            title: title,
            optionCount: optionCount,
            preSelectedIndex:
                preSelectedIndex < optionCount ? preSelectedIndex : 0,
          );
        },
      ),
    ],
  );
}

class _DropdownSheetPlayground extends StatefulWidget {
  const _DropdownSheetPlayground({
    required this.title,
    required this.optionCount,
    required this.preSelectedIndex,
  });

  final String title;
  final int optionCount;
  final int preSelectedIndex;

  @override
  State<_DropdownSheetPlayground> createState() =>
      _DropdownSheetPlaygroundState();
}

class _DropdownSheetPlaygroundState extends State<_DropdownSheetPlayground> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.preSelectedIndex;
  }

  @override
  void didUpdateWidget(_DropdownSheetPlayground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preSelectedIndex != widget.preSelectedIndex) {
      _selectedIndex = widget.preSelectedIndex;
    }
  }

  List<String> get _labels =>
      List.generate(widget.optionCount, (i) => 'Option ${i + 1}');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownChip(
            label: _labels[_selectedIndex],
            selected: true,
            onTap: () async {
              final result = await showDropdownSheet(
                context: context,
                labels: _labels,
                title: widget.title,
                selectedIndex: _selectedIndex,
              );
              if (result != null) {
                setState(() => _selectedIndex = result);
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Selected: ${_labels[_selectedIndex]} (index $_selectedIndex)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
