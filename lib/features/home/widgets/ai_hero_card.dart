import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/app_provider.dart';
import '../../ai/ai_provider.dart';
import '../../ai/models/ai_planner_models.dart';
import '../../trip/providers/trip_planner_provider.dart';

class AIHeroCard extends StatefulWidget {
  const AIHeroCard({super.key});

  @override
  State<AIHeroCard> createState() => _AIHeroCardState();
}

class _AIHeroCardState extends State<AIHeroCard> {
  final TextEditingController _plannerInputCtrl = TextEditingController();

  @override
  void dispose() {
    _plannerInputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Consumer3<AIProvider, TripPlannerProvider, AppProvider>(
          builder: (context, aiProvider, tripProvider, appProvider, _) {
            final plan = aiProvider.lastResult;

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.22),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The Planner (AI)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nhập yêu cầu như "Đà Nẵng 3 ngày" để tạo lịch trình.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _plannerInputCtrl,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _generate(aiProvider),
                          decoration: InputDecoration(
                            hintText: 'Ví dụ: Đà Nẵng 3 ngày',
                            hintStyle: const TextStyle(color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.2),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: aiProvider.isLoading
                            ? null
                            : () => _generate(aiProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: colorScheme.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Tạo'),
                      ),
                    ],
                  ),
                  if (aiProvider.isLoading) ...[
                    const SizedBox(height: 12),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (aiProvider.error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      aiProvider.error!,
                      style: TextStyle(color: colorScheme.errorContainer),
                    ),
                  ],
                  if (plan != null) ...[
                    const SizedBox(height: 14),
                    _PlannerResultView(plan: plan),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: aiProvider.isLoading
                              ? null
                              : () async {
                                  await tripProvider.createTripFromAiPlan(plan);
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Đã tạo chuyến đi từ AI trong tab Chuyến đi.',
                                      ),
                                    ),
                                  );
                                  appProvider.setTab(2);
                                },
                          icon: const Icon(Icons.add_road_outlined),
                          label: const Text('Tạo chuyến đi từ AI'),
                        ),
                        TextButton(
                          onPressed: aiProvider.isLoading
                              ? null
                              : () {
                                  _plannerInputCtrl.clear();
                                  aiProvider.clearResult();
                                },
                          child: const Text(
                            'Xóa kết quả',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _generate(AIProvider aiProvider) async {
    final ok = await aiProvider.generatePlanner(_plannerInputCtrl.text);
    if (ok || !mounted || aiProvider.error == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(aiProvider.error!)));
  }
}

class _PlannerResultView extends StatelessWidget {
  const _PlannerResultView({required this.plan});

  final PlannerResult plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.destination.isEmpty ? 'Lịch trình gợi ý' : plan.destination,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          if (plan.totalDays > 0) ...[
            const SizedBox(height: 4),
            Text('Số ngày: ${plan.totalDays}'),
          ],
          const SizedBox(height: 8),
          if (plan.itinerary.isEmpty)
            const Text('AI chưa trả lịch trình theo ngày.')
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.itinerary
                  .map(
                    (day) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PlannerDayView(day: day),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _PlannerDayView extends StatelessWidget {
  const _PlannerDayView({required this.day});

  final PlannerDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day.title == null || day.title!.isEmpty
                ? 'Day ${day.day}'
                : 'Day ${day.day} - ${day.title}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (day.items.isEmpty)
            const Text('Không có hoạt động.')
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: day.items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${item.time == null ? '' : '${item.time} - '}${item.place}${item.note == null ? '' : ' (${item.note})'}',
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
