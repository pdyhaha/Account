package com.petledger.pet_ledger

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class PetLedgerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Removed pre-warming to avoid native crashes with cached engines
    }
}
