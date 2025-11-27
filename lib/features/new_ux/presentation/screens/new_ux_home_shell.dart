import 'package:flutter/material.dart';

class NewUxHomeShell extends StatefulWidget {
  const NewUxHomeShell({super.key});

  @override
  State<NewUxHomeShell> createState() => _NewUxHomeShellState();
}

class _NewUxHomeShellState extends State<NewUxHomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _ColoredBlank(color: Colors.red, label: 'Tab 1'),
          _ColoredBlank(color: Colors.green, label: 'Tab 2'),
          _ColoredBlank(color: Colors.blue, label: 'Tab 3'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.looks_one), label: 'Tab 1'),
          NavigationDestination(icon: Icon(Icons.looks_two), label: 'Tab 2'),
          NavigationDestination(icon: Icon(Icons.looks_3), label: 'Tab 3'),
        ],
      ),
    );
  }
}

class _ColoredBlank extends StatelessWidget {
  const _ColoredBlank({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}


