import 'dart:io';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';

class BackupService {
  final AppDatabase db;
  BackupService(this.db);

  Future<Directory> _getBackupDir() async {
    final base = await getExternalStorageDirectory();
    final backupDir = Directory('${base!.path}/backups');
    if (!await backupDir.exists()) await backupDir.create(recursive: true);
    return backupDir;
  }

  String _buildFolderName() {
    final now = DateTime.now();
    return 'backup_'
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> exportCSV(BuildContext context) async {
    try {
      final baseDir = await _getBackupDir();
      final folderName = _buildFolderName();
      final backupFolder = Directory('${baseDir.path}/$folderName');
      await backupFolder.create(recursive: true);

      // --- Transações ---
      final transactions = await db.transactionDao.getAllTransactions();
      final categories = await db.categoryDao.getAllCategories();
      final categoryMap = {for (final c in categories) c.id: c};

      final transactionRows = <List<dynamic>>[
        [
          'id', 'descricao', 'valor', 'data', 'tipo',
          'categoria', 'forma_pagamento', 'parcela_numero',
          'total_parcelas', 'grupo_parcela_id', 'recorrente',
        ],
      ];
      for (final t in transactions) {
        transactionRows.add([
          t.id, t.description, t.amount, t.date.toIso8601String(),
          t.isExpense ? 'gasto' : 'receita',
          categoryMap[t.categoryId]?.name ?? '',
          t.paymentMethod, t.installmentNumber ?? '',
          t.totalInstallments ?? '', t.installmentGroupId ?? '',
          t.isRecurring ? '1' : '0',
        ]);
      }
      await File('${backupFolder.path}/transactions.csv')
          .writeAsString(const ListToCsvConverter().convert(transactionRows));

      // --- Metas ---
      final budgets = await db.budgetDao.getAllBudgets();
      final budgetRows = <List<dynamic>>[
        ['id', 'categoria', 'valor', 'percentual', 'eh_percentual'],
      ];
      for (final b in budgets) {
        budgetRows.add([
          b.id,
          categoryMap[b.categoryId]?.name ?? '',
          b.value,
          b.percentage ?? '',
          b.isPercentage ? '1' : '0',
        ]);
      }
      await File('${backupFolder.path}/budgets.csv')
          .writeAsString(const ListToCsvConverter().convert(budgetRows));

      // --- Desejos ---
      final wishes = await db.wishDao.watchAllWishItems().first;
      final wishRows = <List<dynamic>>[
        [
          'id', 'nome', 'descricao', 'valor_alvo', 'valor_guardado',
          'data_alvo', 'prioridade', 'conquistado', 'criado_em',
        ],
      ];
      for (final w in wishes) {
        wishRows.add([
          w.id, w.name, w.description ?? '',
          w.targetValue, w.savedValue,
          w.targetDate?.toIso8601String() ?? '',
          w.priority, w.isAchieved ? '1' : '0',
          w.createdAt.toIso8601String(),
        ]);
      }
      await File('${backupFolder.path}/wishes.csv')
          .writeAsString(const ListToCsvConverter().convert(wishRows));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Backup completo salvo!\n'
              '${transactions.length} transações, '
              '${budgets.length} metas, '
              '${wishes.length} desejos.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao exportar: $e')),
        );
      }
    }
  }

  Future<void> importCSV(BuildContext context) async {
    try {
      final baseDir = await _getBackupDir();

      // Lista as pastas de backup ordenadas pela mais recente
      final folders = baseDir
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.split('/').last.startsWith('backup_'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));

      if (folders.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum backup encontrado.')),
          );
        }
        return;
      }

      final folder = folders.first;
      final folderName = folder.path.split('/').last;

      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Importar backup'),
            content: Text('Importar o backup:\n$folderName?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Importar'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }

      final categories = await db.categoryDao.getAllCategories();
      final categoryByName = {for (final c in categories) c.name: c};
      int importedTransactions = 0;
      int importedBudgets = 0;
      int importedWishes = 0;

      // --- Importa transações ---
      final transactionFile = File('${folder.path}/transactions.csv');
      if (await transactionFile.exists()) {
        final rows = const CsvToListConverter()
            .convert(await transactionFile.readAsString());
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.length < 7) continue;
          try {
            final originalId = int.tryParse(row[0].toString());
            final amount = double.tryParse(row[2].toString());
            final date = DateTime.tryParse(row[3].toString());
            if (amount == null || date == null) continue;

            if (originalId != null) {
              final exists =
                  await db.transactionDao.getTransactionById(originalId);
              if (exists != null) continue;
            }

            final categoryId =
                categoryByName[row[5].toString()]?.id ??
                    categories.last.id;

            await db.transactionDao.insertTransaction(
              TransactionsCompanion.insert(
                description: row[1].toString(),
                amount: amount,
                date: date,
                isExpense: Value(row[4].toString() == 'gasto'),
                categoryId: categoryId,
                paymentMethod: Value(row[6].toString()),
                installmentNumber:
                    Value(int.tryParse(row[7].toString())),
                totalInstallments:
                    Value(int.tryParse(row[8].toString())),
                installmentGroupId:
                    Value(int.tryParse(row[9].toString())),
                isRecurring: Value(row.length > 10 && row[10].toString() == '1'),
              ),
            );
            importedTransactions++;
          } catch (_) {}
        }
      }

      // --- Importa metas ---
      final budgetFile = File('${folder.path}/budgets.csv');
      if (await budgetFile.exists()) {
        final rows = const CsvToListConverter()
            .convert(await budgetFile.readAsString());
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.length < 5) continue;
          try {
            final categoryId =
                categoryByName[row[1].toString()]?.id;
            if (categoryId == null) continue;

            final existing =
                await db.budgetDao.getBudgetByCategoryId(categoryId);
            if (existing != null) continue;

            final isPercentage = row[4].toString() == '1';
            final value = double.tryParse(row[2].toString()) ?? 0;
            final percentage = double.tryParse(row[3].toString());

            await db.budgetDao.upsertBudget(
              BudgetsCompanion.insert(
                categoryId: categoryId,
                value: value,
                isPercentage: Value(isPercentage),
                percentage: Value(percentage),
              ),
            );
            importedBudgets++;
          } catch (_) {}
        }
      }

      // --- Importa desejos ---
      final wishFile = File('${folder.path}/wishes.csv');
      if (await wishFile.exists()) {
        final rows = const CsvToListConverter()
            .convert(await wishFile.readAsString());
        for (int i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.length < 8) continue;
          try {
            final targetValue = double.tryParse(row[3].toString());
            final savedValue = double.tryParse(row[4].toString());
            final createdAt = DateTime.tryParse(row[8].toString());
            if (targetValue == null || createdAt == null) continue;

            await db.wishDao.insertWishItem(
              WishItemsCompanion.insert(
                name: row[1].toString(),
                description: Value(row[2].toString().isEmpty
                    ? null
                    : row[2].toString()),
                targetValue: targetValue,
                savedValue: Value(savedValue ?? 0),
                targetDate: Value(DateTime.tryParse(row[5].toString())),
                priority: Value(int.tryParse(row[6].toString()) ?? 1),
                isAchieved:
                    Value(row[7].toString() == '1'),
                createdAt: createdAt,
              ),
            );
            importedWishes++;
          } catch (_) {}
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Importado: $importedTransactions transações, '
              '$importedBudgets metas, $importedWishes desejos.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar: $e')),
        );
      }
    }
  }
}