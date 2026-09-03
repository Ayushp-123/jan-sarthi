class AppConstants {
  static const String appName = 'Jan Sarthi';
  
  // Emergency Radius Configuration
  static const double initialEmergencyRadiusMeters = 500.0;
  static const double maxEmergencyRadiusMeters = 5000.0;
  
  // Location Updates
  static const int locationUpdateIntervalSeconds = 4;
  static const int locationDistanceFilterMeters = 5;

  // Responder Reliability Monitor Configuration Constants
  static const int primaryMonitorIntervalSeconds = 5;
  static const int locationStaleThresholdSeconds = 15;
  static const int connectionGracePeriodSeconds = 20;
  static const int noProgressThresholdSeconds = 30;
  static const double etaGracePeriodMinutes = 5.0;
  
  // Firestore Collections
  static const String usersCollection = 'users';
  static const String emergenciesCollection = 'emergencies';
  static const String respondersSubcollection = 'responders';

  // State Machine Values
  static const String statusSearching = 'SEARCHING';
  static const String statusAssigned = 'ASSIGNED';
  static const String statusApproaching = 'APPROACHING';
  static const String statusArrived = 'ARRIVED';
  static const String statusCompleted = 'COMPLETED';
  static const String statusCancelled = 'CANCELLED';
}
