// lib/features/chat/presentation/chat_screen.dart
// Version Phase 3b — avec images, vocal, réponse, suppression

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/data/auth_providers.dart';
import '../data/chat_providers.dart';
//import '../data/chat_service.dart';
import '../data/media_service.dart';
import '../domain/message_model.dart';
import '../domain/conversation_model.dart';
import 'widgets/media_picker_sheet.dart';
import 'widgets/message_image_bubble.dart';
import 'widgets/voice_recorder_widget.dart';
import 'widgets/video_message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String contactName;
  final String? contactPhoto;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.contactName,
    this.contactPhoto,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  MessageModel? _replyTo;
  bool _isTyping    = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  void _markAsRead() {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    ref.read(chatServiceProvider).markAsRead(
      conversationId: widget.conversationId,
      userId: uid,
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    ref.read(sendMessageProvider.notifier).send(
      conversationId:  widget.conversationId,
      senderId:        user.uid,
      content:         text,
      replyToId:       _replyTo?.id,
      replyToContent:  _replyTo?.content,
    );

    _controller.clear();
    setState(() { _replyTo = null; _isTyping = false; });
    _scrollToBottom();
  }

  Future<void> _openMediaPicker() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final senderName = await ref.read(currentUserNameProvider.future);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MediaPickerSheet(
        conversationId: widget.conversationId,
        senderId:       user.uid,
        senderName:     senderName,
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages   = ref.watch(messagesProvider(widget.conversationId));
    final currentUid = ref.watch(authStateProvider).value?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // Liste messages
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Erreur: $e')),
              data:    (list) {
                if (list.isEmpty) return _EmptyChatState(name: widget.contactName);
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller:  _scrollCtrl,
                  padding:     const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount:   list.length,
                  itemBuilder: (_, i) {
                    final msg    = list[i];
                    final isMine = msg.senderId == currentUid;
                    final showDate = i == 0 ||
                        !_isSameDay(list[i - 1].sentAt, msg.sentAt);
                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.sentAt),
                        _buildMessageWidget(msg, isMine),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Barre de réponse
          if (_replyTo != null) _ReplyBar(
            message:  _replyTo!,
            onCancel: () => setState(() => _replyTo = null),
          ),

          // Enregistrement vocal OU barre de saisie
          if (_isRecording)
            VoiceRecorderWidget(
              onRecordingComplete: (path, duration) async {
                setState(() => _isRecording = false);
                // Upload + envoi
                final user = ref.read(authStateProvider).value;
                if (user == null) return;
                try {
                  final file = File(path);
                  final senderName =
                      await ref.read(currentUserNameProvider.future);
                  final url = await MediaService().uploadAudio(
                    file: file,
                    conversationId: widget.conversationId,
                  );
                  await ref.read(chatServiceProvider).sendMediaMessage(
                    conversationId: widget.conversationId,
                    senderId:       user.uid,
                    senderName:     senderName,
                    mediaUrl:       url,
                    type:           MessageType.audio,
                    mediaDuration:  duration,
                  );
                } catch (_) {}
              },
              onCancel: () => setState(() => _isRecording = false),
            )
          else
            _InputBar(
              controller: _controller,
              onSend:     _send,
              onAttach:   _openMediaPicker,
              onMicHold:  () => setState(() => _isRecording = true),
              onChanged:  (v) => setState(() => _isTyping = v.isNotEmpty),
              isTyping:   _isTyping,
            ),
        ],
      ),
    );
  }

  Widget _buildMessageWidget(MessageModel msg, bool isMine) {
    if (msg.isDeleted) {
      return _DeletedBubble(isMine: isMine);
    }

    switch (msg.type) {
      case MessageType.image:
        return MessageImageBubble(message: msg, isMine: isMine);
      case MessageType.audio:
        return VoiceMessageBubble(
          audioUrl:        msg.mediaUrl,
          durationSeconds: msg.mediaDuration,
          isMine:          isMine,
          sentAt:          msg.sentAt,
        );
      case MessageType.video:
        return VideoMessageBubble(message: msg, isMine: isMine);
      default:
        return _MessageBubble(
          message:  msg,
          isMine:   isMine,
          onReply:  () => setState(() => _replyTo = msg),
          onDelete: isMine ? () => _deleteMessage(msg) : null,
        );
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      backgroundColor: AppColors.surface,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      leadingWidth: 30,
      title: Row(
        children: [
          _AvatarWidget(name: widget.contactName, photoUrl: widget.contactPhoto),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.contactName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Text('En ligne',
                style: TextStyle(fontSize: 11, color: AppColors.accent)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.videocam_rounded), onPressed: () {}),
        IconButton(icon: const Icon(Icons.call_rounded), onPressed: () {}),
        IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: () {}),
      ],
    );
  }

  Future<void> _deleteMessage(MessageModel msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Supprimer le message'),
        content: const Text('Ce message sera supprimé pour tout le monde.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(chatServiceProvider).deleteMessage(
        conversationId: widget.conversationId,
        messageId:      msg.id,
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Message texte ──────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final VoidCallback onReply;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.onReply,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showOptions(context),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            gradient: isMine ? const LinearGradient(
              colors: [AppColors.primary, Color(0xFF9B7DFF)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ) : null,
            color: isMine ? null : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft:     const Radius.circular(18),
              topRight:    const Radius.circular(18),
              bottomLeft:  Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4, offset: const Offset(0, 2),
            )],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.replyToContent != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: const Border(
                          left: BorderSide(color: AppColors.accent, width: 3)),
                    ),
                    child: Text(message.replyToContent!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                Text(message.content ?? '',
                  style: TextStyle(
                    color: isMine ? Colors.white : AppColors.textPrimary,
                    fontSize: 15,
                  )),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(DateFormat('HH:mm').format(message.sentAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMine
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.textHint,
                      )),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      _StatusIcon(status: message.status),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
              title: const Text('Répondre'),
              onTap: () { Navigator.pop(context); onReply(); },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copier'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content ?? ''));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copié !')));
              },
            ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Supprimer',
                    style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); onDelete!(); },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Message supprimé ───────────────────────────────────────────────────
