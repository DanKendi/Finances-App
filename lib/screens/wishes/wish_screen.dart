import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../utils/providers.dart';
import '../../utils/formatters.dart';
import '../../main.dart';

class WishScreen extends ConsumerWidget {
  const WishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishesAsync = ref.watch(wishItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Desejos'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddWishSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Novo desejo'),
      ),
      body: wishesAsync.when(
        data: (wishes) {
          if (wishes.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nenhum desejo cadastrado ainda.',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final active = wishes.where((w) => !w.isAchieved).toList();
          final achieved = wishes.where((w) => w.isAchieved).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              if (active.isNotEmpty) ...[
                Text('Em andamento',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...active.map((w) => _WishCard(
                      wish: w,
                      onEdit: () => _showEditWishSheet(context, ref, w),
                      onDelete: () => _deleteWish(context, ref, w),
                      onUpdateSaved: (value) =>
                          _updateSaved(ref, w, value),
                      onAchieve: () => _toggleAchieved(ref, w),
                    )),
              ],
              if (achieved.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Conquistados 🎉',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...achieved.map((w) => _WishCard(
                      wish: w,
                      onEdit: () => _showEditWishSheet(context, ref, w),
                      onDelete: () => _deleteWish(context, ref, w),
                      onUpdateSaved: (value) =>
                          _updateSaved(ref, w, value),
                      onAchieve: () => _toggleAchieved(ref, w),
                    )),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Future<void> _showAddWishSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WishSheet(),
    );
  }

  Future<void> _showEditWishSheet(
      BuildContext context, WidgetRef ref, WishItem wish) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _WishSheet(wish: wish),
    );
  }

  Future<void> _deleteWish(
      BuildContext context, WidgetRef ref, WishItem wish) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover desejo'),
        content: Text('Deseja remover "${wish.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(databaseProvider);
      await db.wishDao.deleteWishItem(wish);
    }
  }

  Future<void> _updateSaved(
      WidgetRef ref, WishItem wish, double value) async {
    final db = ref.read(databaseProvider);
    await db.wishDao.updateWishItem(wish.copyWith(savedValue: value));
  }

  Future<void> _toggleAchieved(WidgetRef ref, WishItem wish) async {
    final db = ref.read(databaseProvider);
    await db.wishDao
        .updateWishItem(wish.copyWith(isAchieved: !wish.isAchieved));
  }
}

class _WishCard extends StatelessWidget {
  final WishItem wish;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAchieve;
  final Function(double) onUpdateSaved;

  const _WishCard({
    required this.wish,
    required this.onEdit,
    required this.onDelete,
    required this.onAchieve,
    required this.onUpdateSaved,
  });

  Color get _priorityColor {
    switch (wish.priority) {
      case 3:
        return Colors.redAccent;
      case 2:
        return Colors.orangeAccent;
      default:
        return Colors.blueAccent;
    }
  }

