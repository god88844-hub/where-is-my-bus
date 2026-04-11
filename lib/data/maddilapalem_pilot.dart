class MaddilapalemPilot {
  static const Set<String> routeNumbers = {
    '10K',
    '12D',
    '222',
    '222V',
    '25E',
    '25IT',
    '25P',
    '52V',
    '69',
    '300M',
    '540',
    '541',
    '888',
  };

  static const Map<String, int> serviceCountByRoute = {
    '10K': 4,
    '12D': 15,
    '222': 16,
    '222V': 6,
    '25E': 2,
    '25IT': 3,
    '25P': 3,
    '52V': 4,
    '69': 6,
    '300M': 4,
    '540': 2,
    '541': 22,
    '888': 4,
  };

  static bool isPilotRoute(String routeNumber) =>
      routeNumbers.contains(routeNumber);

  static int serviceCount(String routeNumber) =>
      serviceCountByRoute[routeNumber] ?? 0;
}
