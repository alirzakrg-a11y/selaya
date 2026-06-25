import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/localization/localized_text.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/selaya_card.dart';
import '../../../core/widgets/selaya_scaffold.dart';

class CustomReminder {
  final int id;
  final String text;
  final int hour, minute;
  final bool daily;
  const CustomReminder({
    required this.id,
    required this.text,
    required this.hour,
    required this.minute,
    required this.daily,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    't': text,
    'h': hour,
    'm': minute,
    'd': daily,
  };
  factory CustomReminder.fromJson(Map<String, dynamic> j) => CustomReminder(
    id: (j['id'] as num).toInt(),
    text: (j['t'] ?? '').toString(),
    hour: (j['h'] as num?)?.toInt() ?? 8,
    minute: (j['m'] as num?)?.toInt() ?? 0,
    daily: j['d'] != false,
  );
  String get hhmm =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Kullanıcının kendi hatırlatıcıları (zikir/dua/not) — istenen saatte, günlük
/// veya tek seferlik. Cihaza özel (senkronlanmaz); bildirim olarak planlanır.
class RemindersController extends Notifier<List<CustomReminder>> {
  static const _key = 'custom_reminders';

  @override
  List<CustomReminder> build() {
    final raw = ref.read(sharedPreferencesProvider).getString(_key);
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List)
          .map(
            (e) => CustomReminder.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist(List<CustomReminder> list) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
    state = list;
  }

  Future<void> add(String text, int hour, int minute, bool daily) async {
    final used = state.map((e) => e.id).toSet();
    var id = NotificationService.customReminderBase;
    while (used.contains(id)) {
      id++;
    }
    final r = CustomReminder(
      id: id,
      text: text,
      hour: hour,
      minute: minute,
      daily: daily,
    );
    await _persist([...state, r]);
    final notif = ref.read(notificationServiceProvider);
    await notif.requestPermission();
    await notif.scheduleCustomReminder(
      id: id,
      hour: hour,
      minute: minute,
      title: 'SELAYA',
      body: text,
      daily: daily,
    );
  }

  Future<void> remove(CustomReminder r) async {
    await ref.read(notificationServiceProvider).cancelCustomReminder(r.id);
    await _persist(state.where((e) => e.id != r.id).toList());
  }
}

final remindersProvider =
    NotifierProvider<RemindersController, List<CustomReminder>>(
      RemindersController.new,
    );

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = context.langCode == 'tr';
    final c = context.colors;
    final list = ref.watch(remindersProvider);
    return SelayaScaffold(
      title: 'xt.rdTitle'.tr(),
      showBack: true,
      actions: [
        IconButton(
          tooltip: 'xt.rdAdd'.tr(),
          icon: Icon(Icons.add_rounded, color: c.gold),
          onPressed: () => _showAdd(context, ref, tr),
        ),
      ],
      body: list.isEmpty
          ? _empty(context, ref, tr)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.sm,
                AppSpacing.base,
                AppSpacing.xxxl,
              ),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Gap.sm(),
              itemBuilder: (_, i) => _ReminderTile(
                reminder: list[i],
                onDelete: () =>
                    ref.read(remindersProvider.notifier).remove(list[i]),
                tr: tr,
              ),
            ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref, bool tr) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alarm_add_rounded, size: 60, color: c.textTertiary),
            const Gap.md(),
            Text(
              'xt.rdEmptyMessage'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, height: 1.5),
            ),
            const Gap.lg(),
            FilledButton.icon(
              onPressed: () => _showAdd(context, ref, tr),
              icon: const Icon(Icons.add_rounded),
              label: Text('xt.rdAddReminder'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: c.onGold,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAdd(BuildContext context, WidgetRef ref, bool tr) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddReminderSheet(ref: ref, tr: tr),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final CustomReminder reminder;
  final VoidCallback onDelete;
  final bool tr;
  const _ReminderTile({
    required this.reminder,
    required this.onDelete,
    required this.tr,
  });
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SelayaCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.gold.withValues(alpha: 0.14),
              borderRadius: AppRadius.rMd,
            ),
            child: Text(
              reminder.hhmm,
              style: TextStyle(
                color: c.gold,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const Gap.md(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Gap.xxs(),
                Text(
                  reminder.daily
                      ? 'xt.rdDaily'.tr()
                      : 'xt.rdOnce'.tr(),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: c.textTertiary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: c.textTertiary),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AddReminderSheet extends StatefulWidget {
  final WidgetRef ref;
  final bool tr;
  const _AddReminderSheet({required this.ref, required this.tr});
  @override
  State<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<_AddReminderSheet> {
  final _ctrl = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  bool _daily = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'xt.rdNewReminder'.tr(),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Gap.md(),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: 120,
            decoration: InputDecoration(
              hintText: 'xt.rdHint'.tr(),
              filled: true,
              fillColor: c.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: AppRadius.rLg,
                borderSide: BorderSide.none,
              ),
            ),
          ),
          // Hızlı öneriler — dokununca metni doldurur (kullanıcı düzenleyebilir).
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final p in (tr
                  ? const [
                      '100 Salavat',
                      'Sabah zikri',
                      'Akşam zikri',
                      "Kur'an oku",
                      'Estağfirullah',
                      'Tefekkür',
                    ]
                  : const [
                      '100 Salawat',
                      'Morning dhikr',
                      'Evening dhikr',
                      'Read Quran',
                      'Istighfar',
                      'Reflect',
                    ]))
                GestureDetector(
                  onTap: () => setState(() {
                    _ctrl.text = p;
                    _ctrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: p.length));
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: c.border),
                    ),
                    child: Text(p,
                        style:
                            TextStyle(color: c.textSecondary, fontSize: 13)),
                  ),
                ),
            ],
          ),
          const Gap.sm(),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (t != null) setState(() => _time = t);
                },
                icon: Icon(Icons.access_time_rounded, color: c.gold, size: 18),
                label: Text(
                  _time.format(context),
                  style: TextStyle(color: c.gold, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.gold.withValues(alpha: 0.5)),
                ),
              ),
              const Spacer(),
              Text('xt.rdDaily'.tr()),
              Switch(
                value: _daily,
                onChanged: (v) => setState(() => _daily = v),
              ),
            ],
          ),
          const Gap.sm(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final text = _ctrl.text.trim();
                if (text.isEmpty) return;
                widget.ref
                    .read(remindersProvider.notifier)
                    .add(text, _time.hour, _time.minute, _daily);
                Navigator.of(context).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: c.gold,
                foregroundColor: c.onGold,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('xt.rdAdd'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