class _DeletedBubble extends StatelessWidget {
  final bool isMine;
  const _DeletedBubble({required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Text('🚫 Message supprimé',
          style: TextStyle(color: AppColors.textHint,
              fontStyle: FontStyle.italic, fontSize: 13)),
      ),
    );
  }
}

// ── Icône statut ───────────────────────────────────────────────────────
class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time_rounded, size: 12, color: Colors.white70);
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded, size: 12, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded, size: 12, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded, size: 12, color: AppColors.accent);
    }
  }
}

// ── Barre de réponse ───────────────────────────────────────────────────
class _ReplyBar extends StatelessWidget {
  final MessageModel message;
  final VoidCallback onCancel;

  const _ReplyBar({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(width: 3, height: 36,
              decoration: BoxDecoration(color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.senderName,
                  style: const TextStyle(color: AppColors.primary,
                      fontWeight: FontWeight.w600, fontSize: 12)),
                Text(message.content ?? '',
                  style: const TextStyle(color: AppColors.textSecondary,
                      fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onCancel),
        ],
      ),
    );
  }
}

// ── Barre de saisie ────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onMicHold;
  final ValueChanged<String> onChanged;
  final bool isTyping;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onMicHold,
    required this.onChanged,
    required this.isTyping,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            // Champ texte
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined,
                          color: AppColors.textHint),
                      onPressed: () {},
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        onChanged:  onChanged,
                        maxLines:   5, minLines: 1,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText:  'Message...',
                          hintStyle: TextStyle(color: AppColors.textHint),
                          border:    InputBorder.none,
                          isDense:   true,
                        ),
                      ),
                    ),
                    // Bouton pièce jointe
                    IconButton(
                      icon: const Icon(Icons.attach_file_rounded,
                          color: AppColors.textHint),
                      onPressed: onAttach,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Bouton envoyer / micro
            GestureDetector(
              onTap:      isTyping ? onSend : onMicHold,
              onLongPress: isTyping ? null : onMicHold,
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 8, offset: const Offset(0, 3),
                  )],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isTyping ? Icons.send_rounded : Icons.mic_rounded,
                    key: ValueKey(isTyping),
                    color: Colors.white, size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar ─────────────────────────────────────────────────────────────
class _AvatarWidget extends StatelessWidget {
  final String name;
  final String? photoUrl;
  const _AvatarWidget({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: photoUrl == null ? const LinearGradient(
          colors: [AppColors.primary, AppColors.accent]) : null,
        image: photoUrl != null ? DecorationImage(
            image: NetworkImage(photoUrl!), fit: BoxFit.cover) : null,
      ),
      child: photoUrl == null ? Center(
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.white,
              fontWeight: FontWeight.w700))) : null,
    );
  }
}

// ── Séparateur date ────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    String text;
    if (DateUtils.isSameDay(date, now)) text = "Aujourd'hui";
    else if (DateUtils.isSameDay(date, yesterday)) text = 'Hier';
    else text = DateFormat('d MMMM yyyy', 'fr').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(text, style: const TextStyle(
                color: AppColors.textHint, fontSize: 11,
                fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }
}

// ── État vide ──────────────────────────────────────────────────────────
class _EmptyChatState extends StatelessWidget {
  final String name;
  const _EmptyChatState({required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👋', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('Dites bonjour à $name !',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text("Aucun message pour l'instant.",
              style: TextStyle(color: AppColors.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}
