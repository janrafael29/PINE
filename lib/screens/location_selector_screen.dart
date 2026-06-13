// Location selector dropdown (Compact 50).
library;

import 'package:flutter/material.dart';

class LocationSelectorScreen extends StatelessWidget {
  const LocationSelectorScreen({super.key});

  static const List<String> _locations = <String>[
    'Upper Klinan',
    'Cannery Site',
    'Población',
    'Polomolok',
    'AH26',
    'Silvayos',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _locations.length,
        itemBuilder: (BuildContext context, int index) {
          final String location = _locations[index];
          return ListTile(
            title: Text(location),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop<String>(context, location);
            },
          );
        },
      ),
    );
  }
}
