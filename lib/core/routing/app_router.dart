import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/session_log/screens/session_log_home.dart';
import '../../features/session_log/screens/active_session_screen.dart';
import '../../features/session_log/screens/session_summary_screen.dart';
import '../../features/session_log/screens/session_detail_screen.dart';
import '../../features/analytics/screens/analytics_dashboard.dart';
import '../../features/gyms/screens/gyms_list_screen.dart';
import '../../features/gyms/screens/gym_detail_screen.dart';
import '../../features/gyms/screens/gym_colors_screen.dart';
import '../../features/projects/screens/projects_list_screen.dart';
import '../../features/projects/screens/project_detail_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/gyms',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNav(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/session-log',
                name: 'session-log',
                builder: (context, state) => const SessionLogHome(),
                routes: [
                  GoRoute(
                    path: 'active',
                    name: 'session-active',
                    builder: (context, state) => const ActiveSessionScreen(),
                  ),
                  GoRoute(
                    path: 'summary',
                    name: 'session-summary',
                    builder: (context, state) => const SessionSummaryScreen(),
                  ),
                  GoRoute(
                    path: ':sessionId',
                    name: 'session-detail',
                    builder: (context, state) {
                      final sessionId = int.parse(state.pathParameters['sessionId']!);
                      return SessionDetailScreen(sessionId: sessionId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analytics',
                name: 'analytics',
                builder: (context, state) => const AnalyticsDashboard(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gyms',
                name: 'gyms',
                builder: (context, state) => const GymsListScreen(),
                routes: [
                  GoRoute(
                    path: ':gymId',
                    name: 'gym-detail',
                    builder: (context, state) {
                      final gymId = int.parse(state.pathParameters['gymId']!);
                      return GymDetailScreen(gymId: gymId);
                    },
                    routes: [
                      GoRoute(
                        path: 'colors',
                        name: 'gym-colors',
                        builder: (context, state) {
                          final gymId = int.parse(state.pathParameters['gymId']!);
                          return GymColorsScreen(gymId: gymId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/projects',
                name: 'projects',
                builder: (context, state) => const ProjectsListScreen(),
                routes: [
                  GoRoute(
                    path: ':projectId',
                    name: 'project-detail',
                    builder: (context, state) {
                      final projectId = int.parse(state.pathParameters['projectId']!);
                      return ProjectDetailScreen(projectId: projectId);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNav({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_kabaddi_outlined),
            selectedIcon: Icon(Icons.sports_kabaddi),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Gyms',
          ),
          NavigationDestination(
            icon: Icon(Icons.rocket_launch_outlined),
            selectedIcon: Icon(Icons.rocket_launch),
            label: 'Projects',
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
