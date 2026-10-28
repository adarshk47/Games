# Narrow keep rules only: broad "-keep class pkg.** { *; }" rules stop R8 from
# shrinking/optimising whole libraries (Play Console R8 warning). Libraries ship
# their own consumer rules; these cover what still needs reflection.

# flutter_local_notifications serialises scheduled notifications with Gson:
# keep the generic type info and its model classes (fields are read by name).
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# WorkManager creates its Room database by reflection; R8 full mode otherwise
# strips WorkDatabase_Impl ("Failed to create an instance of WorkDatabase").
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
