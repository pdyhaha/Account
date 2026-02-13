# Flutter Proguard Rules
-keep class com.petledger.pet_ledger.** { *; }

# Drift / SQLite
-keep class net.sqlcipher.** { *; }
-keep class org.sqlite.** { *; }

# Riverpod
-keep class * extends androidx.lifecycle.ViewModel { *; }

# Sherpa-ONNX
-keep class com.k2fsa.sherpa.onnx.** { *; }

# Shared Preferences / Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
