import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/place.dart';
import '../../search/provider/search_provider.dart';
import '../../trip/models/trip_models.dart';
import '../../trip/providers/trip_planner_provider.dart';

class AiSuggestionTab extends StatefulWidget {
  const AiSuggestionTab({super.key});

  @override
  State<AiSuggestionTab> createState() => _AiSuggestionTabState();
}

class _AiSuggestionTabState extends State<AiSuggestionTab> {
  final Map<String, bool> _likedById = <String, bool>{};
  final Map<String, int> _likeCountById = <String, int>{};
  final Map<String, List<_CommentItem>> _commentsById =
      <String, List<_CommentItem>>{};

  @override
  Widget build(BuildContext context) {
    return Consumer2<TripPlannerProvider, SearchProvider>(
      builder: (context, tripProvider, searchProvider, _) {
        final posts = _buildAiPosts(tripProvider.trips);
        _syncLocalStates(posts);

        final sortedPosts = [...posts]
          ..sort((a, b) {
            final aSaved = searchProvider.isFavorite(_favoritePlaceId(a.id));
            final bSaved = searchProvider.isFavorite(_favoritePlaceId(b.id));
            if (aSaved == bSaved) {
              return a.order.compareTo(b.order);
            }
            return aSaved ? -1 : 1;
          });

        return RefreshIndicator(
          onRefresh: () async {
            if (!mounted) {
              return;
            }
            setState(() {});
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            children: [
              if (sortedPosts.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Chua co du lieu chuyen di. Hay tao hoac luu chuyen di truoc de nhan goi y AI.',
                    ),
                  ),
                )
              else ...[
                const Text(
                  'Goi y theo chuyen di',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...sortedPosts.map(
                  (post) => _buildAiPostCard(post, searchProvider),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAiPostCard(_AiPost post, SearchProvider searchProvider) {
    final liked = _likedById[post.id] ?? false;
    final likeCount = _likeCountById[post.id] ?? 0;
    final comments = _commentsById[post.id] ?? const <_CommentItem>[];

    final favoritePlace = _toFavoritePlace(post);
    final isSaved = searchProvider.isFavorite(favoritePlace.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    post.place,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(post.category),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              post.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(post.description),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                post.imageUrl,
                width: double.infinity,
                height: 190,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 120,
                  color: Colors.black12,
                  alignment: Alignment.center,
                  child: const Text('Khong tai duoc anh'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      final current = _likedById[post.id] ?? false;
                      _likedById[post.id] = !current;
                      _likeCountById[post.id] =
                          (_likeCountById[post.id] ?? 0) + (current ? -1 : 1);
                    });
                  },
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? Colors.red : null,
                  ),
                ),
                Text('$likeCount'),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _openCommentsSheet(post),
                  icon: const Icon(Icons.mode_comment_outlined),
                ),
                Text('${comments.length}'),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    searchProvider.toggleFavorite(favoritePlace);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isSaved
                              ? 'Da bo luu "${post.place}" khoi yeu thich.'
                              : 'Da luu "${post.place}" vao Dia diem yeu thich.',
                        ),
                      ),
                    );
                  },
                  icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                  tooltip: isSaved ? 'Bo luu' : 'Luu vao yeu thich',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => _showAddToTripSheet(post),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Them vao chuyen di'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddToTripSheet(_AiPost post) async {
    final tripProvider = context.read<TripPlannerProvider>();
    if (tripProvider.trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ban chua co chuyen di de them.')),
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
    final locationCtrl = TextEditingController(text: post.title);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Them bai post vao lich trinh',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ten dia diem/hoat dong',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTripId,
                    decoration: const InputDecoration(
                      labelText: 'Chon chuyen di',
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
                      setSheetState(() {
                        selectedTripId = value;
                        selectedTrip = tripProvider.trips.firstWhere(
                          (trip) => trip.id == value,
                          orElse: () => tripProvider.trips.first,
                        );
                        selectedDate = _clampDate(
                          selectedDate,
                          selectedTrip.startDate,
                          selectedTrip.endDate,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Ngay trong lich trinh'),
                    subtitle: Text(_fmtDate(selectedDate)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: selectedDate,
                        firstDate: selectedTrip.startDate,
                        lastDate: selectedTrip.endDate,
                      );
                      if (picked == null) {
                        return;
                      }
                      setSheetState(() {
                        selectedDate = picked;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final locationName = locationCtrl.text.trim();
                        if (locationName.isEmpty) {
                          return;
                        }

                        await tripProvider.addLocation(
                          tripId: selectedTripId,
                          name: locationName,
                          day: selectedDate,
                          note: '${post.category}: ${post.description}',
                        );

                        if (!context.mounted) {
                          return;
                        }
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Da them "$locationName" vao "${selectedTrip.title}" (${_fmtDate(selectedDate)}).',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_location_alt_outlined),
                      label: const Text('Them vao chuyen di'),
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

  Future<void> _openCommentsSheet(_AiPost post) async {
    final controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final comments = _commentsById[post.id] ?? <_CommentItem>[];

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 12,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Binh luan - ${post.place}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: comments.isEmpty
                          ? const Center(child: Text('Chua co binh luan.'))
                          : ListView.separated(
                              itemCount: comments.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 8),
                              itemBuilder: (context, index) {
                                final item = comments[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item.author),
                                  subtitle: Text(item.text),
                                  trailing: Text(
                                    item.timeLabel,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'Viet binh luan...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final text = controller.text.trim();
                            if (text.isEmpty) {
                              return;
                            }

                            final now = DateTime.now();
                            final timeLabel =
                                '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

                            setState(() {
                              _commentsById[post.id] = [
                                ...comments,
                                _CommentItem(
                                  author: 'Ban',
                                  text: text,
                                  timeLabel: timeLabel,
                                ),
                              ];
                            });
                            setSheetState(() {});
                            controller.clear();
                          },
                          child: const Text('Gui'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
  }

  List<_AiPost> _buildAiPosts(List<Trip> trips) {
    final placeSeeds = <String>{};

    for (final trip in trips) {
      final title = _normalizePlace(trip.title);
      if (title.isNotEmpty) {
        placeSeeds.add(title);
      }

      for (final location in trip.locations) {
        final place = _extractPlace(location.name);
        if (place.isNotEmpty) {
          placeSeeds.add(place);
        }
      }
    }

    final places = placeSeeds.toList();
    final posts = <_AiPost>[];
    var order = 0;

    for (final place in places) {
      posts.addAll(_generatePostsForPlace(place, startOrder: order));
      order += 3;
    }

    return posts;
  }

  List<_AiPost> _generatePostsForPlace(
    String place, {
    required int startOrder,
  }) {
    final normalized = _normalizeForId(place);

    return [
      _AiPost(
        id: '${normalized}_spot',
        order: startOrder,
        place: place,
        category: 'Dia diem dep',
        title: 'Goi y diem check-in dep o $place',
        description:
            'Uu tien cac diem ngam canh trung tam, khu pho di bo va dia danh noi bat de co anh dep va de di chuyen.',
        imageUrl: _localImageFor(place: place, topic: 'landmark'),
      ),
      _AiPost(
        id: '${normalized}_food',
        order: startOrder + 1,
        place: place,
        category: 'Mon an',
        title: 'An gi khi den $place?',
        description:
            'Ban co the thu mon dac san dia phuong, cac quan dong khach ban dia va khu am thuc ve dem.',
        imageUrl: _localImageFor(place: place, topic: 'food'),
      ),
      _AiPost(
        id: '${normalized}_culture',
        order: startOrder + 2,
        place: place,
        category: 'Van hoa dia phuong',
        title: 'Kham pha van hoa dia phuong o $place',
        description:
            'Ghe cho truyen thong, bao tang, le hoi ban dia va khu dan cu lau doi de hieu ro net van hoa noi day.',
        imageUrl: _localImageFor(place: place, topic: 'culture'),
      ),
    ];
  }

  void _syncLocalStates(List<_AiPost> posts) {
    for (final post in posts) {
      _likedById.putIfAbsent(post.id, () => false);
      _likeCountById.putIfAbsent(post.id, () => 0);
      _commentsById.putIfAbsent(post.id, () => <_CommentItem>[]);
    }
  }

  String _favoritePlaceId(String postId) => 'ai_post_$postId';

  Place _toFavoritePlace(_AiPost post) {
    return Place(
      id: _favoritePlaceId(post.id),
      name: post.title,
      address: post.place,
      lat: 0,
      lng: 0,
      category: post.category,
      imageUrl: post.imageUrl,
      description: post.description,
      rating: 4.5,
      types: const ['ai-suggestion'],
    );
  }

  String _localImageFor({required String place, required String topic}) {
    final normalized = place.toLowerCase();

    if (normalized.contains('da nang')) {
      return 'assets/images/danang.jpg';
    }
    if (normalized.contains('ha noi')) {
      return topic == 'culture'
          ? 'assets/images/hoangthanhthanglong.jpg'
          : 'assets/images/sapa.jpg';
    }
    if (normalized.contains('ha long')) {
      return 'assets/images/halong.jpg';
    }
    if (normalized.contains('phu quoc')) {
      return 'assets/images/phuquoc.jpg';
    }
    if (normalized.contains('sapa')) {
      return 'assets/images/sapa.jpg';
    }
    if (normalized.contains('moc chau')) {
      return 'assets/images/mocchau.jpg';
    }
    if (normalized.contains('ninh binh')) {
      return 'assets/images/baidinh.jpg';
    }
    if (normalized.contains('sam son')) {
      return 'assets/images/samson.jpg';
    }

    if (topic == 'food') {
      return 'assets/images/samson.jpg';
    }
    if (topic == 'culture') {
      return 'assets/images/hoangthanhthanglong.jpg';
    }
    return 'assets/images/danang.jpg';
  }

  String _extractPlace(String source) {
    final cleaned = source
        .replaceAll(RegExp(r'\(.*?\)'), ' ')
        .replaceAll(RegExp(r'[0-9]+:[0-9]+'), ' ')
        .trim();

    if (cleaned.isEmpty) {
      return '';
    }

    final parts = cleaned
        .split(RegExp(r'[-,;]'))
        .map(_normalizePlace)
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return _normalizePlace(cleaned);
    }

    return parts.first;
  }

  String _normalizePlace(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[,.;:\-\s]+|[,.;:\-\s]+$'), '')
        .trim();
  }

  String _normalizeForId(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
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

class _AiPost {
  const _AiPost({
    required this.id,
    required this.order,
    required this.place,
    required this.category,
    required this.title,
    required this.description,
    required this.imageUrl,
  });

  final String id;
  final int order;
  final String place;
  final String category;
  final String title;
  final String description;
  final String imageUrl;
}

class _CommentItem {
  const _CommentItem({
    required this.author,
    required this.text,
    required this.timeLabel,
  });

  final String author;
  final String text;
  final String timeLabel;
}

