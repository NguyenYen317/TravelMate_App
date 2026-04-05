import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../trip/models/trip_models.dart';
import '../../trip/providers/trip_planner_provider.dart';
import '../models/expense_item.dart';
import '../providers/expense_provider.dart';
import '../services/receipt_processing_service.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key, this.tripId});

  final String? tripId;

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  static const Map<String, String> _typeLabels = {
    'All': 'Tất cả',
    'Food': 'Ăn uống',
    'Transport': 'Di chuyển',
    'Stay': 'Lưu trú',
    'Ticket': 'Vé',
    'Shopping': 'Mua sắm',
    'Other': 'Khác',
  };

  static const Map<String, Color> _typeColors = {
    'Food': Color(0xFFEF5350),
    'Transport': Color(0xFF42A5F5),
    'Stay': Color(0xFF66BB6A),
    'Ticket': Color(0xFFFFCA28),
    'Shopping': Color(0xFFAB47BC),
    'Other': Color(0xFF8D6E63),
  };

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  final ReceiptProcessingService _receiptService = ReceiptProcessingService();

  final Set<String> _seededTripIds = <String>{};

  String _type = 'Food';
  DateTime? _expenseDate;
  bool _isScanning = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _receiptService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TripPlannerProvider, ExpenseProvider>(
      builder: (context, tripProvider, expenseProvider, _) {
        final trip = tripProvider.trips
            .where(
              (item) => item.id == (widget.tripId ?? tripProvider.activeTripId),
            )
            .firstOrNull;

        if (trip == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chi phí')),
            body: const Center(
              child: Text('Không tìm thấy chuyến đi để quản lý chi phí.'),
            ),
          );
        }

        if (!_seededTripIds.contains(trip.id)) {
          _seededTripIds.add(trip.id);
          Future.microtask(() {
            expenseProvider.seedRandomExpensesIfEmpty(
              tripId: trip.id,
              startDate: trip.startDate,
              endDate: trip.endDate,
            );
          });
        }

        final expenses = expenseProvider.filteredExpensesByTrip(trip.id);
        return Scaffold(
          appBar: AppBar(title: Text('Chi phí - ${trip.title}')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              _buildCategoryPieChartCard(expenseProvider, trip),
              const SizedBox(height: 12),
              _buildFilterCard(context, expenseProvider, trip),
              const SizedBox(height: 12),
              _buildAddExpenseCard(context, expenseProvider, trip),
              const SizedBox(height: 12),
              _buildExpenseList(context, expenseProvider, expenses, trip),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryPieChartCard(ExpenseProvider provider, Trip trip) {
    final allTripExpenses = provider.expensesByTrip(trip.id);
    if (allTripExpenses.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Chưa có dữ liệu để thống kê biểu đồ danh mục.'),
        ),
      );
    }

    final amountByType = <String, double>{};
    for (final expense in allTripExpenses) {
      final type = expense.type.trim().isEmpty ? 'Other' : expense.type;
      amountByType[type] = (amountByType[type] ?? 0) + expense.amount;
    }

    final entries = amountByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, item) => sum + item.value);

    final slices = entries
        .map(
          (entry) => _PieSlice(
            type: entry.key,
            amount: entry.value,
            ratio: total <= 0 ? 0 : entry.value / total,
            color: _colorForType(entry.key),
          ),
        )
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thống kê chi phí theo danh mục',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(220),
                      painter: _ExpensePieChartPainter(slices: slices),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Tổng',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('VND', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...slices.map(
              (slice) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: slice.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_typeLabel(slice.type))),
                    Text(
                      '${(slice.ratio * 100).toStringAsFixed(1)}% • ${slice.amount.toStringAsFixed(0)} VND',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard(
    BuildContext context,
    ExpenseProvider provider,
    Trip trip,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bộ lọc', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: provider.filterType,
                    decoration: const InputDecoration(
                      labelText: 'Loại chi phí',
                    ),
                    items: ExpenseProvider.types
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(_typeLabel(type)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        provider.setFilterType(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: _onlyDate(trip.startDate),
                      lastDate: _onlyDate(trip.endDate),
                      initialDate: _clampDate(
                        provider.filterDate ?? _effectiveExpenseDate(trip),
                        trip.startDate,
                        trip.endDate,
                      ),
                    );
                    provider.setFilterDate(picked);
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    provider.filterDate == null
                        ? 'Tất cả ngày'
                        : _fmtDate(provider.filterDate!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                provider.setFilterType('All');
                provider.setFilterDate(null);
              },
              child: const Text('Xóa bộ lọc'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddExpenseCard(
    BuildContext context,
    ExpenseProvider provider,
    Trip trip,
  ) {
    final effectiveDate = _effectiveExpenseDate(trip);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thêm chi phí',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _buildReceiptScanActions(context, trip),
            if (_isScanning) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Nội dung'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
              ],
              decoration: const InputDecoration(labelText: 'Số tiền'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Loại'),
              items: ExpenseProvider.types
                  .where((item) => item != 'All')
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(_typeLabel(item)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _type = value;
                  });
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Ghi chú'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: _onlyDate(trip.startDate),
                        lastDate: _onlyDate(trip.endDate),
                        initialDate: _clampDate(
                          effectiveDate,
                          trip.startDate,
                          trip.endDate,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _expenseDate = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.event),
                    label: Text(_fmtDate(effectiveDate)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () async {
                final title = _titleCtrl.text.trim();
                final amount = _parseAmount(_amountCtrl.text);

                if (title.isEmpty || amount == null || amount <= 0) {
                  _showSnack(context, 'Nhập đúng nội dung và số tiền > 0.');
                  return;
                }

                await provider.addExpense(
                  tripId: trip.id,
                  title: title,
                  amount: amount,
                  type: _type,
                  date: _clampDate(effectiveDate, trip.startDate, trip.endDate),
                  note: _noteCtrl.text,
                );

                _titleCtrl.clear();
                _amountCtrl.clear();
                _noteCtrl.clear();
                setState(() {
                  _expenseDate = null;
                  _type = 'Food';
                });
                _showSnack(
                  context,
                  'Da luu chi phi va cong vao tong chi phi chuyen di.',
                );
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptScanActions(
    BuildContext context,
    Trip trip,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _isScanning
              ? null
              : () => _scanReceiptFromSource(
                  context,
                  trip,
                  ImageSource.camera,
                ),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Chup hoa don'),
        ),
        OutlinedButton.icon(
          onPressed: _isScanning
              ? null
              : () => _scanReceiptFromSource(
                  context,
                  trip,
                  ImageSource.gallery,
                ),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Chọn từ thư viện'),
        ),
      ],
    );
  }

  Widget _buildExpenseList(
    BuildContext context,
    ExpenseProvider provider,
    List<ExpenseItem> expenses,
    Trip trip,
  ) {
    if (expenses.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Không có chi phí với bộ lọc hiện tại.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: expenses
              .map(
                (item) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(item.title),
                  subtitle: Text(
                    '${_typeLabel(item.type)} • ${_fmtDate(item.date)}\n${item.amount.toStringAsFixed(0)} VND${item.note == null ? '' : ' • ${item.note}'}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Sửa chi phí',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          await _showEditExpenseSheet(
                            context,
                            provider,
                            item,
                            trip,
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Xóa chi phí',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Xóa chi phí'),
                              content: const Text(
                                'Bạn có chắc muốn xóa chi phí này?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: const Text('Hủy'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                          if (shouldDelete == true) {
                            await provider.deleteExpense(item.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  String _fmtDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  double? _parseAmount(String raw) {
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      return null;
    }

    final thousandNormalized = normalized
        .replaceAll('.', '')
        .replaceAll(',', '');
    return double.tryParse(thousandNormalized);
  }

  String _typeLabel(String value) {
    return _typeLabels[value] ?? value;
  }

  Color _colorForType(String type) {
    final color = _typeColors[type];
    if (color != null) {
      return color;
    }

    const fallbackPalette = [
      Color(0xFF26A69A),
      Color(0xFF5C6BC0),
      Color(0xFFFF7043),
      Color(0xFF7E57C2),
      Color(0xFF26C6DA),
    ];
    final index = type.hashCode.abs() % fallbackPalette.length;
    return fallbackPalette[index];
  }

  DateTime _onlyDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _clampDate(DateTime value, DateTime start, DateTime end) {
    final d = _onlyDate(value);
    final min = _onlyDate(start);
    final max = _onlyDate(end);
    if (d.isBefore(min)) {
      return min;
    }
    if (d.isAfter(max)) {
      return max;
    }
    return d;
  }

  DateTime _effectiveExpenseDate(Trip trip) {
    final base = _expenseDate ?? DateTime.now();
    return _clampDate(base, trip.startDate, trip.endDate);
  }

  Future<void> _scanReceiptFromSource(
    BuildContext context,
    Trip trip,
    ImageSource source,
  ) async {
    final pickedImage = await _receiptService.pickReceiptImage(source: source);
    if (!mounted || pickedImage == null) {
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final recognized = await _receiptService.scanReceiptByPath(pickedImage.path);
      final cloudUrl = await _receiptService.uploadToCloudinary(pickedImage);

      final result = ReceiptScanResult(
        rawText: recognized.rawText,
        storeName: recognized.storeName,
        totalAmount: recognized.totalAmount,
        date: recognized.date,
        summary: recognized.summary,
        suggestedType: recognized.suggestedType,
        cloudinaryUrl: cloudUrl,
      );

      if (!mounted) {
        return;
      }

      if (result.rawText.trim().isEmpty) {
        _showSnack(
          context,
          'Khong nhan dien duoc text tren hoa don. Vui long chup lai ro hon.',
        );
        return;
      }

      _applyScannedReceiptResult(context, trip, result);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack(context, 'Quet OCR that bai. Vui long thu lai.');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _applyScannedReceiptResult(
    BuildContext context,
    Trip trip,
    ReceiptScanResult result,
  ) {
    final amount = result.totalAmount;
    if (amount != null && amount > 0) {
      _amountCtrl.text = amount.toStringAsFixed(0);
    }

    if (_titleCtrl.text.trim().isEmpty) {
      _titleCtrl.text = (result.storeName ?? result.summary ?? 'Hoa don').trim();
    }

    final noteParts = <String>[];
    if (result.summary != null && result.summary!.trim().isNotEmpty) {
      noteParts.add(result.summary!.trim());
    } else if (result.rawText.trim().isNotEmpty) {
      noteParts.add(result.rawText.trim().split('\n').take(3).join(' | '));
    }
    if (result.cloudinaryUrl != null && result.cloudinaryUrl!.isNotEmpty) {
      noteParts.add('Anh hoa don: ${result.cloudinaryUrl}');
    }

    if (noteParts.isNotEmpty && _noteCtrl.text.trim().isEmpty) {
      _noteCtrl.text = noteParts.join('\n');
    }

    final suggestedType = result.suggestedType;
    if (suggestedType != null &&
        ExpenseProvider.types.contains(suggestedType) &&
        suggestedType != 'All') {
      _type = suggestedType;
    }

    _expenseDate = _clampDate(
      result.date ?? (_expenseDate ?? DateTime.now()),
      trip.startDate,
      trip.endDate,
    );

    setState(() {});

    if (amount == null || amount <= 0) {
      _showSnack(
        context,
        'Da quet xong nhung chua tim thay Tong tien. Vui long nhap tay.',
      );
      return;
    }

    _showSnack(
      context,
      'Da dien Tong tien vao form. Kiem tra lai va bam "Luu".',
    );
  }

  Future<void> _showEditExpenseSheet(
    BuildContext context,
    ExpenseProvider provider,
    ExpenseItem item,
    Trip trip,
  ) async {
    final titleCtrl = TextEditingController(text: item.title);
    final amountCtrl = TextEditingController(
      text: item.amount.toStringAsFixed(0),
    );
    final noteCtrl = TextEditingController(text: item.note ?? '');
    var type = item.type;
    var date = item.date;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (localContext, setModalState) {
            return AlertDialog(
              title: const Text('Chỉnh sửa chi phí'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Nội dung'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]')),
                      ],
                      decoration: const InputDecoration(labelText: 'Số tiền'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Loại'),
                      items: ExpenseProvider.types
                          .where((value) => value != 'All')
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(_typeLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() {
                            type = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Ghi chú'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: localContext,
                          firstDate: _onlyDate(trip.startDate),
                          lastDate: _onlyDate(trip.endDate),
                          initialDate: _clampDate(
                            date,
                            trip.startDate,
                            trip.endDate,
                          ),
                        );
                        if (picked != null) {
                          setModalState(() {
                            date = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text(_fmtDate(date)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () async {
                    final parsedAmount = _parseAmount(amountCtrl.text);
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty ||
                        parsedAmount == null ||
                        parsedAmount <= 0) {
                      _showSnack(context, 'Nhập đúng nội dung và số tiền > 0.');
                      return;
                    }

                    await provider.updateExpense(
                      expenseId: item.id,
                      title: title,
                      amount: parsedAmount,
                      type: type,
                      date: _clampDate(date, trip.startDate, trip.endDate),
                      note: noteCtrl.text,
                    );

                    if (mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Lưu thay đổi'),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    amountCtrl.dispose();
    noteCtrl.dispose();
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

extension _IterableX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _PieSlice {
  const _PieSlice({
    required this.type,
    required this.amount,
    required this.ratio,
    required this.color,
  });

  final String type;
  final double amount;
  final double ratio;
  final Color color;
}

class _ExpensePieChartPainter extends CustomPainter {
  _ExpensePieChartPainter({required this.slices});

  final List<_PieSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius - 4);
    final paint = Paint()..style = PaintingStyle.stroke;

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.ratio * 2 * math.pi)
          .clamp(0.0, 2 * math.pi)
          .toDouble();
      paint
        ..color = slice.color
        ..strokeWidth = 36
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }

    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.46, holePaint);
  }

  @override
  bool shouldRepaint(covariant _ExpensePieChartPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}
