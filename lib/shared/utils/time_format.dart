/// Formats a [DateTime] to 12-hour time string, e.g. "2:30 PM".
String formatTime(DateTime dt) {
  final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  final min = dt.minute.toString().padLeft(2, '0');
  return '$hour:$min $amPm';
}

/// Formats a [DateTime] to a display-friendly date, e.g. "Jun 18".
String formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}

/// Formats a [DateTime] to a full date, e.g. "Jun 18, 2026".
String formatDateFull(DateTime dt) {
  return '${formatDate(dt)}, ${dt.year}';
}

/// Formats a [DateTime] to date + time, e.g. "Jun 18, 2026  2:30 PM".
String formatDateTime(DateTime dt) {
  return '${formatDateFull(dt)}  ${formatTime(dt)}';
}
