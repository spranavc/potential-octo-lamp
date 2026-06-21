import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (email != null)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text('Signed in as'),
              subtitle: Text(email),
            ),
          if (email != null)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          if (email != null) const Divider(),
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
                  const Text('Track your climbs. Discover your style. Get better.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
