import 'dart:io';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/resto_stats.dart';
import '../../resto_provider.dart';
import '../../services/stats_service.dart';
import '../../theme.dart';
import '../../l10n/tr.dart';
import '../../widgets/fast_ui.dart';

// Teal is the main series and the accent; a rise is green, a drop red.
const _brand = FASTPro.teal;
const _positive = FASTBrand.success;
const _negative = FASTBrand.error;

class RestoStatsScreen extends StatefulWidget {
  const RestoStatsScreen({super.key});

  @override
  State<RestoStatsScreen> createState() => _RestoStatsScreenState();
}

class _RestoStatsScreenState extends State<RestoStatsScreen> {
  final _statsService = StatsService();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<RestoProvider>();
      if (provider.stats == null && !provider.statsLoading) {
        provider.loadStats();
      }
    });
  }

  Future<void> _exportStats(int periodDays) async {
    setState(() => _exporting = true);
    final exportEmpty = tr(context, 'export_empty');
    final exportTitle = tr(context, 'export_title');
    final exportText = tr(
      context,
      'stats_range',
    ).replaceAll('{n}', '$periodDays');
    try {
      final csv = await _statsService.exportStats(periodDays: periodDays);
      if (csv.isEmpty) throw Exception(exportEmpty);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/fast-stats-$periodDays-j.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: exportTitle,
        text: exportText,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(context, 'export_fail').replaceAll('{n}', '$e')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestoProvider>();
    final stats = provider.stats;

    return ColoredBox(
      color: context.fast.bg,
      child: RefreshIndicator(
        color: _brand,
        onRefresh: provider.loadStats,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            FASTSpace.s16,
            FASTSpace.s16,
            FASTSpace.s16,
            FASTSpace.s40,
          ),
          children: [
            Text(
              tr(context, 'analytics'),
              style: FASTText.title.copyWith(color: context.fast.t1),
            ),
            const SizedBox(height: FASTSpace.s4),
            Text(
              tr(context, 'revenue_note'),
              style: FASTText.body.copyWith(color: context.fast.t2),
            ),
            const SizedBox(height: FASTSpace.s16),
            _PeriodSelector(
              selected: provider.statsPeriodDays,
              onSelected: (days) => provider.loadStats(periodDays: days),
            ),
            const SizedBox(height: FASTSpace.s12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: _exporting
                    ? null
                    : () => _exportStats(provider.statsPeriodDays),
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _brand,
                        ),
                      )
                    : const Icon(
                        Icons.download_outlined,
                        size: 18,
                        color: _brand,
                      ),
                label: Text(
                  _exporting
                      ? tr(context, 'exporting')
                      : tr(context, 'export_csv'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.fast.t1,
                  disabledForegroundColor: context.fast.t3,
                  side: BorderSide(color: context.fast.line),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: FASTSpace.s16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: FASTSpace.s24),
            if (provider.statsLoading && stats != null)
              Padding(
                padding: const EdgeInsets.only(bottom: FASTSpace.s16),
                child: LinearProgressIndicator(
                  color: _brand,
                  backgroundColor: context.fast.line,
                  minHeight: 3,
                ),
              ),
            if (provider.statsLoading && stats == null)
              const _LoadingState()
            else if (provider.statsError != null && stats == null)
              _ErrorState(
                message: provider.statsError!,
                onRetry: provider.loadStats,
              )
            else if (stats == null || stats.isEmpty)
              _EmptyState(onRetry: provider.loadStats)
            else ...[
              _OverviewSection(stats: stats),
              const SizedBox(height: FASTSpace.s40),
              _RevenueChart(stats: stats),
              const SizedBox(height: FASTSpace.s40),
              _LoyaltySection(kpis: stats.kpis),
              const SizedBox(height: FASTSpace.s40),
              _OperationsSection(stats: stats),
              const SizedBox(height: FASTSpace.s40),
              _PopularProducts(items: stats.popularItems),
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _PeriodSelector({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr(context, 'stats_period'),
      child: Wrap(
        spacing: FASTSpace.s8,
        runSpacing: FASTSpace.s8,
        children: [
          for (final days in const [7, 30, 90])
            _PeriodPill(
              label: tr(context, 'days_n').replaceAll('{n}', '$days'),
              active: days == selected,
              // Like the segmented control it replaces: tapping the
              // period already shown does nothing.
              onTap: () {
                if (days == selected) return;
                HapticFeedback.selectionClick();
                onSelected(days);
              },
            ),
        ],
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PeriodPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fast = context.fast;
    return Semantics(
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          constraints: const BoxConstraints(minWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: FASTSpace.s16),
          decoration: BoxDecoration(
            color: active ? _brand : fast.cardHigh,
            borderRadius: BorderRadius.circular(FASTRadius.pill),
            border: Border.all(color: active ? _brand : fast.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: FASTText.body.copyWith(
                  color: active ? FASTBrand.onAmber : fast.t1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewSection extends StatelessWidget {
  final RestoStats stats;

  const _OverviewSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final kpis = stats.kpis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: tr(context, 'stats_overview_t'),
          subtitle: tr(context, 'stats_overview_s'),
        ),
        const SizedBox(height: FASTSpace.s16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 4 : 2;
            final width =
                (constraints.maxWidth - (12 * (columns - 1))) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _KpiCard(
                  width: width,
                  label: tr(context, 'revenue'),
                  value: _money(kpis.revenue),
                  icon: Icons.payments_outlined,
                  delta: kpis.revenueDeltaPercent,
                ),
                _KpiCard(
                  width: width,
                  label: tr(context, 'nav_orders'),
                  value: kpis.orders.toString(),
                  icon: Icons.receipt_long_outlined,
                  delta: stats.comparison.ordersDeltaPercent,
                ),
                _KpiCard(
                  width: width,
                  label: tr(context, 'avg_basket'),
                  value: _money(kpis.averageBasket),
                  icon: Icons.shopping_bag_outlined,
                ),
                _KpiCard(
                  width: width,
                  label: tr(context, 'unique_clients'),
                  value: kpis.uniqueCustomers.toString(),
                  icon: Icons.people_alt_outlined,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RevenueChart extends StatelessWidget {
  final RestoStats stats;

  const _RevenueChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final points = stats.daily
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value.revenue))
        .toList(growable: false);
    final highest = stats.daily.fold<double>(
      0,
      (value, day) => max(value, day.revenue),
    );
    final maxY = highest <= 0 ? 10.0 : highest * 1.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: tr(context, 'ca_evo_t'),
          subtitle: tr(context, 'ca_evo_s'),
        ),
        const SizedBox(height: FASTSpace.s16),
        Semantics(
          label: tr(context, 'revenue_curve')
              .replaceAll('{n}', '${stats.periodDays}')
              .replaceAll('{m}', _money(stats.kpis.revenue)),
          image: true,
          child: _Panel(
            child: SizedBox(
              height: 260,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: max(1, points.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => context.fast.cardHigh,
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              _money(spot.y),
                              FASTText.price.copyWith(
                                color: context.fast.t1,
                                fontSize: 14,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: context.fast.line, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 54,
                        interval: maxY / 4,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            _compactMoney(value),
                            style: FASTText.caption.copyWith(
                              color: context.fast.t2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (!_showDateLabel(index, stats.daily.length)) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: Text(
                              _shortDate(stats.daily[index].date),
                              style: FASTText.caption.copyWith(
                                color: context.fast.t2,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points,
                      color: _brand,
                      barWidth: 3,
                      isCurved: points.length <= 30,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: points.length <= 7),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _brand.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoyaltySection extends StatelessWidget {
  final StatsKpis kpis;

  const _LoyaltySection({required this.kpis});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: tr(context, 'retention_t'),
          subtitle: tr(context, 'retention_s'),
        ),
        const SizedBox(height: FASTSpace.s16),
        _Panel(
          child: Wrap(
            spacing: FASTSpace.s24,
            runSpacing: FASTSpace.s24,
            children: [
              _Metric(
                label: tr(context, 'new_clients'),
                value: '${kpis.newCustomers}',
              ),
              _Metric(
                label: tr(context, 'repeat_clients'),
                value: '${kpis.recurringCustomers}',
              ),
              _Metric(
                label: tr(context, 'repurchase_rate'),
                value: _percent(kpis.repurchaseRate),
              ),
              _Metric(
                label: tr(context, 'recurring_revenue'),
                value: _money(kpis.recurringCustomerRevenue),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OperationsSection extends StatelessWidget {
  final RestoStats stats;

  const _OperationsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final kpis = stats.kpis;
    final delta = stats.comparison.cancellationRateDeltaPoints;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: tr(context, 'annulations'),
          subtitle: tr(context, 'cancelled_stat_sub'),
        ),
        const SizedBox(height: FASTSpace.s16),
        _Panel(
          child: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: _negative, size: 28),
              const SizedBox(width: FASTSpace.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${kpis.cancelledOrders} commande${kpis.cancelledOrders > 1 ? 's' : ''}',
                      style: FASTText.title.copyWith(color: context.fast.t1),
                    ),
                    const SizedBox(height: FASTSpace.s4),
                    Text(
                      '${_percent(kpis.cancellationRate)} · ${_signedPoints(delta)} ${tr(context, 'vs_prev_period')}',
                      style: FASTText.body.copyWith(color: context.fast.t2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PopularProducts extends StatelessWidget {
  final List<PopularItemStat> items;

  const _PopularProducts({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final maximum = items.first.totalSold;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          title: tr(context, 'popular_products'),
          subtitle: tr(context, 'qty_sold_sub'),
        ),
        const SizedBox(height: FASTSpace.s4),
        Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _ProductRow(
                rank: index + 1,
                item: items[index],
                maximum: maximum,
              ),
              if (index < items.length - 1)
                Divider(height: 1, color: context.fast.line),
            ],
          ],
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  final int rank;
  final PopularItemStat item;
  final int maximum;

  const _ProductRow({
    required this.rank,
    required this.item,
    required this.maximum,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rank, ${item.name}, ${item.totalSold} vendus',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: FASTSpace.s12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: FASTText.price.copyWith(
                  color: context.fast.t3,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FASTText.item.copyWith(color: context.fast.t1),
                  ),
                  const SizedBox(height: FASTSpace.s8),
                  LinearProgressIndicator(
                    value: maximum == 0 ? 0 : item.totalSold / maximum,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(FASTRadius.pill),
                    color: _brand,
                    backgroundColor: context.fast.line,
                  ),
                ],
              ),
            ),
            const SizedBox(width: FASTSpace.s16),
            Text(
              '${item.totalSold}',
              style: FASTText.price.copyWith(color: context.fast.t1),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  final double? delta;

  const _KpiCard({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final hasDelta = delta != null;
    final isPositive = (delta ?? 0) >= 0;
    final deltaColor = isPositive ? _positive : _negative;
    final deltaLabel = delta == null
        ? tr(context, 'no_ref')
        : '${isPositive ? '+' : ''}${_number(delta!)} %';

    return Semantics(
      label:
          '$label, $value${hasDelta ? ', ${tr(context, 'evolution_lbl')} $deltaLabel' : ''}',
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 164),
        padding: const EdgeInsets.all(FASTSpace.s16),
        decoration: BoxDecoration(
          color: context.fast.card,
          borderRadius: BorderRadius.circular(FASTRadius.md),
          border: Border.all(color: context.fast.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _brand, size: 22),
            const SizedBox(height: FASTSpace.s12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                maxLines: 1,
                style: FASTText.display.copyWith(color: context.fast.t1),
              ),
            ),
            const SizedBox(height: FASTSpace.s4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FASTText.caption.copyWith(color: context.fast.t2),
            ),
            if (hasDelta) ...[
              const SizedBox(height: FASTSpace.s8),
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.trending_up : Icons.trending_down,
                    size: 16,
                    color: deltaColor,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      deltaLabel,
                      style: FASTText.caption.copyWith(
                        color: deltaColor,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: FASTText.display.copyWith(color: context.fast.t1),
            ),
          ),
          const SizedBox(height: FASTSpace.s4),
          Text(label, style: FASTText.caption.copyWith(color: context.fast.t2)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FASTSpace.s16),
      decoration: BoxDecoration(
        color: context.fast.card,
        borderRadius: BorderRadius.circular(FASTRadius.md),
        border: Border.all(color: context.fast.line),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: FASTText.title.copyWith(color: context.fast.t1)),
        const SizedBox(height: FASTSpace.s4),
        Text(subtitle, style: FASTText.body.copyWith(color: context.fast.t2)),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Semantics(
          label: tr(context, 'loading_stats'),
          child: const CircularProgressIndicator(color: _brand),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.cloud_off_outlined,
      title: tr(context, 'stats_unavail'),
      message: message,
      actionLabel: tr(context, 'retry'),
      onPressed: onRetry,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      icon: Icons.query_stats_outlined,
      title: tr(context, 'no_data'),
      message: tr(context, 'no_activity'),
      actionLabel: tr(context, 'refresh'),
      onPressed: onRetry,
    );
  }
}

class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onPressed;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FastEmpty(
      icon: icon,
      accent: _brand,
      title: title,
      subtitle: message,
      action: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh, size: 18, color: _brand),
        label: Text(actionLabel),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.fast.t1,
          side: BorderSide(color: context.fast.line),
          shape: const StadiumBorder(),
          minimumSize: const Size(140, 48),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

bool _showDateLabel(int index, int count) {
  if (index < 0 || index >= count) return false;
  if (count <= 7) return true;
  final step = max(1, (count / 4).floor());
  return index == 0 || index == count - 1 || index % step == 0;
}

String _money(double value) => '${_number(value)} €';

String _compactMoney(double value) {
  if (value >= 1000) return '${_number(value / 1000)} k€';
  return '${value.round()} €';
}

String _percent(double value) => '${_number(value)} %';

String _number(double value) {
  final fixed = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
  return fixed.replaceAll('.', ',');
}

String _signedPoints(double value) =>
    '${value > 0 ? '+' : ''}${_number(value)} pt';

String _shortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
