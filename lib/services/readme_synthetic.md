Synthetic data generation helpers

- Use `SyntheticDataGenerator.expandCsvToCsv` to expand a small CSV into a larger dataset while preserving trend/seasonality.
- Loaders (`CsvLoaderCommon`) automatically clean data and convert energy (kWh) columns into power (kW) by dividing by interval hours.

Example (in code):

```dart
import 'dart:io';
import 'package:watts_energy/services/synthetic_data_generator.dart';

Future<void> main() async {
  final seed = await File('powerconsumption.csv').readAsString();
  final bigCsv = await SyntheticDataGenerator.expandCsvToCsv(
    seed,
    step: Duration(hours: 1),
    totalPoints: 5000,
    noiseStd: 0.05,
    seasonality: true,
  );
  await File('synthetic_power.csv').writeAsString(bigCsv);
}
```