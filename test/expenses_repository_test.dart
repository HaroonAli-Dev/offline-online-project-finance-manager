import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/expenses/data/expenses_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late ExpensesRepository expensesRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    expensesRepository = ExpensesRepository(database, uuid);
  });

  tearDown(() => database.close());

  test(
    'creates, updates, searches, and soft-deletes expenses offline',
    () async {
      await expensesRepository.createExpense(
        expenseCode: 'EXP-101',
        expenseDate: DateTime(2026, 3, 10),
        category: 'office',
        amount: 4500.0,
        purpose: 'Printer Ink & Stationery Supplies',
        remarks: 'Purchased from Metro Stationers',
      );

      await expensesRepository.createExpense(
        expenseCode: 'EXP-102',
        expenseDate: DateTime(2026, 3, 11),
        category: 'vehicle',
        amount: 12000.0,
        purpose: 'Site Truck Diesel Tank Refill',
      );

      final expenses = await expensesRepository
          .watchExpenses(searchQuery: 'Stationery')
          .first;
      expect(expenses, hasLength(1));
      expect(expenses.single.expenseCode, 'EXP-101');
      expect(expenses.single.category, 'office');
      expect(expenses.single.amount, 4500.0);

      var vehicleExps = await expensesRepository
          .watchExpenses(categoryFilter: 'vehicle')
          .first;
      expect(vehicleExps, hasLength(1));
      expect(vehicleExps.single.expenseCode, 'EXP-102');

      await expensesRepository.updateExpense(
        id: vehicleExps.single.id,
        expenseCode: 'EXP-102-REV',
        expenseDate: DateTime(2026, 3, 11),
        category: 'vehicle',
        amount: 13500.0,
        purpose: 'Site Truck Diesel & Maintenance',
      );

      vehicleExps = await expensesRepository
          .watchExpenses(categoryFilter: 'vehicle')
          .first;
      expect(vehicleExps.single.amount, 13500.0);

      await expensesRepository.deleteExpense(vehicleExps.single.id);
      expect(
        await expensesRepository.watchExpenses(categoryFilter: 'vehicle').first,
        isEmpty,
      );
    },
  );
}
