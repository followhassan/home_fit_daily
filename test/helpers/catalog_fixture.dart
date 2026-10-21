import 'dart:io';

import 'package:home_fit_daily/data/catalog/catalog.dart';
import 'package:home_fit_daily/data/catalog/catalog_loader.dart';

Catalog? _cached;

/// Loads the real bundled catalog from disk (tests run from the project
/// root), parsed exactly as the app does.
Catalog loadBundledCatalog() =>
    _cached ??= parseCatalog([for (final path in CatalogAssets.all) File(path).readAsStringSync()]);
