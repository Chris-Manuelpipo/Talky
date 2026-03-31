package com.example.talky

import android.content.ContentResolver
import android.database.Cursor
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.talky/contacts"
    private val CALL_CHANNEL = "com.example.talky/call_notification"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Canal pour les contacts
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getContacts") {
                val contacts = getContacts()
                result.success(contacts)
            } else {
                result.notImplemented()
            }
        }
        
        // Canal pour les notifications d'appel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showIncomingCall" -> {
                    val data = call.arguments as? Map<String, Any?> ?: emptyMap()
                    val service = CallNotificationService(this)
                    service.showIncomingCallNotification(data)
                    result.success(null)
                }
                "cancelNotification" -> {
                    val service = CallNotificationService(this)
                    service.cancelNotification()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // Gérer les intents d'appel au démarrage
        handleIncomingCallIntent()
    }
    
    private fun handleIncomingCallIntent() {
        val intent = intent
        if (intent != null && intent.getStringExtra("type") == "call") {
            // Stocker les données d'appel pour Flutter
            val callData = mapOf(
                "callerId" to intent.getStringExtra("callerId"),
                "callerName" to intent.getStringExtra("callerName"),
                "isVideo" to intent.getBooleanExtra("isVideo", false),
                "isGroup" to intent.getBooleanExtra("isGroup", false),
                "roomId" to intent.getStringExtra("roomId"),
                "offer" to intent.getStringExtra("offer")
            )
            
            // Envoyer les données à Flutter via un canal
            val channel = MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, "com.example.talky/incoming_call")
            channel.invokeMethod("onIncomingCall", callData)
        }
    }

    private fun getContacts(): List<Map<String, Any?>> {
        val contacts = mutableListOf<Map<String, Any?>>()
        val contentResolver: ContentResolver = contentResolver
        
        val cursor: Cursor? = contentResolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            null,
            null,
            null,
            ContactsContract.Contacts.DISPLAY_NAME + " ASC"
        )

        cursor?.use {
            val idIndex = it.getColumnIndex(ContactsContract.Contacts._ID)
            val nameIndex = it.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME)

            while (it.moveToNext()) {
                val id = it.getString(idIndex)
                val name = it.getString(nameIndex) ?: "Inconnu"

                // Get phone numbers for this contact
                val phones = mutableListOf<String>()
                val phoneCursor = contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    null,
                    ContactsContract.CommonDataKinds.Phone.CONTACT_ID + " = ?",
                    arrayOf(id),
                    null
                )

                phoneCursor?.use { pc ->
                    val phoneIndex = pc.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    while (pc.moveToNext()) {
                        val phone = pc.getString(phoneIndex)
                        if (phone != null) {
                            phones.add(phone)
                        }
                    }
                }

                if (phones.isNotEmpty()) {
                    contacts.add(
                        mapOf(
                            "id" to id,
                            "displayName" to name,
                            "phones" to phones
                        )
                    )
                }
            }
        }

        return contacts
    }
}
