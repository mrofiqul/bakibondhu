import 'package:flutter/material.dart';

import 'package:bakibondhu/core/app_scope.dart';
import 'package:bakibondhu/core/format.dart';
import 'package:bakibondhu/core/strings_bn.dart';
import 'package:bakibondhu/data/ledger_repository.dart';
import 'package:bakibondhu/domain/money.dart';

/// Daily sales report: total sales (credit given) with a day-by-day breakdown,
/// newest day first. Reached from the "মোট বিক্রি" card on Home.
class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _ReportData {
  final Money total;
  final List<DailySales> days;
  const _ReportData(this.total, this.days);
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  _ReportData? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  // Data held in state (not a swapped FutureBuilder future) so it repaints
  // reliably — the same pattern as Home/Customer screens.
  Future<void> _refresh() async {
    final repo = AppScope.of(context);
    final days = await repo.dailySales();
    final total = await repo.totalSales();
    if (!mounted) return;
    setState(() => _data = _ReportData(total, days));
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: const Text(S.salesReportTitle)),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _TotalSalesCard(total: data.total, days: data.days.length),
                if (data.days.isEmpty)
                  const Expanded(child: _EmptySales())
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: data.days.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) => _DayTile(row: data.days[i]),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TotalSalesCard extends StatelessWidget {
  final Money total;
  final int days;
  const _TotalSalesCard({required this.total, required this.days});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
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
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: scheme.onSecondaryContainer,
              )),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final DailySales row;
  const _DayTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.calendar_today, size: 20),
      title: Text(dayLabel(row.day),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(S.salesCount(row.count)),
      trailing: Text(
        row.total.format(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
