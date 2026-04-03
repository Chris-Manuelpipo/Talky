package com.example.talky

import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL        = "com.example.talky/contacts"
    private val CALL_CHANNEL   = "com.example.talky/call_notification"
    private val CALL_ACTION_CH = "com.example.talky/call_action"

    // Stocker un intent arrivé AVANT que Flutter soit prêt
    private var pendingCallAction: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Canal contacts ────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getContacts") {
                    result.success(getContacts())
                } else {
                    result.notImplemented()
                }
            }

        // ── Canal notifications d'appel (depuis Flutter → natif) ──────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showIncomingCall" -> {
                        val data = call.arguments as? Map<String, Any?> ?: emptyMap()
                        CallNotificationService(this).showIncomingCallNotification(data)
                        result.success(null)
                    }
                    "cancelNotification" -> {
                        CallNotificationService(this).cancelNotification()
                        // Fermer aussi IncomingCallActivity si elle est visible
                        sendBroadcast(Intent(IncomingCallActivity.ACTION_DISMISS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Canal actions d'appel (natif → Flutter) ───────────────────
        // Flutter s'abonne à ce canal pour savoir si l'utilisateur a
        // répondu ou refusé depuis l'écran natif (lock screen)
        val callActionChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CALL_ACTION_CH
        )

        // Si un intent est arrivé avant que Flutter soit prêt, l'envoyer maintenant
        pendingCallAction?.let { pending ->
            dispatchCallAction(callActionChannel, pending)
            pendingCallAction = null
        }

        // Stocker le channel pour les intents futurs (onNewIntent)
        _callActionChannel = callActionChannel
    }

    // Appelé quand MainActivity est déjà en vie et reçoit un nouvel intent
    // (cas : IncomingCallActivity appelle startActivity avec FLAG_SINGLE_TOP)
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val channel = _callActionChannel
        if (channel != null) {
            dispatchCallAction(channel, intent)
        } else {
            // Flutter pas encore prêt — mettre en attente
            pendingCallAction = intent
        }
    }

    private var _callActionChannel: MethodChannel? = null

    private fun dispatchCallAction(channel: MethodChannel, intent: Intent) {
        when (intent.action) {
            "ANSWER_CALL" -> {
                val args = mapOf(
                    "action"   to "answer",
                    "callerId" to (intent.getStringExtra("callerId") ?: ""),
                    "roomId"   to (intent.getStringExtra("roomId") ?: ""),
                    "isGroup"  to intent.getBooleanExtra("isGroup", false)
                )
                channel.invokeMethod("onCallAction", args)
            }
            "REJECT_CALL" -> {
                val args = mapOf(
                    "action"   to "reject",
                    "callerId" to (intent.getStringExtra("callerId") ?: ""),
                    "roomId"   to (intent.getStringExtra("roomId") ?: ""),
                    "isGroup"  to intent.getBooleanExtra("isGroup", false)
                )
                channel.invokeMethod("onCallAction", args)
            }
        }
    }

    // ── Contacts ──────────────────────────────────────────────────────
    private fun getContacts(): List<Map<String, Any?>> {
        val contacts = mutableListOf<Map<String, Any?>>()
        val contentResolver: ContentResolver = contentResolver

        val cursor: Cursor? = contentResolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            null, null, null,
            ContactsContract.Contacts.DISPLAY_NAME + " ASC"
        )

        cursor?.use {
            val idIndex   = it.getColumnIndex(ContactsContract.Contacts._ID)
            val nameIndex = it.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME)

            while (it.moveToNext()) {
                val id   = it.getString(idIndex)
                val name = it.getString(nameIndex) ?: "Inconnu"

                val phones    = mutableListOf<String>()
                val phoneCursor = contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    null,
                    ContactsContract.CommonDataKinds.Phone.CONTACT_ID + " = ?",
                    arrayOf(id), null
                )
                phoneCursor?.use { pc ->
                    val phoneIndex =
                        pc.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    while (pc.moveToNext()) {
                        val phone = pc.getString(phoneIndex)
                        if (phone != null) phones.add(phone)
                    }
                }

                if (phones.isNotEmpty()) {
                    contacts.add(mapOf(
                        "id"          to id,
                        "displayName" to name,
                        "phones"      to phones
                    ))
                }
            }
        }
        return contacts
    }
}