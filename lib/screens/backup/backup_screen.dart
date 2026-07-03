import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../utils/backup_service.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final service = BackupService(db);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exportar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.upload_file, color: Colors.greenAccent),
                        const SizedBox(width: 8),
                        Text('Exportar dados',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Salva todas as suas transações em um arquivo CSV. '
                      'Guarde em um local seguro para restaurar futuramente.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => service.exportCSV(context),
                        icon: const Icon(Icons.download),
                        label: const Text('Exportar CSV'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Importar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download_for_offline,
                            color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Text('Importar dados',
                            style: Theme.of(context).textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Restaura transações a partir de um arquivo CSV exportado anteriormente. '
                      'Duplicatas são ignoradas automaticamente.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => service.importCSV(context),
                        icon: const Icon(Icons.upload),
                        label: const Text('Importar CSV'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Tudo offline. Nenhum dado é enviado para servidores externos.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}