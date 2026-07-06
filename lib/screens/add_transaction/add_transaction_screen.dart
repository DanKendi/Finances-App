import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import '../../database/app_database.dart';
import '../../utils/providers.dart';
import '../../utils/constants.dart';
import '../../main.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;
  String _paymentMethod = 'pix';
  bool _isExpense = true;

  // Parcelamento
  bool _isInstallment = false;
  int _installmentCount = 2;

  // Recorrente
  bool _isRecurring = false;
  int _recurringMonths = 12;

  final List<String> _paymentMethods = ['pix', 'débito', 'cartão', 'dinheiro'];

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedCategoryId == null) {
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione uma categoria')),
        );
      }
      return;
    }

    final db = ref.read(databaseProvider);
    final amount = double.parse(_amountController.text.replaceAll(',', '.'));

    if (_isInstallment && _isExpense) {
      await db.transactionDao.insertInstallmentPurchase(
        InstallmentPurchasesCompanion.insert(
          description: _descriptionController.text,
          totalAmount: amount,
          totalInstallments: _installmentCount,
          startDate: _selectedDate,
          categoryId: _selectedCategoryId!,
          paymentMethod: Value(_paymentMethod),
        ),
      );
    } else if (_isRecurring) {
      await db.transactionDao.insertRecurringTransaction(
        description: _descriptionController.text,
        amount: amount,
        startDate: _selectedDate,
        months: _recurringMonths,
        categoryId: _selectedCategoryId!,
        paymentMethod: _paymentMethod,
        isExpense: _isExpense,
      );
    } else {
      await db.transactionDao.insertTransaction(
        TransactionsCompanion.insert(
          description: _descriptionController.text,
          amount: amount,
          date: _selectedDate,
          isExpense: Value(_isExpense),
          categoryId: _selectedCategoryId!,
          paymentMethod: Value(_paymentMethod),
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _toggleButton(
            label: 'Gasto',
            icon: Icons.arrow_upward,
            selected: _isExpense,
            color: Colors.redAccent,
            onTap: () => setState(() {
              _isExpense = true;
              _selectedCategoryId = null;
              _isRecurring = false;
            }),
          ),
          _toggleButton(
            label: 'Receita',
            icon: Icons.arrow_downward,
            selected: !_isExpense,
            color: Colors.greenAccent.shade700,
            onTap: () => setState(() {
              _isExpense = false;
              _selectedCategoryId = null;
              _isInstallment = false;
            }),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecurringSelector() {
    return Column(
      children: [
        SwitchListTile(
          value: _isRecurring,
          onChanged: (v) => setState(() {
            _isRecurring = v;
            if (v) _isInstallment = false;
          }),
          title: Text(_isExpense ? 'Gasto fixo recorrente' : 'Receita fixa recorrente'),
          subtitle: Text(_isExpense
              ? 'Ex: aluguel, conta de energia'
              : 'Ex: salário, aluguel recebido'),
          secondary: const Icon(Icons.repeat),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        if (_isRecurring) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Repetir por'),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      if (_recurringMonths > 1) {
                        setState(() => _recurringMonths--);
                      }
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_recurringMonths ${_recurringMonths == 1 ? 'mês' : 'meses'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: () {
                      if (_recurringMonths < 36) {
                        setState(() => _recurringMonths++);
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'Vai gerar $_recurringMonths lançamentos mensais a partir de ${DateFormat('MM/yyyy').format(_selectedDate)}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInstallmentSelector() {
    return Column(
      children: [
        SwitchListTile(
          value: _isInstallment,
          onChanged: (v) => setState(() {
            _isInstallment = v;
            if (v) _isRecurring = false;
          }),
          title: const Text('Compra parcelada'),
          secondary: const Icon(Icons.credit_card),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        if (_isInstallment) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.payment, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text('Parcelas'),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      if (_installmentCount > 2) setState(() => _installmentCount--);
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_installmentCount x',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: () {
                      if (_installmentCount < 24) setState(() => _installmentCount++);
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          ),
          if (_amountController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Text(
                '$_installmentCount x de R\$ ${((double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0) / _installmentCount).toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isExpense ? 'Adicionar gasto' : 'Adicionar receita'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildToggle(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Informe a descrição' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Valor (R\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Informe o valor';
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return 'Valor inválido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Forma de pagamento',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
              ),
              items: _paymentMethods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: 16),
            categoriesAsync.when(
              data: (cats) {
                final filtered =
                    cats.where((c) => c.isExpense == _isExpense).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Categoria',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filtered.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id;
                        final color = hexToColor(cat.color);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(cat.name),
                          avatar: Icon(
                            categoryIcons[cat.icon] ?? Icons.category,
                            size: 16,
                            color: isSelected ? Colors.white : color,
                          ),
                          selectedColor: color,
                          onSelected: (_) =>
                              setState(() => _selectedCategoryId = cat.id),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Erro: $e'),
            ),
            const SizedBox(height: 16),

            // Recorrente (para gastos e receitas)
            _buildRecurringSelector(),
            const SizedBox(height: 12),

            // Parcelamento (só para gastos)
            if (_isExpense && !_isRecurring) _buildInstallmentSelector(),

            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_isExpense ? 'Salvar gasto' : 'Salvar receita'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isExpense
                    ? Colors.redAccent
                    : Colors.greenAccent.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}