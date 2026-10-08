/// Release feature switches. Features that are built but planned for a later
/// version stay hidden here; flip to true (or pass --dart-define) to ship them.
///   flutter build appbundle --dart-define=ACHIEVEMENTS=true --dart-define=STREAKS=true
const bool kAchievementsEnabled = bool.fromEnvironment('ACHIEVEMENTS');
const bool kStreaksEnabled = bool.fromEnvironment('STREAKS');
