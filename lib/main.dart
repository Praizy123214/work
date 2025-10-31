import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const BiometricsDashboard());
}

class BiometricsDashboard extends StatelessWidget {
  const BiometricsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BiometricsProvider(),
      child: MaterialApp(
        title: 'Biometrics Dashboard',
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const DashboardScreen(),
      ),
    );
  }
}

class BiometricsProvider extends ChangeNotifier {
  List<BiometricEntry> allData = [];
  List<JournalEntry> journals = [];
  bool loading = false;
  bool error = false;
  bool largeData = false;
  int rangeDays = 90;

  Future<void> loadData() async {
    loading = true;
    error = false;
    notifyListeners();

    try {
      await Future.delayed(Duration(milliseconds: 700 + Random().nextInt(500)));
      if (Random().nextDouble() < 0.1) throw Exception("Simulated load failure");

      final bioJson = await rootBundle.loadString('assets/biometrics_90d.json');
      final journalJson = await rootBundle.loadString('assets/journals.json');

      final bioList = jsonDecode(bioJson) as List;
      final journalList = jsonDecode(journalJson) as List;

      allData = bioList.map((e) => BiometricEntry.fromJson(e)).toList();
      journals = journalList.map((e) => JournalEntry.fromJson(e)).toList();

      if (largeData) {
        allData = List.generate(
          10000,
              (i) => BiometricEntry(
            date: DateTime(2025, 1, 1).add(Duration(days: i)),
            hrv: 50 + Random().nextDouble() * 20,
            rhr: 55 + Random().nextDouble() * 15,
            steps: 4000 + Random().nextInt(6000),
            sleepScore: 60 + Random().nextInt(40),
          ),
        );
      }
    } catch (e) {
      error = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setRange(int days) {
    rangeDays = days;
    notifyListeners();
  }

  void toggleLargeData(bool val) {
    largeData = val;
    loadData();
  }

  List<BiometricEntry> get filteredData {
    if (allData.isEmpty) return [];
    DateTime cutoff = allData.last.date.subtract(Duration(days: rangeDays - 1));
    return allData
        .where((e) => e.date.isAfter(cutoff) || e.date.isAtSameMomentAs(cutoff))
        .toList();
  }
}

class BiometricEntry {
  final DateTime date;
  final double hrv;
  final double rhr;
  final int steps;
  final int sleepScore;

  BiometricEntry({
    required this.date,
    required this.hrv,
    required this.rhr,
    required this.steps,
    required this.sleepScore,
  });

  factory BiometricEntry.fromJson(Map<String, dynamic> json) {
    return BiometricEntry(
      date: DateTime.parse(json['date']),
      hrv: (json['hrv'] ?? 0).toDouble(),
      rhr: (json['rhr'] ?? 0).toDouble(),
      steps: json['steps'] ?? 0,
      sleepScore: json['sleepScore'] ?? 0,
    );
  }
}

class JournalEntry {
  final DateTime date;
  final int mood;
  final String note;
  JournalEntry({required this.date, required this.mood, required this.note});

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      date: DateTime.parse(json['date']),
      mood: json['mood'],
      note: json['note'],
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BiometricsProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<BiometricsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometrics Dashboard'),
        actions: [
          Row(children: [
            const Text("Large"),
            Switch(
              value: prov.largeData,
              onChanged: (v) => prov.toggleLargeData(v),
            ),
          ])
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: prov.loading
            ? const Center(child: CircularProgressIndicator())
            : prov.error
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Failed to load data"),
              ElevatedButton(
                  onPressed: prov.loadData,
                  child: const Text("Retry"))
            ],
          ),
        )
            : prov.filteredData.isEmpty
            ? const Center(child: Text("No data available"))
            : Column(
          children: [
            RangeButtons(
              currentRange: prov.rangeDays,
              onRangeChange: prov.setRange,
            ),
            Expanded(
              child: ListView(
                children: [
                  ChartCard(
                      title: "HRV (ms)",
                      values: prov.filteredData
                          .map((e) => FlSpot(
                          e.date.millisecondsSinceEpoch
                              .toDouble(),
                          e.hrv))
                          .toList(),
                      journals: prov.journals,
                      isDark: isDark,
                      color: Colors.teal),
                  ChartCard(
                      title: "RHR (bpm)",
                      values: prov.filteredData
                          .map((e) => FlSpot(
                          e.date.millisecondsSinceEpoch
                              .toDouble(),
                          e.rhr))
                          .toList(),
                      journals: prov.journals,
                      isDark: isDark,
                      color: Colors.orange),
                  ChartCard(
                      title: "Steps",
                      values: prov.filteredData
                          .map((e) => FlSpot(
                          e.date.millisecondsSinceEpoch
                              .toDouble(),
                          e.steps.toDouble()))
                          .toList(),
                      journals: prov.journals,
                      isDark: isDark,
                      color: Colors.blue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RangeButtons extends StatelessWidget {
  final int currentRange;
  final Function(int) onRangeChange;
  const RangeButtons(
      {super.key, required this.currentRange, required this.onRangeChange});

  @override
  Widget build(BuildContext context) {
    final ranges = [7, 30, 90];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: ranges
          .map(
            (r) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ChoiceChip(
            label: Text("${r}d"),
            selected: r == currentRange,
            onSelected: (_) => onRangeChange(r),
          ),
        ),
      )
          .toList(),
    );
  }
}

class ChartCard extends StatelessWidget {
  final String title;
  final List<FlSpot> values;
  final List<JournalEntry> journals;
  final bool isDark;
  final Color color;

  const ChartCard({
    super.key,
    required this.title,
    required this.values,
    required this.journals,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox();
    double minX = values.first.x;
    double maxX = values.last.x;
    double minY = values.map((e) => e.y).reduce(min);
    double maxY = values.map((e) => e.y).reduce(max);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            AspectRatio(
              aspectRatio: 1.6,
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                        final date = DateTime.fromMillisecondsSinceEpoch(
                            spot.x.toInt());
                        final label = DateFormat('MMMd').format(date);
                        return LineTooltipItem(
                            "$label\n${spot.y.toStringAsFixed(1)}",
                            TextStyle(color: color));
                      }).toList(),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles:
                        SideTitles(showTitles: true, reservedSize: 36)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (maxX - minX) / 4,
                        getTitlesWidget: (val, meta) {
                          final date =
                          DateTime.fromMillisecondsSinceEpoch(val.toInt());
                          return Text(DateFormat('MMMd').format(date),
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: values,
                      color: color,
                      barWidth: 2,
                      isCurved: true,
                      dotData: const FlDotData(show: false),
                    )
                  ],
                  minX: minX,
                  maxX: maxX,
                  minY: minY - 2,
                  maxY: maxY + 2,
                  extraLinesData: ExtraLinesData(
                    verticalLines: journals
                        .map(
                          (j) => VerticalLine(
                        x: j.date.millisecondsSinceEpoch.toDouble(),
                        color: Colors.grey.withOpacity(0.4),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: VerticalLineLabel(
                            show: true,
                            alignment: Alignment.topCenter,
                            style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black),
                            labelResolver: (vl) => "📔"),
                      ),
                    )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
