import 'dart:io';

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
        final total = expenseProvider.totalByTrip(trip.id);

        return Scaffold(
          appBar: AppBar(title: Text('Chi phí - ${trip.title}')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              _buildSummaryCard(total),
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

  Widget _buildSummaryCard(double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng chi phí',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${total.toStringAsFixed(0)} VND',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
            _buildReceiptScanActions(context, provider, trip),
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
              },
              child: const Text('Thêm chi phí'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptScanActions(
    BuildContext context,
    ExpenseProvider provider,
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
                  provider,
                  trip,
                  ImageSource.camera,
                ),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Chụp từ camera'),
        ),
        OutlinedButton.icon(
          onPressed: _isScanning
              ? null
              : () => _scanReceiptFromSource(
                  context,
                  provider,
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
    ExpenseProvider provider,
    Trip trip,
    ImageSource source,
  ) async {
    final pickedImage = await _receiptService.pickReceiptImage(source: source);
    if (!mounted || pickedImage == null) {
      return;
    }

    await _showReceiptPreviewAndScan(context, provider, trip, pickedImage);
  }

  Future<void> _showReceiptPreviewAndScan(
    BuildContext context,
    ExpenseProvider provider,
    Trip trip,
    XFile pickedImage,
  ) async {
    ReceiptScanResult? scannedResult;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isProcessing = false;
        return StatefulBuilder(
          builder: (localContext, setDialogState) {
            return AlertDialog(
              title: const Text('Xem trước hóa đơn'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(pickedImage.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Kiểm tra ảnh rõ nét trước khi quét OCR.'),
                    if (isProcessing) ...[
                      const SizedBox(height: 10),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                FilledButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setDialogState(() {
                            isProcessing = true;
                          });
                          setState(() {
                            _isScanning = true;
                          });

                          try {
                            final recognized = await _receiptService
                                .scanReceiptByPath(pickedImage.path);
                            final cloudUrl = await _receiptService
                                .uploadToCloudinary(pickedImage);

                            scannedResult = ReceiptScanResult(
                              rawText: recognized.rawText,
                              storeName: recognized.storeName,
                              totalAmount: recognized.totalAmount,
                              date: recognized.date,
                              summary: recognized.summary,
                              suggestedType: recognized.suggestedType,
                              cloudinaryUrl: cloudUrl,
                            );

                            if (localContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isScanning = false;
                              });
                            }
                            if (localContext.mounted) {
                              setDialogState(() {
                                isProcessing = false;
                              });
                            }
                          }
                        },
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Bắt đầu quét'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || scannedResult == null) {
      return;
    }

    final result = scannedResult!;
    if (result.rawText.trim().isEmpty) {
      _showSnack(
        context,
        'Không nhận diện được nội dung hóa đơn. Hãy thử ảnh rõ hơn.',
      );
      return;
    }

    await _showScannedReceiptDialog(context, provider, trip, result);
  }

  Future<void> _showScannedReceiptDialog(
    BuildContext context,
    ExpenseProvider provider,
    Trip trip,
    ReceiptScanResult result,
  ) async {
    final titleCtrl = TextEditingController(
      text: (result.storeName ?? result.summary ?? 'Hóa đơn').trim(),
    );
    final amountCtrl = TextEditingController(
      text: result.totalAmount == null
          ? ''
          : result.totalAmount!.toStringAsFixed(0),
    );

    final noteBuffer = StringBuffer();
    if (result.summary != null && result.summary!.trim().isNotEmpty) {
      noteBuffer.write(result.summary!.trim());
    }
    if (result.cloudinaryUrl != null && result.cloudinaryUrl!.isNotEmpty) {
      if (noteBuffer.isNotEmpty) {
        noteBuffer.write('\n');
      }
      noteBuffer.write('Ảnh hóa đơn: ${result.cloudinaryUrl}');
    }
    final noteCtrl = TextEditingController(text: noteBuffer.toString());

    var type = result.suggestedType ?? 'Other';
    if (!ExpenseProvider.types.contains(type) || type == 'All') {
      type = 'Other';
    }
    var date = _clampDate(
      result.date ?? _effectiveExpenseDate(trip),
      trip.startDate,
      trip.endDate,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (localContext, setDialogState) {
            return AlertDialog(
              title: const Text('Thông tin hóa đơn nhận diện'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tên cửa hàng / nội dung',
                      ),
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
                      decoration: const InputDecoration(labelText: 'Tổng tiền'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'Phân loại chi phí',
                      ),
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
                          setDialogState(() {
                            type = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung hóa đơn / ghi chú',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: localContext,
                          firstDate: _onlyDate(trip.startDate),
                          lastDate: _onlyDate(trip.endDate),
                          initialDate: date,
                        );
                        if (picked != null) {
                          setDialogState(() {
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
                  child: const Text('Bỏ qua'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final amount = _parseAmount(amountCtrl.text);
                    if (title.isEmpty || amount == null || amount <= 0) {
                      _showSnack(
                        context,
                        'Kiểm tra lại tên cửa hàng/nội dung và tổng tiền.',
                      );
                      return;
                    }

                    _titleCtrl.text = title;
                    _amountCtrl.text = amount.toStringAsFixed(0);
                    _noteCtrl.text = noteCtrl.text.trim();
                    setState(() {
                      _type = type;
                      _expenseDate = date;
                    });
                    Navigator.of(dialogContext).pop();
                    _showSnack(
                      context,
                      'Đã điền dữ liệu OCR vào form. Kiểm tra và bấm "Thêm chi phí" để lưu.',
                    );
                  },
                  child: const Text('Áp dụng vào biểu mẫu'),
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
