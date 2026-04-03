package com.example.talky

import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class IncomingCallActivity : AppCompatActivity() {

    companion object {
        const val ACTION_DISMISS = "com.example.talky.DISMISS_INCOMING_CALL"

        fun createIntent(context: Context, data: Map<String, Any?>): Intent {
            return Intent(context, IncomingCallActivity::class.java).apply {
                putExtra("callerId", data["callerId"] as? String)
                putExtra("callerName", data["callerName"] as? String)
                putExtra("isVideo", data["isVideo"] as? Boolean ?: false)
                putExtra("isGroup", data["isGroup"] as? Boolean ?: false)
                putExtra("roomId", data["roomId"] as? String)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
            }
        }
    }

    // Reçoit l'ordre de fermeture depuis MainActivity (ex: appelant raccoche)
    private val dismissReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Allumer l'écran et afficher par-dessus le lock screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            km.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        super.onCreate(savedInstanceState)

        val callerName = intent.getStringExtra("callerName") ?: "Appel entrant"
        val isVideo    = intent.getBooleanExtra("isVideo", false)
        val isGroup    = intent.getBooleanExtra("isGroup", false)
        val callerId   = intent.getStringExtra("callerId") ?: ""
        val roomId     = intent.getStringExtra("roomId") ?: ""

        val callTypeLabel = when {
            isGroup && isVideo -> "Appel vidéo de groupe"
            isGroup            -> "Appel audio de groupe"
            isVideo            -> "Appel vidéo entrant"
            else               -> "Appel audio entrant"
        }

        // ── UI native simple ──────────────────────────────────────────
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#0D0D1A"))
        }

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity     = Gravity.CENTER
        }

        // Texte type appel
        val typeView = TextView(this).apply {
            text      = callTypeLabel
            textSize  = 16f
            setTextColor(Color.parseColor("#AAAAAA"))
            gravity   = Gravity.CENTER
        }

        // Avatar initiale
        val initial = if (callerName.isNotEmpty()) callerName[0].uppercaseChar().toString() else "?"
        val avatarContainer = FrameLayout(this).apply {
            val size = (130 * resources.displayMetrics.density).toInt()
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                topMargin    = (24 * resources.displayMetrics.density).toInt()
                bottomMargin = (24 * resources.displayMetrics.density).toInt()
                gravity      = Gravity.CENTER_HORIZONTAL
            }
            background = resources.getDrawable(android.R.drawable.btn_default, null)
            background?.setTint(Color.parseColor("#6C63FF"))
            clipToOutline = true
        }
        val initialView = TextView(this).apply {
            text      = initial
            textSize  = 52f
            setTextColor(Color.WHITE)
            gravity   = Gravity.CENTER
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
        avatarContainer.addView(initialView)

        // Nom appelant
        val nameView = TextView(this).apply {
            text      = callerName
            textSize  = 32f
            setTextColor(Color.WHITE)
            setTypeface(null, android.graphics.Typeface.BOLD)
            gravity   = Gravity.CENTER
        }

        // Sous-titre
        val subtitleView = TextView(this).apply {
            text      = if (isVideo) "Vidéo" else "Audio"
            textSize  = 16f
            setTextColor(Color.parseColor("#AAAAAA"))
            gravity   = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = (8 * resources.displayMetrics.density).toInt() }
        }

        content.addView(typeView)
        content.addView(avatarContainer)
        content.addView(nameView)
        content.addView(subtitleView)

        // ── Boutons Refuser / Répondre ────────────────────────────────
        val buttonsRow = LinearLayout(this).apply {
            orientation  = LinearLayout.HORIZONTAL
            gravity      = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin    = (60 * resources.displayMetrics.density).toInt()
                bottomMargin = (60 * resources.displayMetrics.density).toInt()
            }
        }

        val dp = resources.displayMetrics.density
        val btnSize = (72 * dp).toInt()
        val btnMargin = (40 * dp).toInt()

        // Bouton Refuser
        val rejectBtn = buildCircleButton(
            iconRes    = android.R.drawable.ic_menu_close_clear_cancel,
            color      = Color.RED,
            size       = btnSize,
            marginEnd  = btnMargin,
            label      = "Refuser"
        ) {
            // Notifier Flutter que l'appel est refusé
            sendCallActionToMain(callerId, roomId, isGroup, accepted = false)
            finish()
        }

        // Bouton Répondre
        val answerBtn = buildCircleButton(
            iconRes    = android.R.drawable.ic_menu_call,
            color      = Color.parseColor("#00C851"),
            size       = btnSize,
            marginEnd  = 0,
            label      = "Répondre"
        ) {
            // Ouvrir MainActivity avec les données d'appel → socket déjà prêt
            sendCallActionToMain(callerId, roomId, isGroup, accepted = true)
            finish()
        }

        buttonsRow.addView(rejectBtn)
        buttonsRow.addView(answerBtn)
        content.addView(buttonsRow)

        root.addView(content, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ).apply { gravity = Gravity.CENTER })

        setContentView(root)

        // Écouter la commande de fermeture (appelant raccroche)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(dismissReceiver, IntentFilter(ACTION_DISMISS),
                RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(dismissReceiver, IntentFilter(ACTION_DISMISS))
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(dismissReceiver) } catch (_: Exception) {}
    }

    // Empêcher le retour arrière (ne pas rejeter l'appel accidentellement)
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Ne rien faire
    }

    private fun sendCallActionToMain(
        callerId: String,
        roomId: String,
        isGroup: Boolean,
        accepted: Boolean
    ) {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = if (accepted) "ANSWER_CALL" else "REJECT_CALL"
            putExtra("callerId", callerId)
            putExtra("roomId", roomId)
            putExtra("isGroup", isGroup)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
        }
        startActivity(intent)
    }

    // ── Builder bouton circulaire ─────────────────────────────────────
    private fun buildCircleButton(
        iconRes:   Int,
        color:     Int,
        size:      Int,
        marginEnd: Int,
        label:     String,
        onClick:   () -> Unit
    ): LinearLayout {
        val dp      = resources.displayMetrics.density
        val wrapper = LinearLayout(this).apply {
            orientation  = LinearLayout.VERTICAL
            gravity      = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { rightMargin = marginEnd }
        }

        val circle = FrameLayout(this).apply {
            layoutParams = LinearLayout.LayoutParams(size, size).apply {
                bottomMargin = (12 * dp).toInt()
            }
            setBackgroundColor(color)
            // Rendre circulaire via clipToOutline + background shape
            outlineProvider = object : android.view.ViewOutlineProvider() {
                override fun getOutline(view: android.view.View, outline: android.graphics.Outline) {
                    outline.setOval(0, 0, view.width, view.height)
                }
            }
            clipToOutline = true
            isClickable     = true
            isFocusable     = true
            setOnClickListener { onClick() }
        }

        val icon = ImageView(this).apply {
            setImageResource(iconRes)
            setColorFilter(Color.WHITE)
            layoutParams = FrameLayout.LayoutParams(
                (32 * dp).toInt(), (32 * dp).toInt(), Gravity.CENTER
            )
        }
        circle.addView(icon)

        val labelView = TextView(this).apply {
            text = label
            textSize = 14f
            setTextColor(Color.parseColor("#CCCCCC"))
            gravity = Gravity.CENTER
        }

        wrapper.addView(circle)
        wrapper.addView(labelView)
        return wrapper
    }
}