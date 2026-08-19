import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_finance_management_app/src/core/database/app_database.dart';
import 'package:offline_finance_management_app/src/features/people/data/people_repository.dart';
import 'package:offline_finance_management_app/src/features/transactions/data/transactions_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase database;
  late PeopleRepository peopleRepository;
  late TransactionsRepository transactionsRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    peopleRepository = PeopleRepository(database, uuid);
    transactionsRepository = TransactionsRepository(database, uuid);
  });

  tearDown(() => database.close());

  test(
    'creates, updates, searches, and soft-deletes transactions offline',
    () async {
      await peopleRepository.createPerson(
        fullName: 'Contractor Ali',
        roleCodes: {'labour'},
      );
      final person = (await peopleRepository.watchPeople().first).single;

      await transactionsRepository.createTransaction(
        transactionCode: 'TXN-101',
        transactionDate: DateTime(2026, 3, 1),
        type: 'received',
        personId: person.id,
        amount: 50000.0,
        purpose: 'Advance Payment Received',
        paymentMethod: 'bank_transfer',
        referenceNumber: 'REF-889900',
      );

      await transactionsRepository.createTransaction(
        transactionCode: 'TXN-102',
        transactionDate: DateTime(2026, 3, 2),
        type: 'paid',
        personId: person.id,
        amount: 15000.0,
        purpose: 'Labor Wages Paid',
        paymentMethod: 'cash',
      );

      final transactions = await transactionsRepository
          .watchTransactions(searchQuery: 'Advance')
          .first;
      expect(transactions, hasLength(1));
      expect(transactions.single.transactionCode, 'TXN-101');
      expect(transactions.single.isReceived, isTrue);
      expect(transactions.single.amount, 50000.0);
      expect(transactions.single.personName, 'Contractor Ali');

      var paidTxns = await transactionsRepository
          .watchTransactions(typeFilter: 'paid')
          .first;
      expect(paidTxns, hasLength(1));
      expect(paidTxns.single.transactionCode, 'TXN-102');
      expect(paidTxns.single.isPaid, isTrue);

      await transactionsRepository.updateTransaction(
        id: paidTxns.single.id,
        transactionCode: 'TXN-102-REV',
        transactionDate: DateTime(2026, 3, 2),
        type: 'paid',
        personId: person.id,
        amount: 18000.0,
        purpose: 'Labor Wages Paid Revised',
        paymentMethod: 'cash',
      );

      paidTxns = await transactionsRepository
          .watchTransactions(typeFilter: 'paid')
          .first;
      expect(paidTxns.single.amount, 18000.0);

      await transactionsRepository.deleteTransaction(paidTxns.single.id);
      expect(
        await transactionsRepository
            .watchTransactions(typeFilter: 'paid')
            .first,
        isEmpty,
      );
    },
  );
}
