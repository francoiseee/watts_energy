import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app/app_theme.dart';
import '../services/csv_loader.dart';
import '../services/ml_service.dart';
import '../services/data_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  File? _selectedFile;
  List<PowerDataPoint> _data = [];
  List<PowerDataPoint> _forecast = [];
  LinearRegressionModel? _model;
  String? _error;
  bool _loading = false;
  int _years = 1; // forecast horizon in years
  Duration _step = const Duration(days: 1); // default daily step
  bool _usePersistent = false; // include stored training data

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();
      if (files.isNotEmpty) {
        setState(() {
          _selectedFile = files.first;
        });
        await _loadAndTrainMultiple(files);
      }
    }
  }

  void _handleFileDrop(List<File> files) {
    if (files.isNotEmpty) {
      final file = files.first;
      setState(() {
        _selectedFile = file;
      });
      _loadAndTrain(file);
    }
  }

  Future<void> _loadAndTrain(File file) async {
    setState(() {
      _loading = true;
      _error = null;
      _data = [];
      _forecast = [];
      _model = null;
    });
    try {
  final data = await CsvLoader.loadPowerData(file);
      if (data.length < 2) {
        throw Exception('Not enough rows to train. Need at least 2.');
      }
    // Optionally merge with persisted training data for more robust model
    final merged = _usePersistent
      ? await DataRepository.mergeAndSave(data)
      : data;
    final trained = MLService.train(merged);
  final model = trained.model;
      // Compute steps: years horizon with chosen step
      final totalDays = 365 * _years;
      final steps = (_step.inSeconds > 0)
          ? (Duration(days: totalDays).inSeconds ~/ _step.inSeconds)
          : 0;
      final clampedSteps = steps.clamp(1, 365 * 24 * 5);
      // Prefer seasonal forecast when possible for realism
      final preds = MLService.forecastSeasonal(
        model,
        merged,
        clampedSteps,
        _step,
      );

      setState(() {
        _data = merged;
        _forecast = preds;
        _model = model;
        _tabController.animateTo(1);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Forecast generated successfully')), 
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadAndTrainMultiple(List<File> files) async {
    setState(() {
      _loading = true;
      _error = null;
      _data = [];
      _forecast = [];
      _model = null;
    });
    try {
      final datasets = <PowerDataPoint>[];
      for (final f in files) {
        datasets.addAll(await CsvLoader.loadPowerData(f));
      }
      if (datasets.length < 2) {
        throw Exception('Not enough rows to train. Need at least 2.');
      }
      // Merge with persistent store if selected
      final merged = _usePersistent
          ? await DataRepository.mergeAndSave(datasets)
          : (datasets..sort((a,b)=>a.timestamp.compareTo(b.timestamp)));

      final trained = MLService.train(merged);
      // Compute steps
      final totalDays = 365 * _years;
      final steps = (_step.inSeconds > 0)
          ? (Duration(days: totalDays).inSeconds ~/ _step.inSeconds)
          : 0;
      final clampedSteps = steps.clamp(1, 365 * 24 * 5);
      final preds = MLService.forecastSeasonal(
        trained.model,
        merged,
        clampedSteps,
        _step,
      );

      setState(() {
        _data = merged;
        _forecast = preds;
        _model = trained.model;
        _tabController.animateTo(1);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Forecast generated from multiple files')), 
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'VarelaRound',
                ),
                children: [
                  const TextSpan(
                    text: 'Watts',
                    style: TextStyle(color: AppTheme.black),
                  ),
                  TextSpan(
                    text: 'Energy',
                    style: TextStyle(
                      color: AppTheme.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 3,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.black,
          labelColor: AppTheme.black,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'My Energy'),
            Tab(text: 'Graph'),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x22FFFFFF),
                      Color(0x44FFFFFF),
                      Color(0x22FFFFFF),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            TabBarView(
              controller: _tabController,
              children: [
                _buildMyEnergyTab(),
                _buildGraphTab(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyEnergyTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Forecast controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Forecast horizon:', style: AppTheme.bodyTextStyle),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _years,
                items: const [1, 2, 3, 5]
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y year${y>1?'s':''}')))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _years = v);
                  if (_selectedFile != null) _loadAndTrain(_selectedFile!);
                },
              ),
              const SizedBox(width: 16),
              Text('Step:', style: AppTheme.bodyTextStyle),
              const SizedBox(width: 8),
              DropdownButton<Duration>(
                value: _step,
                items: const [
                  Duration(days: 1),
                  Duration(hours: 12),
                  Duration(hours: 6),
                  Duration(hours: 1),
                ]
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d.inDays >= 1
                              ? '${d.inDays} day${d.inDays>1?'s':''}'
                              : '${d.inHours} hr'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _step = v);
                  if (_selectedFile != null) _loadAndTrain(_selectedFile!);
                },
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _usePersistent,
                    onChanged: (v) async {
                      setState(() => _usePersistent = v);
                      if (_data.isNotEmpty) {
                        // retrain to reflect change
                        await _loadAndTrainMultiple([if (_selectedFile!=null) _selectedFile!]);
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  Text('Use saved training data', style: AppTheme.bodyTextStyle),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // File upload section
          GestureDetector(
            onTap: _pickFile,
            child: DragTarget<File>(
              onAcceptWithDetails: (details) {
                _handleFileDrop([details.data]);
              },
              builder: (context, candidateData, rejectedData) {
                return Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    border: Border.all(
                      color: Colors.black,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_upload,
                        color: Colors.black,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap or drag-and-drop a CSV file',
                        style: AppTheme.subtitleTextStyle.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Expected columns: time/date and consumption (or single numeric column)',
                        style: AppTheme.bodyTextStyle.copyWith(color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Selected file info
          if (_selectedFile != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Colors.black),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedFile!.path.split(Platform.pathSeparator).last,
                      style: AppTheme.bodyTextStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87),
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                        _data = [];
                        _forecast = [];
                        _model = null;
                        _error = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          if (_loading) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Colors.black),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: AppTheme.bodyTextStyle.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGraphTab() {
    if (_data.isEmpty && _forecast.isEmpty) {
      return Center(
        child: Text(
          'Upload a CSV to see your past usage and predictions',
          style: AppTheme.titleTextStyle.copyWith(fontSize: 20),
          textAlign: TextAlign.center,
        ),
      );
    }

  final all = [..._data, ..._forecast];
  final minYData = all.map((e) => e.consumption).reduce((a, b) => a < b ? a : b);
  final maxY = all.map((e) => e.consumption).reduce((a, b) => a > b ? a : b);
  final minT = _data.first.timestamp.millisecondsSinceEpoch.toDouble();
  final maxT = all.last.timestamp.millisecondsSinceEpoch.toDouble();
  final spanHours = (maxT - minT) / (3600 * 1000);
  final showDays = spanHours >= 72; // if > 3 days, show days
  double toX(DateTime t) =>
    (t.millisecondsSinceEpoch.toDouble() - minT) / (3600 * 1000);

    // Ensure chronological order
    final dataSorted = [..._data]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Aggregate to daily points when step is daily or larger to reduce visual jitter
    List<PowerDataPoint> historyForChart;
    if (_step.inDays >= 1) {
      final byDay = <DateTime, List<double>>{};
      for (final p in dataSorted) {
        final day = DateTime(p.timestamp.year, p.timestamp.month, p.timestamp.day);
        byDay.putIfAbsent(day, () => []).add(p.consumption);
      }
      final days = byDay.keys.toList()..sort();
      historyForChart = [
        for (final d in days)
          PowerDataPoint(d, byDay[d]!.reduce((a, b) => a + b) / byDay[d]!.length),
      ];
    } else {
      historyForChart = dataSorted;
    }
    
    // 7-day simple moving average for smoother trend
    List<FlSpot> maSpots = [];
    if (historyForChart.length >= 7) {
      final values = historyForChart.map((e) => e.consumption).toList();
      final times = historyForChart.map((e) => e.timestamp).toList();
      for (int i = 6; i < values.length; i++) {
        final window = values.sublist(i - 6, i + 1);
        final mean = window.reduce((a, b) => a + b) / window.length;
        maSpots.add(FlSpot(toX(times[i]), mean));
      }
    }

    final historySpots = historyForChart
        .map((p) => FlSpot(toX(p.timestamp), p.consumption))
        .toList();
  final forecastSpots = _forecast
    .map((p) => FlSpot(toX(p.timestamp), p.consumption))
    .toList();

  // Compute summary: trend slope sign, first/last values, % change, avg daily change
  final lastObservedY = historyForChart.last.consumption;
  final lastForecastY = _forecast.isNotEmpty ? _forecast.last.consumption : _data.last.consumption;
  final delta = lastForecastY - lastObservedY;
  final pct = lastObservedY != 0 ? (delta / lastObservedY) * 100.0 : 0.0;
  final totalDays = ((all.last.timestamp.difference(all.first.timestamp)).inHours / 24).clamp(1, double.infinity);
  final avgDaily = delta / totalDays;

    // Optional: trend line from fitted model across the entire time span
    final trendSpots = <FlSpot>[];
    if (_model?.isTrained == true) {
      final firstTs = _data.first.timestamp;
      final lastTs = all.last.timestamp;
      final x0sec = 0.0;
      final x1sec = (lastTs.millisecondsSinceEpoch -
              firstTs.millisecondsSinceEpoch) /
          1000.0;
      final y0 = _model!.a! + _model!.b! * x0sec;
      final y1 = _model!.a! + _model!.b! * x1sec;
      trendSpots.add(FlSpot(toX(firstTs), y0));
      trendSpots.add(FlSpot(toX(lastTs), y1));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Power consumption (history + ${_years}y forecast, step ${_step.inDays>=1 ? "${_step.inDays}d" : "${_step.inHours}h"})',
            style: AppTheme.titleTextStyle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: (minYData * 0.95).clamp(0.0, double.infinity),
                maxY: (maxY * 1.05),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (value) =>
                      const FlLine(color: Colors.black12, strokeWidth: 1),
                  getDrawingVerticalLine: (value) =>
                      const FlLine(color: Colors.black12, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: showDays ? 24 : 6,
                      getTitlesWidget: (value, meta) => Text(
                        showDays
                            ? '${(value/24).toStringAsFixed(0)}d'
                            : '${value.toStringAsFixed(0)}h',
                        style: AppTheme.bodyTextStyle.copyWith(fontSize: 12),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style:
                            AppTheme.bodyTextStyle.copyWith(fontSize: 12),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: historySpots,
                    isCurved: false, // avoid overshoot artifacts
                    color: Colors.black,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  if (maSpots.isNotEmpty)
                    LineChartBarData(
                      spots: maSpots,
                      isCurved: false,
                      color: Colors.green,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                  LineChartBarData(
                    spots: forecastSpots,
                    isCurved: false,
                    color: Colors.blueGrey,
                    barWidth: 2,
                    dashArray: [8, 6],
                    dotData: const FlDotData(show: false),
                  ),
                  if (trendSpots.isNotEmpty)
                    LineChartBarData(
                      spots: trendSpots,
                      isCurved: false,
                      color: Colors.orange,
                      barWidth: 2,
                      dashArray: [2, 2],
                      dotData: const FlDotData(show: false),
                    ),
                ],
                lineTouchData: const LineTouchData(enabled: true),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    left: BorderSide(color: Colors.black54),
                    bottom: BorderSide(color: Colors.black54),
                    right: BorderSide(color: Colors.transparent),
                    top: BorderSide(color: Colors.transparent),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LegendItem(label: 'History', color: Colors.black, dashed: false),
              if (maSpots.isNotEmpty)
                _LegendItem(label: '7-day MA', color: Colors.green, dashed: false),
              _LegendItem(label: 'Forecast', color: Colors.blueGrey, dashed: true),
              if (trendSpots.isNotEmpty)
                _LegendItem(label: 'Trend', color: Colors.orange, dashed: true),
            ],
          ),
          const SizedBox(height: 12),
          // Interpretation summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
          delta >= 0
            ? 'Trend: rising (kWh increasing)'
            : 'Trend: falling (kWh decreasing)',
                  style: AppTheme.subtitleTextStyle.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Change over ${_years} year${_years>1?'s':''} (vs. last observed): ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(2)} kWh (${pct.toStringAsFixed(1)}%)',
                  style: AppTheme.bodyTextStyle,
                ),
                const SizedBox(height: 6),
                Text(
                  'Average change per day: ${avgDaily.toStringAsFixed(3)} kWh/day',
                  style: AppTheme.bodyTextStyle,
                ),
                if (_model?.rSquared != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Fit (R²): ${(_model!.rSquared! * 100).toStringAsFixed(1)}%'
                        '${_model!.rSquared! < 0.2 ? ' — low linear fit; strong seasonality/noise present' : ''}',
                    style: AppTheme.bodyTextStyle,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final bool dashed;
  const _LegendItem({required this.label, required this.color, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    Widget swatch;
    if (dashed) {
      swatch = Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          4,
          (i) => Container(
            width: 10,
            height: 4,
            margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
            color: color,
          ),
        ),
      );
    } else {
      swatch = Container(width: 40, height: 4, color: color);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 8),
        Text(label, style: AppTheme.bodyTextStyle.copyWith(fontSize: 12)),
      ],
    );
  }
}