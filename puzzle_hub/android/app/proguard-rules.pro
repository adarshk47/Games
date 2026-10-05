# flutter_local_notifications serialises scheduled notifications with Gson;
# without these rules R8 strips generic type info and scheduling fails in release.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# WorkManager (pulled in by Google Mobile Ads) creates its Room database by
# reflection; R8 full mode otherwise strips WorkDatabase_Impl and the app
# crashes on launch with "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
