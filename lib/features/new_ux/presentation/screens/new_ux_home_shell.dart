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
          _ColoredBlank(color: Colors.red, label: 'Produced Blocks'),
          _ColoredBlank(color: Colors.green, label: 'Node Status'),
          _ColoredBlank(color: Colors.blue, label: 'Settings'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.layers_outlined),
            selectedIcon: Icon(Icons.layers),
            label: 'Produced Blocks',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Node Status',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
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


