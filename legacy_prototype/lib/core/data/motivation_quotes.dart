/// Daily motivation quotes for the home screen.
abstract final class MotivationQuotes {
  static const List<String> quotes = [
    'The only bad workout is the one that didn\'t happen.',
    'Your body can stand almost anything. It\'s your mind you have to convince.',
    'Sweat is just fat crying.',
    'Don\'t wish for it. Work for it.',
    'The pain you feel today will be the strength you feel tomorrow.',
    'Fitness is not about being better than someone else. It\'s about being better than you used to be.',
    'Take care of your body. It\'s the only place you have to live.',
    'Success starts with self-discipline.',
    'Push yourself because no one else is going to do it for you.',
    'Strive for progress, not perfection.',
    'Wake up with determination. Go to bed with satisfaction.',
    'The harder you work, the luckier you get.',
    'Make yourself proud.',
    'Every workout counts.',
    'Strong is the new beautiful.',
  ];

  static String quoteForDay(DateTime date) {
    final index = date.day % quotes.length;
    return quotes[index];
  }
}
