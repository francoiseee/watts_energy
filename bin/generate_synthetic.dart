import 'dart:io';
import 'package:args/args.dart';
import 'package:watts_energy/services/synthetic_data_generator.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('input', abbr: 'i', help: 'Path to input CSV file', defaultsTo: 'powerconsumption.csv')
    ..addOption('output', abbr: 'o', help: 'Path to output CSV file', defaultsTo: 'synthetic_power.csv')
    ..addOption('points', abbr: 'n', help: 'Total points to generate (default: 5x input)')
    ..addOption('step-hours', help: 'Step interval in hours', defaultsTo: '1')
    ..addOption('noise-std', help: 'Additive Gaussian noise std (relative)', defaultsTo: '0.05')
    ..addFlag('seasonality', help: 'Enable seasonality injection', defaultsTo: true)
    ..addOption('seed', help: 'Random seed', defaultsTo: '42')
    ..addFlag('help', abbr: 'h', help: 'Show usage', defaultsTo: false, negatable: false);

  final results = parser.parse(args);
  if (results['help'] == true) {
    print('Generate synthetic power dataset from a seed CSV');
    print(parser.usage);
    exit(0);
  }

  final inputPath = results['input'] as String;
  final outputPath = results['output'] as String;
  final stepHours = int.tryParse(results['step-hours'] as String? ?? '1') ?? 1;
  final noiseStd = double.tryParse(results['noise-std'] as String? ?? '0.05') ?? 0.05;
  final seed = int.tryParse(results['seed'] as String? ?? '42') ?? 42;
  final seasonality = results['seasonality'] as bool? ?? true;
  final points = (results['points'] as String?) == null
      ? null
      : int.tryParse(results['points'] as String);

  final inputFile = File(inputPath);
  if (!await inputFile.exists()) {
    stderr.writeln('Input file not found: $inputPath');
    exit(2);
  }

  final content = await inputFile.readAsString();
  final csv = await SyntheticDataGenerator.expandCsvToCsv(
    content,
    step: Duration(hours: stepHours),
    totalPoints: points,
    noiseStd: noiseStd,
    seasonality: seasonality,
    randomSeed: seed,
  );

  final outFile = File(outputPath);
  await outFile.writeAsString(csv);
  print('Synthetic dataset written to: ${outFile.path}');
}
