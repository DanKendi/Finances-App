import 'dart:io';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import '../database/daos/transaction_dao.dart';

class BackupService {
  final AppDatabase db;
  BackupService(this.db);

  Future<Directory> _getBackupDir() async {
    // Usa o diretório externo do app — não precisa de permissão
    // Fica em: /storage/emulated/0/Android/data/com.example.financesapp/files/backups
    final base = await getExternalStorageDirectory();
    final backupDir = Directory('${base!.path}/backups');
    if (!await backupDir.exists()) await backupDir.create(recursive: true);
    return backupDir;
  }

  String _buildFileName() {
    final now = DateTime.now();
    return 'financas_backup_'
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}.csv';
  }

  Future<void> exportCSV(BuildContext context) async {
    try {
      final transactions = await db.transactionDao.getAllTransactions();
      final categories = await db.categoryDao.getAllCategories();
      final categoryMap = {for (final c in categories) c.id: c};

      final rows = <List<dynamic>>[
        [
          'id', 'descricao', 'valor', 'data', 'tipo',
          'categoria', 'forma_pagamento', 'parcela_numero',
          'total_parcelas', 'grupo_parcela_id',
        ],
      ];

      for (final t in transactions) {
        final category = categoryMap[t.categoryId];
        rows.add([
          t.id, t.description, t.amount, t.date.toIso8601String(),
          t.isExpense ? 'gasto' : 'receita', category?.name ?? '',
          t.paymentMethod, t.installmentNumber ?? '',
          t.totalInstallments ?? '', t.installmentGroupId ?? '',
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await _getBackupDir();
      final fileName = _buildFileName();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Backup salvo!\nLocal: ${file.path}'),
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
      final dir = await _getBackupDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.csv'))
          .toList();

      if (files.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhum backup encontrado. Exporte primeiro.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Usa o backup mais recente
      files.sort((a, b) => b.path.compareTo(a.path));
      final file = files.first;
      final fileName = file.path.split('/').last;

      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Importar backup'),
            content: Text('Importar o arquivo:\n$fileName?'),
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

      final content = await file.readAsString();
      final rows = const CsvToListConverter().convert(content);

      if (rows.length < 2) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Arquivo vazio ou inválido')),
          );
        }
        return;
      }

      final categories = await db.categoryDao.getAllCategories();
      final categoryByName = {for (final c in categories) c.name: c};
      int imported = 0;
      int skipped = 0;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 7) continue;
        try {
          final originalId = int.tryParse(row[0].toString());
          final description = row[1].toString();
          final amount = double.tryParse(row[2].toString());
          final date = DateTime.tryParse(row[3].toString());
          final isExpense = row[4].toString() == 'gasto';
          final categoryName = row[5].toString();
          final paymentMethod = row[6].toString();
          final installmentNumber = int.tryParse(row[7].toString());
          final totalInstallments = int.tryParse(row[8].toString());
          final installmentGroupId = int.tryParse(row[9].toString());

          if (amount == null || date == null) { skipped++; continue; }

          final categoryId =
              categoryByName[categoryName]?.id ?? categories.last.id;

          if (originalId != null) {
            final exists =
                await db.transactionDao.getTransactionById(originalId);
            if (exists != null) { skipped++; continue; }
          }

          await db.transactionDao.insertTransaction(
            TransactionsCompanion.insert(
              description: description,
              amount: amount,
              date: date,
              isExpense: Value(isExpense),
              categoryId: categoryId,
              paymentMethod: Value(paymentMethod),
              installmentNumber: Value(installmentNumber),
              totalInstallments: Value(totalInstallments),
              installmentGroupId: Value(installmentGroupId),
            ),
          );
          imported++;
        } catch (_) {
          skipped++;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $imported importadas, $skipped ignoradas'),
            duration: const Duration(seconds: 4),
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