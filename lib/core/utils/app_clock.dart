import 'local_date.dart';

/// Wall-clock access, injectable for tests. Only used for timestamps and
/// calendar dates; elapsed workout time uses a monotonic clock instead.
class AppClock {
  const AppClock();

  DateTime now() => DateTime.now();

  DateTime nowUtc() => now().toUtc();

  LocalDate today() => LocalDate.fromDateTime(now());
}

/// A clock fixed to (or advanced from) a given time, for tests.
class FixedClock extends AppClock {
  FixedClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration duration) => current = current.add(duration);
}
