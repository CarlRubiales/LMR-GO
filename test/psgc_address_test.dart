import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/psgc_service.dart';
import 'package:flutter_app/widgets/searchable_address_picker.dart';
import 'package:flutter_app/theme/app_theme.dart';

void main() {
  group('PSGC Service & Location Model Tests', () {
    test('PsgcLocation.cleanName correctly decodes corrupt accents', () {
      expect(PsgcLocation.cleanName('Los BaÃ±os'), 'Los Baños');
      expect(PsgcLocation.cleanName('City of BiÃ±an'), 'City of Biñan');
      expect(PsgcLocation.cleanName('ParaÃ±aque'), 'Parañaque');
    });

    test('getProvinces contains all 81 provinces + Metro Manila (NCR)', () async {
      final provinces = await PsgcService.instance.getProvinces();
      expect(provinces.length, greaterThanOrEqualTo(82));
      final names = provinces.map((p) => p.name).toList();
      expect(names, contains('Metro Manila (NCR)'));
      expect(names, contains('Laguna'));
      expect(names, contains('Cavite'));
      expect(names, contains('Cebu'));
      expect(names, contains('Davao Del Sur'));
    });

    test('getCitiesMunicipalities returns cities for Laguna and NCR offline fallback', () async {
      const laguna = PsgcLocation(code: '043400000', name: 'Laguna');
      final cities = await PsgcService.instance.getCitiesMunicipalities(laguna);
      expect(cities.isNotEmpty, isTrue);
      final cityNames = cities.map((c) => c.name).toList();
      expect(cityNames, contains('Santa Cruz'));
      expect(cityNames, contains('Pila'));
      expect(cityNames, contains('Los Baños'));
    });

    test('getBarangays returns barangays for Pila and Santa Cruz offline fallback', () async {
      const pila = PsgcLocation(code: '043422000', name: 'Pila');
      final brgys = await PsgcService.instance.getBarangays(pila);
      expect(brgys.isNotEmpty, isTrue);
      final brgyNames = brgys.map((b) => b.name).toList();
      expect(brgyNames, contains('Santa Clara Norte (Pob.)'));
      expect(brgyNames, contains('Santa Clara Sur (Pob.)'));
      expect(brgyNames, contains('Aplaya'));
    });
  });

  group('SearchableAddressPicker Widget Tests', () {
    testWidgets('shows label, hint and disabled reason when disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SearchableAddressPicker(
              label: 'Municipality / City *',
              hint: 'Select province first',
              selectedLocation: null,
              items: const [],
              isEnabled: false,
              disabledReason: 'Please select a Province first.',
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Municipality / City *'), findsOneWidget);
      expect(find.text('Select province first'), findsOneWidget);
      expect(find.text('Please select a Province first.'), findsOneWidget);
    });

    testWidgets('tapping enabled picker opens search bottom sheet and allows filtering', (tester) async {
      PsgcLocation? selected;
      const sampleLocations = [
        PsgcLocation(code: '1', name: 'Laguna'),
        PsgcLocation(code: '2', name: 'Cavite'),
        PsgcLocation(code: '3', name: 'Batangas'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SearchableAddressPicker(
              label: 'Province *',
              hint: 'Search & select province',
              selectedLocation: null,
              items: sampleLocations,
              isEnabled: true,
              onSelected: (loc) => selected = loc,
            ),
          ),
        ),
      );

      // Tap to open sheet
      await tester.tap(find.text('Search & select province'));
      await tester.pumpAndSettle();

      expect(find.text('Select Province'), findsOneWidget);
      expect(find.text('Laguna'), findsOneWidget);
      expect(find.text('Cavite'), findsOneWidget);
      expect(find.text('Batangas'), findsOneWidget);

      // Type in search box to filter
      await tester.enterText(find.byType(TextField), 'Lagu');
      await tester.pumpAndSettle();

      expect(find.text('Laguna'), findsOneWidget);
      expect(find.text('Cavite'), findsNothing);
      expect(find.text('Batangas'), findsNothing);

      // Select Laguna
      await tester.tap(find.text('Laguna'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.name, 'Laguna');
      expect(find.text('Select Province'), findsNothing);
    });

    testWidgets('shows empty state when no location matches query', (tester) async {
      const sampleLocations = [
        PsgcLocation(code: '1', name: 'Laguna'),
        PsgcLocation(code: '2', name: 'Cavite'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SearchableAddressPicker(
              label: 'Province *',
              hint: 'Search & select province',
              selectedLocation: null,
              items: sampleLocations,
              isEnabled: true,
              onSelected: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Search & select province'));
      await tester.pumpAndSettle();

      // Search for nonexistent location
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pumpAndSettle();

      expect(find.text('No matching locations found'), findsOneWidget);
    });
  });
}
