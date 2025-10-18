import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app/app_theme.dart';
import '../app/responsive.dart';
import '../services/csv_loader.dart';
import '../services/ml_service.dart';
import '../services/data_repository.dart';
import '../services/synthetic_data_generator.dart';
import '../services/file_output.dart';
import 'package:csv/csv.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedFilePath; // native only, path string
  PlatformFile? _selectedWebFile; // web file reference
  List<PowerDataPoint> _data = [];
  List<PowerDataPoint> _forecast = [];
  LinearRegressionModel? _model;
  // _historyX not needed for seasonal forecast
  String? _error;
  bool _loading = false;
  int _years = 1; // forecast horizon in years
  Duration _step = const Duration(days: 1); // default daily step
  bool _usePersistent = false; // include stored training data
  // Seasonal toggle removed; app uses non-seasonal forecast by default

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPersistedForecast();
  }

  Future<void> _loadPersistedForecast() async {
    try {
      final saved = await DataRepository.loadForecast();
      if (saved.isNotEmpty) {
        setState(() {
          _forecast = saved..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      if (kIsWeb) {
        final files = result.files.where((f) => f.bytes != null).toList();
        if (files.isNotEmpty) {
          setState(() {
            _selectedWebFile = files.first;
          });
          await _loadAndTrainMultipleWeb(files);
        }
      } else {
        final paths = result.files
            .where((f) => f.path != null)
            .map((f) => f.path!)
            .toList();
        if (paths.isNotEmpty) {
          setState(() {
            _selectedFilePath = paths.first;
          });
          await _loadAndTrainMultiplePaths(paths);
        }
      }
    }
  }

  Future<void> _loadAndTrainPath(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _data = [];
      _forecast = [];
      _model = null;
    });
    try {
      final data = await CsvLoader.loadPowerDataFromPath(path);
      if (data.length < 2) {
        throw Exception('Not enough rows to train. Need at least 2.');
      }
      final merged = (!kIsWeb && _usePersistent)
          ? await DataRepository.mergeAndSave(data)
          : data;
      final trained = MLService.train(merged);
      final model = trained.model;
      final totalDays = 365 * _years;
      final steps = (_step.inSeconds > 0)
          ? (Duration(days: totalDays).inSeconds ~/ _step.inSeconds)
          : 0;
      final clampedSteps = steps.clamp(1, 365 * 24 * 5);
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
      // Persist forecast for later sessions
      await DataRepository.saveForecast(
        preds,
        stepSeconds: _step.inSeconds,
        horizonSteps: clampedSteps,
        a: model.a,
        b: model.b,
      );
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

  Widget _uploadCardBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.cloud_upload,
          color: Colors.black,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          'Tap to select CSV ${kIsWeb ? '' : 'or drag-and-drop'}',
          style:
              AppTheme.subtitleTextStyle.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Expected columns: time/date and consumption (or single numeric column)',
          style: AppTheme.bodyTextStyle.copyWith(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _loadAndTrainMultiplePaths(List<String> paths) async {
    setState(() {
      _loading = true;
      _error = null;
      _data = [];
      _forecast = [];
      _model = null;
    });
    try {
      final datasets = <PowerDataPoint>[];
      for (final p in paths) {
        datasets.addAll(await CsvLoader.loadPowerDataFromPath(p));
      }
      if (datasets.length < 2) {
        throw Exception('Not enough rows to train. Need at least 2.');
      }
      final merged = (!kIsWeb && _usePersistent)
          ? await DataRepository.mergeAndSave(datasets)
          : (datasets..sort((a, b) => a.timestamp.compareTo(b.timestamp)));

      final trained = MLService.train(merged);
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
      await DataRepository.saveForecast(
        preds,
        stepSeconds: _step.inSeconds,
        horizonSteps: clampedSteps,
        a: trained.model.a,
        b: trained.model.b,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Forecast generated from multiple files')),
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

  Future<void> _loadAndTrainMultipleWeb(List<PlatformFile> files) async {
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
        final bytes = f.bytes;
        if (bytes == null) continue;
        datasets.addAll(await CsvLoader.loadPowerDataFromBytes(bytes));
      }
      if (datasets.length < 2) {
        throw Exception('Not enough rows to train. Need at least 2.');
      }
      datasets.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final trained = MLService.train(datasets);
      final totalDays = 365 * _years;
      final steps = (_step.inSeconds > 0)
          ? (Duration(days: totalDays).inSeconds ~/ _step.inSeconds)
          : 0;
      final clampedSteps = steps.clamp(1, 365 * 24 * 5);
      final preds = MLService.forecastSeasonal(
        trained.model,
        datasets,
        clampedSteps,
        _step,
      );
      setState(() {
        _data = datasets;
        _forecast = preds;
        _model = trained.model;
        _tabController.animateTo(1);
      });
      await DataRepository.saveForecast(
        preds,
        stepSeconds: _step.inSeconds,
        horizonSteps: clampedSteps,
        a: trained.model.a,
        b: trained.model.b,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Forecast generated successfully (web)')),
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
              height: Responsive.s(context, 28),
              width: Responsive.s(context, 28),
            ),
            SizedBox(width: Responsive.s(context, 8)),
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
      padding: EdgeInsets.all(Responsive.s(context, 14)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Responsive.s(context, 10),
            runSpacing: Responsive.s(context, 8),
            children: [
              Text('Forecast horizon:', style: AppTheme.bodyTextStyle),
              SizedBox(width: Responsive.s(context, 6)),
              DropdownButton<int>(
                value: _years,
                items: const [1, 2, 3, 5]
                    .map((y) => DropdownMenuItem(
                        value: y, child: Text('$y year${y > 1 ? 's' : ''}')))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _years = v);
                  if (_selectedFilePath != null)
                    _loadAndTrainPath(_selectedFilePath!);
                },
              ),
              SizedBox(width: Responsive.s(context, 12)),
              Text('Step:', style: AppTheme.bodyTextStyle),
              SizedBox(width: Responsive.s(context, 6)),
              DropdownButton<Duration>(
                value: _step,
                items: const [
                  Duration(days: 1),
                  Duration(hours: 12),
                  Duration(hours: 6),
                  Duration(hours: 1),
                ]
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(
                          d.inDays >= 1
                              ? '${d.inDays} day${d.inDays > 1 ? 's' : ''}'
                              : '${d.inHours} hr',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _step = v);
                  if (_data.isNotEmpty && _model?.isTrained == true) {
                    final totalDays = 365 * _years;
                    final steps = (_step.inSeconds > 0)
                        ? (Duration(days: totalDays).inSeconds ~/
                            _step.inSeconds)
                        : 0;
                    final clampedSteps = steps.clamp(1, 365 * 24 * 5);
                    final preds = MLService.forecastSeasonal(
                      _model!,
                      _data,
                      clampedSteps,
                      _step,
                    );
                    setState(() => _forecast = preds);
                  }
                },
              ),
              // Seasonal toggle removed
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Switch(
                    value: _usePersistent,
                    onChanged: (v) async {
                      setState(() => _usePersistent = v);
                      if (_data.isNotEmpty) {
                        if (_selectedFilePath != null) {
                          await _loadAndTrainMultiplePaths([
                            _selectedFilePath!
                          ]);
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  Text('Use saved training data',
                      style: AppTheme.bodyTextStyle),
                ],
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_data.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please upload a dataset first to generate a dummy dataset.')),
                      );
                    }
                    return;
                  }
                  try {
                    // Generate a larger synthetic dataset based on the loaded data
                    final synthetic = SyntheticDataGenerator.expand(
                      _data,
                      step: _step.inSeconds > 0 ? _step : const Duration(hours: 1),
                      totalPoints: (_data.length * 5).clamp(_data.length + 10, 20000),
                      noiseStd: 0.05,
                      seasonality: true,
                      randomSeed: 42,
                    );
                    // Convert to CSV
                    final csvRows = <List<dynamic>>[
                      ['timestamp', 'consumption'],
                      ...synthetic.map((p) => [p.timestamp.toIso8601String(), p.consumption])
                    ];
                    final csv = const ListToCsvConverter().convert(csvRows);
                    final path = await FileOutput.saveCsv('synthetic_from_uploaded.csv', csv);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Synthetic dataset saved: $path')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to generate synthetic dataset: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: const Text('Generate dummy dataset from uploaded', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          SizedBox(height: Responsive.s(context, 12)),
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              height: Responsive.hp(context, 22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _uploadCardBody(),
            ),
          ),
          SizedBox(height: Responsive.s(context, 14)),
          if (!kIsWeb && _selectedFilePath != null)
            Container(
              padding: EdgeInsets.all(Responsive.s(context, 10)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Colors.black),
                  SizedBox(width: Responsive.s(context, 6)),
                  Expanded(
                    child: Text(
                      _selectedFilePath!.split(RegExp(r'[\\/]')).last,
                      style: AppTheme.bodyTextStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87),
                    onPressed: () {
                      setState(() {
                        _selectedFilePath = null;
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
          if (kIsWeb && _selectedWebFile != null)
            Container(
              padding: EdgeInsets.all(Responsive.s(context, 10)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: Colors.black),
                  SizedBox(width: Responsive.s(context, 6)),
                  Expanded(
                    child: Text(
                      _selectedWebFile!.name,
                      style: AppTheme.bodyTextStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black87),
                    onPressed: () {
                      setState(() {
                        _selectedWebFile = null;
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
    // Downsample helper: averages every N points to reduce total count
    List<PowerDataPoint> downsample(List<PowerDataPoint> data, int maxPoints) {
      if (data.length <= maxPoints) return data;
      int groupSize = (data.length / maxPoints).ceil();
      List<PowerDataPoint> result = [];
      for (int i = 0; i < data.length; i += groupSize) {
        final group = data.sublist(i, (i + groupSize).clamp(0, data.length));
        final avgConsumption =
            group.map((e) => e.consumption).reduce((a, b) => a + b) /
                group.length;
        result.add(PowerDataPoint(group.first.timestamp, avgConsumption));
      }
      return result;
    }

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
    final minYData =
        all.map((e) => e.consumption).reduce((a, b) => a < b ? a : b);
    final maxY = all.map((e) => e.consumption).reduce((a, b) => a > b ? a : b);
    final minT = _data.first.timestamp.millisecondsSinceEpoch.toDouble();
    final maxT = all.last.timestamp.millisecondsSinceEpoch.toDouble();
    final spanHours = (maxT - minT) / (3600 * 1000);
    final showDays = spanHours >= 72; // if > 3 days, show days
    double toX(DateTime t) =>
        (t.millisecondsSinceEpoch.toDouble() - minT) / (3600 * 1000);

    final dataSorted = [..._data]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    List<PowerDataPoint> historyForChart;
    if (_step.inDays >= 1) {
      final byDay = <DateTime, List<double>>{};
      for (final p in dataSorted) {
        final day =
            DateTime(p.timestamp.year, p.timestamp.month, p.timestamp.day);
        byDay.putIfAbsent(day, () => []).add(p.consumption);
      }
      final days = byDay.keys.toList()..sort();
      historyForChart = [
        for (final d in days)
          PowerDataPoint(
              d, byDay[d]!.reduce((a, b) => a + b) / byDay[d]!.length),
      ];
    } else {
      historyForChart = dataSorted;
    }
    // Downsample if too many points
    const int maxPoints = 200;
    historyForChart = downsample(historyForChart, maxPoints);

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
    final forecastSpots =
        _forecast.map((p) => FlSpot(toX(p.timestamp), p.consumption)).toList();

    final trendSpots = <FlSpot>[];
    if (_model?.isTrained == true) {
      final firstTs = _data.first.timestamp;
      final lastTs = all.last.timestamp;
      final x0sec = 0.0;
      final x1sec =
          (lastTs.millisecondsSinceEpoch - firstTs.millisecondsSinceEpoch) /
              1000.0;
      final y0 = _model!.a! + _model!.b! * x0sec;
      final y1 = _model!.a! + _model!.b! * x1sec;
      trendSpots.add(FlSpot(toX(firstTs), y0));
      trendSpots.add(FlSpot(toX(lastTs), y1));
    }

    return Padding(
      padding: EdgeInsets.all(Responsive.s(context, 14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Power consumption (history + ${_years}y forecast, step ${_step.inDays >= 1 ? "${_step.inDays}d" : "${_step.inHours}h"})',
            style: AppTheme.titleTextStyle
                .copyWith(fontSize: Responsive.sp(context, 18)),
          ),
          SizedBox(height: Responsive.s(context, 10)),
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
                            ? '${(value / 24).toStringAsFixed(0)}d'
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
                        style: AppTheme.bodyTextStyle.copyWith(fontSize: 12),
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
                    isCurved: false,
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
                    dashArray: const [8, 6],
                    dotData: const FlDotData(show: false),
                  ),
                  if (trendSpots.isNotEmpty)
                    LineChartBarData(
                      spots: trendSpots,
                      isCurved: false,
                      color: Colors.orange,
                      barWidth: 2,
                      dashArray: const [2, 2],
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
          SizedBox(height: Responsive.s(context, 8)),
          Wrap(
            spacing: Responsive.s(context, 12),
            runSpacing: Responsive.s(context, 6),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              _LegendItem(label: 'History', color: Colors.black, dashed: false),
              _LegendItem(
                  label: '7-day MA', color: Colors.green, dashed: false),
              _LegendItem(
                  label: 'Forecast', color: Colors.blueGrey, dashed: true),
              _LegendItem(label: 'Trend', color: Colors.orange, dashed: true),
            ],
          ),
          SizedBox(height: Responsive.s(context, 10)),
          if (_model?.isTrained == true) _buildInterpretation(context),
        ],
      ),
    );
  }

  Widget _buildInterpretation(BuildContext context) {
    // Slope-based daily change (from linear regression)
    final b = _model!.b ?? 0.0; // units per second
    final slopePerDay = b * 86400.0;
    final direction = slopePerDay.abs() < 1e-6
        ? 'stable'
        : (slopePerDay > 0 ? 'increasing' : 'decreasing');
    final r2 = _model!.rSquared ?? 0.0;

    // Projected change vs recent baseline (closer to previous interpretation)
    final recentWindowDays = 30;
    final recentCutoff = _data.isNotEmpty
        ? _data.last.timestamp.subtract(Duration(days: recentWindowDays))
        : DateTime.now();
    final recent =
        _data.where((p) => p.timestamp.isAfter(recentCutoff)).toList();
    final recentMean = recent.isNotEmpty
        ? recent.map((e) => e.consumption).reduce((a, b) => a + b) /
            recent.length
        : (_data.isNotEmpty
            ? _data.map((e) => e.consumption).reduce((a, b) => a + b) /
                _data.length
            : 0.0);

    // Forecast next year with daily step and compute mean (respect seasonal toggle)
    final forecastDays = 365;
    final List<PowerDataPoint> projected = MLService.forecastSeasonal(
      _model!,
      _data,
      forecastDays,
      const Duration(days: 1),
    );
    final projMean = projected.isNotEmpty
        ? projected.map((e) => e.consumption).reduce((a, b) => a + b) /
            projected.length
        : 0.0;
    final deltaVsRecentPerDay = projMean - recentMean;
    final pct = recentMean.abs() > 1e-9
        ? (deltaVsRecentPerDay / recentMean) * 100.0
        : 0.0;

    String fmt(double v) {
      final av = v.abs();
      if (av >= 1) return v.toStringAsFixed(2);
      if (av >= 0.1) return v.toStringAsFixed(3);
      return v.toStringAsFixed(4);
    }

    return Container(
      padding: EdgeInsets.all(Responsive.s(context, 10)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: AppTheme.bodyTextStyle
                  .copyWith(fontSize: Responsive.sp(context, 14)),
              children: [
                const TextSpan(
                    text: 'Interpretation: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: 'Trend is '),
                TextSpan(
                    text: direction,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          SizedBox(height: Responsive.s(context, 6)),
          Text('Average change per day (slope): ${fmt(slopePerDay)}/day',
              style: AppTheme.bodyTextStyle
                  .copyWith(fontSize: Responsive.sp(context, 13))),
          Text(
              'Projected daily vs recent (~${recentWindowDays}d): '
              '${fmt(deltaVsRecentPerDay)}/day (${fmt(pct)}%)',
              style: AppTheme.bodyTextStyle
                  .copyWith(fontSize: Responsive.sp(context, 13))),
          Text('Fit (R²): ${r2.toStringAsFixed(2)}',
              style: AppTheme.bodyTextStyle
                  .copyWith(fontSize: Responsive.sp(context, 13))),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  final bool dashed;
  const _LegendItem(
      {required this.label, required this.color, this.dashed = false});

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
