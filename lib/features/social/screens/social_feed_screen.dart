import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../trip/models/trip_models.dart';
import '../../trip/providers/trip_planner_provider.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<TripPlannerProvider>(
      builder: (context, tripProvider, _) {
        final suggestions = _buildSuggestionPosts(tripProvider.trips);

        return Scaffold(
          appBar: AppBar(title: const Text('AI gợi ý')),
          body: suggestions.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Chưa có dữ liệu chuyến đi để gợi ý. Hãy tạo chuyến đi ở tab Chuyến đi trước.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return _SuggestionCard(
                      suggestion: suggestion,
                      onAddToTrip: () => _showAddToTripSheet(
                        context,
                        tripProvider,
                        suggestion,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _showAddToTripSheet(
    BuildContext context,
    TripPlannerProvider tripProvider,
    _SuggestionPost suggestion,
  ) async {
    if (tripProvider.trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chưa có chuyến đi nào để thêm.')),
      );
      return;
    }

    String selectedTripId =
        tripProvider.activeTrip?.id ?? tripProvider.trips.first.id;
    Trip selectedTrip = tripProvider.trips.firstWhere(
      (trip) => trip.id == selectedTripId,
      orElse: () => tripProvider.trips.first,
    );
    DateTime selectedDate = selectedTrip.startDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thêm "${suggestion.spotName}" vào chuyến đi',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTripId,
                    decoration: const InputDecoration(
                      labelText: 'Chọn chuyến đi',
                    ),
                    items: tripProvider.trips
                        .map(
                          (trip) => DropdownMenuItem<String>(
                            value: trip.id,
                            child: Text(
                              trip.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      final trip = tripProvider.trips.firstWhere(
                        (item) => item.id == value,
                      );
                      setStateSheet(() {
                        selectedTripId = value;
                        selectedTrip = trip;
                        selectedDate = _clampDate(
                          selectedDate,
                          selectedTrip.startDate,
                          selectedTrip.endDate,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: selectedTrip.startDate,
                        lastDate: selectedTrip.endDate,
                        initialDate: selectedDate,
                      );
                      if (picked == null) {
                        return;
                      }
                      setStateSheet(() {
                        selectedDate = picked;
                      });
                    },
                    icon: const Icon(Icons.event),
                    label: Text('Ngày: ${_fmtDate(selectedDate)}'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await tripProvider.addLocation(
                          tripId: selectedTripId,
                          name: suggestion.spotName,
                          day: selectedDate,
                          note: '${suggestion.category}: ${suggestion.title}',
                        );

                        if (!context.mounted) {
                          return;
                        }

                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã thêm ${suggestion.spotName} vào "${selectedTrip.title}" (${_fmtDate(selectedDate)}).',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Thêm vào chuyến đi'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<_SuggestionPost> _buildSuggestionPosts(List<Trip> trips) {
    final places = <String>{};

    for (final trip in trips) {
      final titleKeywords = _extractKeywords(trip.title);
      places.addAll(titleKeywords);
      for (final location in trip.locations) {
        if (location.name.trim().isNotEmpty) {
          places.add(_normalizePlace(location.name));
        }
      }
    }

    final results = <_SuggestionPost>[];
    for (final place in places) {
      final normalized = _normalizePlace(place);
      if (normalized.isEmpty) {
        continue;
      }
      results.addAll(_suggestionsForPlace(normalized));
      if (results.length >= 24) {
        break;
      }
    }

    return results;
  }

  List<String> _extractKeywords(String text) {
    final cleaned = text
        .replaceAll(
          RegExp(r'\d+\s*(ngày|ngay|đêm|dem|n\d+d\d*)', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\d+'), '')
        .trim();

    final parts = cleaned.split(RegExp(r'[,/&\-|và]+', caseSensitive: false));

    return parts.map(_normalizePlace).where((item) => item.isNotEmpty).toList();
  }

  List<_SuggestionPost> _suggestionsForPlace(String place) {
    final lower = place.toLowerCase();

    if (lower.contains('đà nẵng') || lower.contains('da nang')) {
      return const [
        _SuggestionPost(
          place: 'Đà Nẵng',
          category: 'Địa điểm đẹp',
          spotName: 'Bán đảo Sơn Trà',
          title: 'Top view đẹp ở Đà Nẵng',
          body:
              'Sơn Trà, Bà Nà Hills, biển Mỹ Khê và cầu Rồng là các điểm check-in nổi bật.',
        ),
        _SuggestionPost(
          place: 'Đà Nẵng',
          category: 'Món ăn',
          spotName: 'Khu ẩm thực Đà Nẵng',
          title: 'Ăn gì ở Đà Nẵng?',
          body:
              'Mì Quảng, bún chả cá, bánh tráng cuốn thịt heo và hải sản ven biển rất đáng thử.',
        ),
        _SuggestionPost(
          place: 'Đà Nẵng',
          category: 'Văn hóa',
          spotName: 'Chợ địa phương Đà Nẵng',
          title: 'Nhịp sống địa phương Đà Nẵng',
          body:
              'Dậy sớm dạo biển, ghé chợ địa phương và trải nghiệm nhịp sống thân thiện của người dân.',
        ),
      ];
    }

    if (lower.contains('nam định') || lower.contains('nam dinh')) {
      return const [
        _SuggestionPost(
          place: 'Nam Định',
          category: 'Địa điểm đẹp',
          spotName: 'Nhà thờ đổ Hải Lý',
          title: 'Gợi ý điểm tham quan Nam Định',
          body:
              'Nhà thờ đổ Hải Lý, biển Thịnh Long, đền Trần và các làng nghề truyền thống rất đáng ghé.',
        ),
        _SuggestionPost(
          place: 'Nam Định',
          category: 'Món ăn',
          spotName: 'Phở bò Nam Định',
          title: 'Đặc sản Nam Định nên thử',
          body:
              'Phở bò Nam Định, bánh xíu páo và các món hải sản vùng biển là những món nổi bật.',
        ),
        _SuggestionPost(
          place: 'Nam Định',
          category: 'Văn hóa',
          spotName: 'Khu lễ hội Đền Trần',
          title: 'Văn hóa lễ hội Nam Định',
          body:
              'Nam Định nổi tiếng với không gian làng quê Bắc Bộ và các lễ hội truyền thống giàu bản sắc.',
        ),
      ];
    }

    return [
      _SuggestionPost(
        place: place,
        category: 'Địa điểm đẹp',
        spotName: 'Điểm ngắm cảnh $place',
        title: 'Gợi ý cảnh đẹp tại $place',
        body:
            'Ưu tiên khu trung tâm, chợ địa phương, bờ biển/sông/hồ và các điểm cao để ngắm toàn cảnh.',
      ),
      _SuggestionPost(
        place: place,
        category: 'Món ăn',
        spotName: 'Khu ăn uống $place',
        title: 'Ăn gì khi đến $place?',
        body:
            'Hãy thử món đặc sản địa phương, quán lâu năm đông khách bản địa và khu ẩm thực buổi tối.',
      ),
      _SuggestionPost(
        place: place,
        category: 'Văn hóa',
        spotName: 'Điểm văn hóa $place',
        title: 'Trải nghiệm văn hóa tại $place',
        body:
            'Ghé chợ truyền thống, bảo tàng và khu sinh hoạt cộng đồng để hiểu nhịp sống người dân.',
      ),
    ];
  }

  String _normalizePlace(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[,.;:\-\s]+|[,.;:\-\s]+$'), '')
        .trim();
  }

  DateTime _clampDate(DateTime value, DateTime start, DateTime end) {
    if (value.isBefore(start)) {
      return start;
    }
    if (value.isAfter(end)) {
      return end;
    }
    return value;
  }

  String _fmtDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }
}

class _SuggestionPost {
  const _SuggestionPost({
    required this.place,
    required this.category,
    required this.spotName,
    required this.title,
    required this.body,
  });

  final String place;
  final String category;
  final String spotName;
  final String title;
  final String body;
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onAddToTrip});

  final _SuggestionPost suggestion;
  final VoidCallback onAddToTrip;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: color.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Gợi ý cho ${suggestion.place}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(suggestion.category),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.spotName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(suggestion.body),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onAddToTrip,
                icon: const Icon(Icons.add),
                label: const Text('Chọn vào chuyến đi'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
