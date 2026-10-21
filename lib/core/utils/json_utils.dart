/// Small helpers for reading untrusted JSON maps with clear error messages.
///
/// Every reader throws a [FormatException] naming the offending field, so
/// catalog validation and backup import can report exactly what is wrong.
typedef JsonMap = Map<String, dynamic>;

JsonMap asJsonMap(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), v));
  }
  throw FormatException('"$field" must be an object');
}

List<Object?> asJsonList(Object? value, String field) {
  if (value is List) return value;
  throw FormatException('"$field" must be a list');
}

String readString(JsonMap json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('"$key" must be a string');
}

String? readOptionalString(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('"$key" must be a string');
}

int readInt(JsonMap json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is double && value == value.roundToDouble()) return value.toInt();
  throw FormatException('"$key" must be a whole number');
}

int? readOptionalInt(JsonMap json, String key) {
  if (json[key] == null) return null;
  return readInt(json, key);
}

int readIntOr(JsonMap json, String key, int fallback) =>
    json[key] == null ? fallback : readInt(json, key);

double readDouble(JsonMap json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toDouble();
  throw FormatException('"$key" must be a number');
}

double? readOptionalDouble(JsonMap json, String key) {
  if (json[key] == null) return null;
  return readDouble(json, key);
}

bool readBool(JsonMap json, String key, {bool fallback = false}) {
  final value = json[key];
  if (value == null) return fallback;
  if (value is bool) return value;
  throw FormatException('"$key" must be true or false');
}

List<String> readStringList(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return const [];
  return asJsonList(value, key)
      .map((e) {
        if (e is String) return e;
        throw FormatException('"$key" must contain only strings');
      })
      .toList(growable: false);
}

DateTime readDateTime(JsonMap json, String key) {
  final value = readString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('"$key" is not a valid timestamp');
  return parsed;
}

DateTime? readOptionalDateTime(JsonMap json, String key) {
  if (json[key] == null) return null;
  return readDateTime(json, key);
}

List<T> readObjectList<T>(JsonMap json, String key, T Function(JsonMap) parse) {
  final value = json[key];
  if (value == null) return const [];
  final list = asJsonList(value, key);
  return [
    for (var i = 0; i < list.length; i++)
      _wrap('$key[$i]', () => parse(asJsonMap(list[i], '$key[$i]'))),
  ];
}

T _wrap<T>(String path, T Function() body) {
  try {
    return body();
  } on FormatException catch (e) {
    throw FormatException('$path: ${e.message}');
  }
}

/// Values exposed by every enum that is stored in JSON.
abstract interface class JsonEnum {
  String get json;
  String get label;
}

T parseEnum<T extends JsonEnum>(List<T> values, Object? raw, String field) {
  for (final value in values) {
    if (value.json == raw) return value;
  }
  throw FormatException('"$field" has unknown value "$raw"');
}

T parseEnumOr<T extends JsonEnum>(List<T> values, Object? raw, T fallback) =>
    parseEnumOrNull(values, raw) ?? fallback;

T? parseEnumOrNull<T extends JsonEnum>(List<T> values, Object? raw) {
  for (final value in values) {
    if (value.json == raw) return value;
  }
  return null;
}
