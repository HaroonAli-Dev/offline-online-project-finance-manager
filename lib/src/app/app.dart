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

const appLogoAsset = 'lib/assests/images/logo/logo.png';

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
        title: 'Finance & Construction Manager',
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
                SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: NavigationRail(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: (index) {
                          setState(() => _currentIndex = index);
                          ref.read(hintPreferencesProvider.notifier).clearAll();
                        },
                        labelType: NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Image.asset(
                            appLogoAsset,
                            width: 44,
                            height: 44,
                            fit: BoxFit.contain,
                          ),
                        ),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            selectedIcon: Icon(Icons.dashboard),
                            label: Text('Dashboard'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.people_outline),
                            selectedIcon: Icon(Icons.people),
                            label: Text('People'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.location_city_outlined),
                            selectedIcon: Icon(Icons.location_city),
                            label: Text('Sites'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.assignment_outlined),
                            selectedIcon: Icon(Icons.assignment),
                            label: Text('Schemes'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.account_balance_wallet_outlined),
                            selectedIcon: Icon(Icons.account_balance_wallet),
                            label: Text('Transactions'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.receipt_long_outlined),
                            selectedIcon: Icon(Icons.receipt_long),
                            label: Text('Expenses'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.directions_bus_outlined),
                            selectedIcon: Icon(Icons.directions_bus),
                            label: Text('Vehicles'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.receipt_outlined),
                            selectedIcon: Icon(Icons.receipt),
                            label: Text('Bills'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.track_changes_outlined),
                            selectedIcon: Icon(Icons.track_changes),
                            label: Text('Progress'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.notifications_outlined),
                            selectedIcon: Icon(Icons.notifications),
                            label: Text('Reminders'),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                        // Material 3-style pill indicator around the icon
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
