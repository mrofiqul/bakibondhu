import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/dialogs.dart';
import 'package:bakibondhu/core/format.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/domain/money.dart';

/// Sales report: total sales with a day/month/quarter/year breakdown, plus a
/// button to record a sale. Sales are direct amounts the owner enters (not tied
/// to a customer). Reached from the "আজকের বিক্রি" card on Home.
class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _ReportData {
  final Money total;
  final List<SalesBucket> buckets;
  const _ReportData(this.total, this.buckets);
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  SalesPeriod _period = SalesPeriod.day;
  _ReportData? _data;

  LedgerRepository get _repo => AppScope.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  Future<void> _refresh() async {
    final repo = AppScope.of(context);
    final total = await repo.totalSales();
    final buckets = await repo.salesBuckets(_period);
    if (!mounted) return;
    setState(() => _data = _ReportData(total, buckets));
  }

  void _setPeriod(SalesPeriod p) {
    setState(() => _period = p);
    _refresh();
  }

  Future<void> _addSale() async {
    final input = await showAddSaleDialog(context);
    if (input == null) return;
    await _repo.addSale(amount: input.amount, note: input.note);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.saleSaved)));
    }
    await _refresh();
  }

  static String _bucketLabel(SalesBucket b, SalesPeriod p) {
    switch (p) {
      case SalesPeriod.day:
        return dayLabel(b.start);
      case SalesPeriod.month:
        return '${bnMonth(b.start.month)} ${b.start.year}';
      case SalesPeriod.quarter:
        return '${bnMonth(b.start.month)}–${bnMonth(b.start.month + 2)} ${b.start.year}';
      case SalesPeriod.year:
        return '${b.start.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: Text(S.salesReportTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSale,
        icon: const Icon(Icons.add),
        label: Text(S.addSale),
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _TotalSalesCard(total: data.total),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SegmentedButton<SalesPeriod>(
                    segments: [
                      ButtonSegment(
                          value: SalesPeriod.day, label: Text(S.periodDaily)),
                      ButtonSegment(
                          value: SalesPeriod.month, label: Text(S.periodMonthly)),
                      ButtonSegment(
                          value: SalesPeriod.quarter,
                          label: Text(S.periodQuarterly)),
                      ButtonSegment(
                          value: SalesPeriod.year, label: Text(S.periodYearly)),
                    ],
                    selected: {_period},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => _setPeriod(s.first),
                  ),
                ),
                const SizedBox(height: 4),
                if (data.buckets.isEmpty)
                  const Expanded(child: _EmptySales())
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: data.buckets.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final b = data.buckets[i];
                        return ListTile(
                          leading: const Icon(Icons.event_note, size: 20),
                          title: Text(_bucketLabel(b, _period),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(S.salesCount(b.count)),
                          trailing: Text(b.total.format(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TotalSalesCard extends StatelessWidget {
  final Money total;
  const _TotalSalesCard({required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.totalSales,
              style: TextStyle(color: scheme.onSecondaryContainer)),
          const SizedBox(height: 6),
          Text(total.format(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: scheme.onSecondaryContainer,
              )),
        ],
      ),
    );
  }
}

class _EmptySales extends StatelessWidget {
  const _EmptySales();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.point_of_sale, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(S.noSales,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