  String get _priorityLabel {
    switch (wish.priority) {
      case 3:
        return 'Alta';
      case 2:
        return 'Média';
      default:
        return 'Baixa';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        (wish.savedValue / wish.targetValue).clamp(0.0, 1.0);
    final remaining = wish.targetValue - wish.savedValue;
    final isAchieved = wish.isAchieved;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wish.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              decoration: isAchieved
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      if (wish.description != null)
                        Text(wish.description!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                // Badge prioridade
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _priorityLabel,
                    style: TextStyle(
                        color: _priorityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: Colors.grey),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: onEdit,
                      child: const Row(children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ]),
                    ),
                    PopupMenuItem(
                      onTap: onAchieve,
                      child: Row(children: [
                        Icon(
                          isAchieved
                              ? Icons.undo
                              : Icons.check_circle_outline,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(isAchieved
                            ? 'Desfazer conquista'
                            : 'Marcar como conquistado'),
                      ]),
                    ),
                    PopupMenuItem(
                      onTap: onDelete,
                      child: const Row(children: [
                        Icon(Icons.delete_outline,
                            size: 16, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Remover',
                            style: TextStyle(color: Colors.redAccent)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progresso
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isAchieved
                      ? Colors.greenAccent.shade700
                      : progress >= 1.0
                          ? Colors.greenAccent.shade700
                          : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatCurrency(wish.savedValue)} de ${formatCurrency(wish.targetValue)}',
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isAchieved
                        ? Colors.greenAccent.shade400
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            if (!isAchieved && remaining > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Faltam ${formatCurrency(remaining)}',
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),

            if (wish.targetDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Meta: ${DateFormat('MM/yyyy').format(wish.targetDate!)}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),

            if (!isAchieved) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showUpdateSavedDialog(context),
                  icon: const Icon(Icons.savings_outlined, size: 16),
                  label: const Text('Atualizar valor guardado'),
                  style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showUpdateSavedDialog(BuildContext context) async {
    final controller = TextEditingController(
        text: wish.savedValue.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Valor guardado'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Valor atual guardado (R\$)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
          ),
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(
                  controller.text.replaceAll(',', '.'));
              Navigator.pop(context, value);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result != null) onUpdateSaved(result);
  }
}

class _WishSheet extends ConsumerStatefulWidget {
  final WishItem? wish;
  const _WishSheet({this.wish});

  @override
  ConsumerState<_WishSheet> createState() => _WishSheetState();
}

class _WishSheetState extends ConsumerState<_WishSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetController = TextEditingController();
  int _priority = 1;
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    if (widget.wish != null) {
      final w = widget.wish!;
      _nameController.text = w.name;
      _descriptionController.text = w.description ?? '';
      _targetController.text = w.targetValue.toStringAsFixed(2);
      _priority = w.priority;
      _targetDate = w.targetDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2040),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty || _targetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha nome e valor alvo')),
      );
      return;
    }

    final targetValue =
        double.tryParse(_targetController.text.replaceAll(',', '.'));
    if (targetValue == null || targetValue <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor inválido')),
      );
      return;
    }

    final db = ref.read(databaseProvider);

    if (widget.wish != null) {
      await db.wishDao.updateWishItem(widget.wish!.copyWith(
        name: _nameController.text,
        description: Value(_descriptionController.text.isEmpty
            ? null
            : _descriptionController.text),
        targetValue: targetValue,
        priority: _priority,
        targetDate: Value(_targetDate),
      ));
    } else {
      await db.wishDao.insertWishItem(
        WishItemsCompanion.insert(
          name: _nameController.text,
          description: Value(_descriptionController.text.isEmpty
              ? null
              : _descriptionController.text),
          targetValue: targetValue,
          priority: Value(_priority),
          targetDate: Value(_targetDate),
          createdAt: DateTime.now(),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.wish != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(isEdit ? 'Editar desejo' : 'Novo desejo',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.star_outline),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _targetController,
              decoration: const InputDecoration(
                labelText: 'Valor alvo (R\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),

            // Prioridade
            Text('Prioridade',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                _PriorityChip(
                    label: 'Baixa',
                    value: 1,
                    color: Colors.blueAccent,
                    selected: _priority == 1,
                    onTap: () => setState(() => _priority = 1)),
                const SizedBox(width: 8),
                _PriorityChip(
                    label: 'Média',
                    value: 2,
                    color: Colors.orangeAccent,
                    selected: _priority == 2,
                    onTap: () => setState(() => _priority = 2)),
                const SizedBox(width: 8),
                _PriorityChip(
                    label: 'Alta',
                    value: 3,
                    color: Colors.redAccent,
                    selected: _priority == 3,
                    onTap: () => setState(() => _priority = 3)),
              ],
            ),
            const SizedBox(height: 12),

            // Data alvo
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Data alvo (opcional)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: _targetDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () =>
                              setState(() => _targetDate = null),
                        )
                      : null,
                ),
                child: Text(
                  _targetDate != null
                      ? DateFormat('MM/yyyy').format(_targetDate!)
                      : 'Sem data definida',
                  style: TextStyle(
                      color: _targetDate != null
                          ? null
                          : Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: Text(isEdit ? 'Salvar alterações' : 'Adicionar desejo'),
                style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.grey.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.grey,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}