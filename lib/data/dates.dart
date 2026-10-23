/// Helpers to work with calendar days.
///
/// Every function here looks at the calendar day of a date and never at the
/// instant, so a daylight saving change never moves a day around.
library;

/// The number of days since the epoch for the calendar day of [date].
int dayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// The name of the weekday of [date], in Spanish.
String weekdayName(DateTime date) => const [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
][date.weekday - 1];

/// A short label for [date] relative to [today].
///
/// Used to say when a task comes due, without making the user do the maths.
String relativeDayLabel(DateTime date, DateTime today) {
  final days = dayNumber(date) - dayNumber(today);
  if (days == 0) return 'Hoy';
  if (days == 1) return 'Mañana';
  if (days == 2) return 'Pasado mañana';
  if (days < 7) return 'El ${weekdayName(date)}';
  return 'En $days días';
}
