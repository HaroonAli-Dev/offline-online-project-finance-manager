import 'package:flutter/material.dart';

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
    return MaterialApp(
      title: 'Finance & Construction Manager',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
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
                        onDestinationSelected: (index) =>
                            setState(() => _currentIndex = index),
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

        return Scaffold(
          body: _pages[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'People',
              ),
              NavigationDestination(
                icon: Icon(Icons.location_city_outlined),
                selectedIcon: Icon(Icons.location_city),
                label: 'Sites',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: 'Schemes',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Transactions',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Expenses',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_bus_outlined),
                selectedIcon: Icon(Icons.directions_bus),
                label: 'Vehicles',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_outlined),
                selectedIcon: Icon(Icons.receipt),
                label: 'Bills',
              ),
              NavigationDestination(
                icon: Icon(Icons.track_changes_outlined),
                selectedIcon: Icon(Icons.track_changes),
                label: 'Progress',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_outlined),
                selectedIcon: Icon(Icons.notifications),
                label: 'Reminders',
              ),
            ],
          ),
        );
      },
    );
  }
}
