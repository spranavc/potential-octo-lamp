import 'package:drift/drift.dart';

/// A climbing gym — can be user-created or seeded from the directory.
@DataClassName('Gym')
class Gyms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get userId => text().nullable()();           // Supabase auth.uid() — null for directory gyms
  // Location
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get address => text().nullable()();
  // Contact
  TextColumn get phone => text().nullable()();
  TextColumn get website => text().nullable()();
  // Details
  TextColumn get description => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  RealColumn get rating => real().nullable()();
  IntColumn get ratingCount => integer().nullable()();
  TextColumn get hours => text().nullable()();            // JSON blob of weekly schedule
  TextColumn get dayPassPrice => text().nullable()();     // "~$22"
  // Amenities
  BoolColumn get hasBouldering => boolean().nullable()();
  BoolColumn get hasTopRope => boolean().nullable()();
  BoolColumn get hasLead => boolean().nullable()();
  BoolColumn get hasAutoBelay => boolean().nullable()();
  BoolColumn get hasTrainingArea => boolean().nullable()();
  BoolColumn get hasYoga => boolean().nullable()();
  BoolColumn get hasProShop => boolean().nullable()();
  BoolColumn get hasCafe => boolean().nullable()();
  BoolColumn get hasShowers => boolean().nullable()();
  BoolColumn get hasParking => boolean().nullable()();
  // Meta
  BoolColumn get isDirectory => boolean().withDefault(const Constant(false))();  // seeded = true, user = false
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A wall within a gym (e.g., "Main Cave", "Slab Wall").
@DataClassName('Wall')
class Walls extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gymId => integer().references(Gyms, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Maps a gym's hold color to a grade in a grading system.
///
/// Example: a gym's "red" holds → V4 (V-scale) or 6B+ (Font).
@DataClassName('GymColor')
class GymColors extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gymId => integer().references(Gyms, #id, onDelete: KeyAction.cascade)();
  TextColumn get colorName => text()();    // e.g. "red"
  TextColumn get colorHex => text()();     // e.g. "#FF0000"
  TextColumn get gradeSystem => text()();  // "V-scale" or "Font"
  TextColumn get gradeValue => text()();   // e.g. "V4", "6B+"
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A climbing session at a gym.
@DataClassName('Session')
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gymId => integer().references(Gyms, #id, onDelete: KeyAction.cascade)();
  IntColumn get wallId => integer().nullable().references(Walls, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get userId => text().nullable()();  // Supabase auth.uid()
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();  // synced | pending | conflict
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A single climb attempt within a session.
///
/// [sent] is true for success (send), false for failure.
/// [rpe] is Rate of Perceived Exertion, 1-10, nullable.
@DataClassName('Climb')
class Climbs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get gradeSystem => text()();  // "V-scale" or "Font"
  TextColumn get gradeValue => text()();   // e.g. "V5", "7A"
  BoolColumn get sent => boolean()();
  IntColumn get attemptNumber => integer().withDefault(const Constant(1))();
  IntColumn get problemNumber => integer().withDefault(const Constant(1))();
  RealColumn get rpe => real().nullable()();
  IntColumn get completionPercent => integer().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get loggedAt => dateTime()();
  TextColumn get userId => text().nullable()();  // Supabase auth.uid()
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();  // synced | pending | conflict
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A climb style / hold-type tag (e.g., "crimpy", "dynamic", "slopey").
@DataClassName('Tag')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Many-to-many join: which tags apply to which climbs.
@DataClassName('ClimbTag')
class ClimbTags extends Table {
  IntColumn get climbId => integer().references(Climbs, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId => integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {climbId, tagId};
}

/// A project — a specific climb the user is working on.
@DataClassName('Project')
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get gymId => integer().references(Gyms, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get gradeSystem => text()();
  TextColumn get gradeValue => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, completed, abandoned
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get userId => text().nullable()();  // Supabase auth.uid()
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();  // synced | pending | conflict
  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Many-to-many join: which climbs are associated with which projects.
@DataClassName('ProjectClimb')
class ProjectClimbs extends Table {
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get climbId => integer().references(Climbs, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {projectId, climbId};
}
