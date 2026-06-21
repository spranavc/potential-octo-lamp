import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export Data'),
            subtitle: const Text('Export your climbing data as JSON'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete All Data', style: TextStyle(color: Colors.red)),
            subtitle: const Text('This cannot be undone'),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('ClimbApp v1.0.0'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'ClimbApp',
                applicationVersion: '1.0.0',
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Track your climbs. Discover your style. Get better.'),
                  ),
                  Text(
                    '© 2026 spranavc. MIT License.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
