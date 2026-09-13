import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/hint_preferences_provider.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/bills/presentation/bills_page.dart';
import '../features/expenses/presentation/expenses_page.dart';
import '../features/people/presentation/people_page.dart';
import '../features/schemes/presentation/schemes_page.dart';
import '../features/sites/presentation/sites_page.dart';
import '../features/transactions/presentation/transactions_page.dart';
import '../features/progress/presentation/progress_page.dart';
import '../features/reminders/presentation/reminders_page.dart';
import '../features/vehicles/presentation/vehicles_page.dart';

const appLogoAsset = 'lib/assests/logo_svg.svg';
const appLogoPngAsset = 'lib/assests/logo_256.png';

final appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
  useMaterial3: true,
);

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Offline Project Finance Management App',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        home: const MainNavigationShell(),
      ),
    );
  }
}

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    DashboardPage(),
    PeoplePage(),
    SitesPage(),
    SchemesPage(),
    TransactionsPage(),
    ExpensesPage(),
    VehiclesPage(),
    BillsPage(),
    ProgressPage(),
    RemindersPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                _WindowsSidebar(
                  currentIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                    ref.read(hintPreferencesProvider.notifier).clearAll();
                  },
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _pages[_currentIndex]),
              ],
            ),
          );
        }

        // Responsive bottom navigation with two rows for narrow screens
        const row1Destinations = [
          (0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
          (1, Icons.people_outline, Icons.people, 'People'),
          (2, Icons.location_city_outlined, Icons.location_city, 'Sites'),
          (3, Icons.assignment_outlined, Icons.assignment, 'Schemes'),
          (
            4,
            Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet,
            'Transactions',
          ),
        ];
        const row2Destinations = [
          (5, Icons.receipt_long_outlined, Icons.receipt_long, 'Expenses'),
          (6, Icons.directions_bus_outlined, Icons.directions_bus, 'Vehicles'),
          (7, Icons.receipt_outlined, Icons.receipt, 'Bills'),
          (8, Icons.track_changes_outlined, Icons.track_changes, 'Progress'),
          (9, Icons.notifications_outlined, Icons.notifications, 'Reminders'),
        ];

        Widget buildNavigationRow(
          List<(int, IconData, IconData, String)> items,
        ) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: items.map((item) {
              final index = item.$1;
              final icon = item.$2;
              final selectedIcon = item.$3;
              final label = item.$4;
              final isSelected = _currentIndex == index;
              final colorScheme = Theme.of(context).colorScheme;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _currentIndex = index);
                    ref.read(hintPreferencesProvider.notifier).clearAll();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isSelected ? selectedIcon : icon,
                            size: 22,
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }

        return Scaffold(
          body: _pages[_currentIndex],
          bottomNavigationBar: SafeArea(
            child: Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildNavigationRow(row1Destinations),
                  const Divider(height: 1, thickness: 0.5),
                  buildNavigationRow(row2Destinations),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Windows Sidebar — 2-column grid, Dashboard centered alone at top
// ---------------------------------------------------------------------------

class _WindowsSidebar extends StatelessWidget {
  const _WindowsSidebar({
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = [
    (0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    (1, Icons.people_outline, Icons.people, 'People'),
    (2, Icons.location_city_outlined, Icons.location_city, 'Sites'),
    (3, Icons.assignment_outlined, Icons.assignment, 'Schemes'),
    (
      4,
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
      'Transactions',
    ),
    (5, Icons.receipt_long_outlined, Icons.receipt_long, 'Expenses'),
    (6, Icons.directions_bus_outlined, Icons.directions_bus, 'Vehicles'),
    (7, Icons.receipt_outlined, Icons.receipt, 'Bills'),
    (8, Icons.track_changes_outlined, Icons.track_changes, 'Progress'),
    (9, Icons.notifications_outlined, Icons.notifications, 'Reminders'),
  ];

  // Dashboard alone (index 0), then pairs, Reminders alone at end
  static const _rows = [
    [0], // Dashboard — centered alone
    [1, 2], // People | Sites
    [3, 4], // Schemes | Transactions
    [5, 6], // Expenses | Vehicles
    [7, 8], // Bills | Progress
    [9], // Reminders — alone
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 160,
      color: colorScheme.surfaceContainer,
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Image.asset(appLogoPngAsset, width: 36, height: 36),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _rows.map((row) {
                  final isSingle = row.length == 1;
                  final d0 = _destinations[row[0]];

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: isSingle
                          ? _SidebarButton(
                              index: d0.$1,
                              icon: d0.$2,
                              selectedIcon: d0.$3,
                              label: d0.$4,
                              isSelected: currentIndex == d0.$1,
                              onTap: onDestinationSelected,
                              isDashboard: d0.$1 == 0,
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _SidebarButton(
                                    index: d0.$1,
                                    icon: d0.$2,
                                    selectedIcon: d0.$3,
                                    label: d0.$4,
                                    isSelected: currentIndex == d0.$1,
                                    onTap: onDestinationSelected,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Builder(
                                    builder: (_) {
                                      final d1 = _destinations[row[1]];
                                      return _SidebarButton(
                                        index: d1.$1,
                                        icon: d1.$2,
                                        selectedIcon: d1.$3,
                                        label: d1.$4,
                                        isSelected: currentIndex == d1.$1,
                                        onTap: onDestinationSelected,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isDashboard = false,
  });

  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final ValueChanged<int> onTap;
  final bool isDashboard;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              size: isDashboard ? 24 : 20,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
