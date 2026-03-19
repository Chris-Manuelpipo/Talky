// lib/features/chat/presentation/chat_screen.dart
// Version Phase 3b — avec images, vocal, réponse, suppression

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../data/chat_providers.dart';
//import '../data/chat_service.dart';
import '../data/media_service.dart';
import '../domain/message_model.dart';
import '../domain/conversation_model.dart';
import 'chat_details_screen.dart';
import 'widgets/media_picker_sheet.dart';
import 'widgets/message_image_bubble.dart';
import 'widgets/voice_recorder_widget.dart';
import 'widgets/video_message_bubble.dart';
import '../../calls/data/call_providers.dart';
import '../../calls/presentation/call_screen.dart';

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

  Future<void> _openEmojiPicker() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmojiPicker(
        onSelect: (emoji) {
          Navigator.pop(context);
          _insertEmoji(emoji);
        },
      ),
    );
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    setState(() => _isTyping = newText.trim().isNotEmpty);
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
    final convos     = ref.watch(conversationsProvider);

    ref.listen(messagesProvider(widget.conversationId), (_, next) {
      final uid = ref.read(authStateProvider).value?.uid;
      if (uid == null) return;
      next.whenData((list) {
        final toRead = list
            .where((m) => m.senderId != uid && m.status != MessageStatus.read)
            .map((m) => m.id)
            .toList();
        // ignore: avoid_print
        print('[ChatScreen] toRead=${toRead.length} uid=$uid');
        if (toRead.isNotEmpty) {
          ref.read(chatServiceProvider).markMessagesReadByIds(
            conversationId: widget.conversationId,
            userId: uid,
            messageIds: toRead,
          );
        }
      });
    });

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: _buildAppBar(context, convos, currentUid),
      body: Column(
        children: [
          // Liste messages
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:   (e, _) => Center(child: Text('Erreur: $e')),
              data:    (list) {
                if (list.isEmpty) return _EmptyChatState(name: widget.contactName);
                
                // Déterminer si c'est un groupe
                final isGroup = convos.maybeWhen(
                  data: (convoList) {
                    final convo = convoList.firstWhere(
                      (c) => c.id == widget.conversationId,
                      orElse: () => ConversationModel(
                        id: widget.conversationId,
                        participantIds: const [],
                        participantNames: const {},
                        participantPhotos: const {},
                        unreadCount: const {},
                        lastMessageStatus: MessageStatus.sent,
                      ),
                    );
                    return convo.isGroup;
                  },
                  orElse: () => false,
                );
                
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
                        _buildMessageWidget(msg, isMine, isGroup),
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
              onEmoji:    _openEmojiPicker,
              onChanged:  (v) => setState(() => _isTyping = v.isNotEmpty),
              isTyping:   _isTyping,
            ),
        ],
      ),
    );
  }

  Widget _buildMessageWidget(MessageModel msg, bool isMine, bool isGroup) {
    if (msg.isDeleted) {
      return _DeletedBubble(isMine: isMine);
    }

    switch (msg.type) {
      case MessageType.image:
        return MessageImageBubble(message: msg, isMine: isMine, isGroup: isGroup);
      case MessageType.audio:
        return VoiceMessageBubble(
          audioUrl:        msg.mediaUrl,
          durationSeconds: msg.mediaDuration,
          isMine:          isMine,
          isGroup:         isGroup,
          senderName:      msg.senderName,
          sentAt:          msg.sentAt,
        );
      case MessageType.video:
        return VideoMessageBubble(message: msg, isMine: isMine, isGroup: isGroup);
      default:
        return _MessageBubble(
          message:  msg,
          isMine:   isMine,
          isGroup:  isGroup,
          onReply:  () => setState(() => _replyTo = msg),
          onDelete: isMine ? () => _deleteMessage(msg) : null,
        );
    }
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AsyncValue<List<ConversationModel>> convos,
    String currentUid,
  ) {
    final canPop = Navigator.of(context).canPop();
    final convo = convos.maybeWhen(
      data: (list) => list.firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => ConversationModel(
          id: widget.conversationId,
          participantIds: const [],
          participantNames: const {},
          participantPhotos: const {},
          unreadCount: const {},
          lastMessageStatus: MessageStatus.sent,
        ),
      ),
      orElse: () => null,
    );

    final isGroup = convo?.isGroup ?? false;
    final otherUserId = (convo == null || currentUid.isEmpty)
        ? null
        : convo.participantIds.firstWhere(
            (id) => id != currentUid,
            orElse: () => '',
          );
    final canCall = !isGroup && otherUserId != null && otherUserId.isNotEmpty;

    return AppBar(
      backgroundColor: context.appThemeColors.surface,
      automaticallyImplyLeading: false,
      leading: canPop
          ? IconButton(
              icon: Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      leadingWidth: 30,
      title: Row(
        children: [
          _AvatarWidget(name: widget.contactName, photoUrl: widget.contactPhoto),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.contactName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (isGroup)
                Text('Groupe',
                style: TextStyle(fontSize: 11, color: context.appThemeColors.textSecondary))
              else if (otherUserId != null && otherUserId.isNotEmpty)
                _PresenceText(userId: otherUserId)
              else
                Text('Hors ligne',
                style: TextStyle(fontSize: 11, color: context.appThemeColors.textSecondary)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.videocam_rounded),
          onPressed: canCall
              ? () => _startCallFromChat(
                  context,
                  otherUserId!,
                  isVideo: true,
                )
              : () => _showCallDisabled(context, isGroup),
        ),
        IconButton(
          icon: Icon(Icons.call_rounded),
          onPressed: canCall
              ? () => _startCallFromChat(
                  context,
                  otherUserId!,
                  isVideo: false,
                )
              : () => _showCallDisabled(context, isGroup),
        ),
        IconButton(
          icon: Icon(Icons.more_vert_rounded),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailsScreen(
                  conversationId: widget.conversationId,
                  contactName: widget.contactName,
                  contactPhoto: widget.contactPhoto,
                  contactUserId: otherUserId,
                  isGroup: isGroup,
                  conversation: convo,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showCallDisabled(BuildContext context, bool isGroup) {
    final msg = isGroup
        ? 'Appel de groupe non supporté'
        : 'Contact indisponible';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _startCallFromChat(
    BuildContext context,
    String targetUserId, {
    required bool isVideo,
  }) async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (micStatus.isPermanentlyDenied) {
        await openAppSettings();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission microphone refusée'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (isVideo) {
      final camStatus = await Permission.camera.request();
      if (!camStatus.isGranted) {
        if (camStatus.isPermanentlyDenied) {
          await openAppSettings();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission caméra refusée'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    final service = ref.read(callServiceProvider);
    if (!service.isConnected) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion au serveur en cours... Réessaie dans 5s'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      await ref.read(callProvider.notifier).startCall(
        targetUserId: targetUserId,
        targetName:   widget.contactName,
        targetPhoto:  widget.contactPhoto,
        isVideo:      isVideo,
      );

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CallScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur appel: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _deleteMessage(MessageModel msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.appThemeColors.surface,
        title: Text('Supprimer le message'),
        content: Text('Ce message sera supprimé pour tout le monde.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text('Supprimer',
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
  final bool isGroup;
  final VoidCallback onReply;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isGroup,
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
            color: isMine ? null : context.appThemeColors.surface,
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
                // Afficher le nom de l'expéditeur pour les messages de groupe
                if (!isMine && isGroup && message.senderName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                if (message.replyToContent != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                          left: BorderSide(color: AppColors.accent, width: 3)),
                    ),
                    child: Text(message.replyToContent!,
                      style: TextStyle(
                          fontSize: 12, color: context.appThemeColors.textSecondary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                Text(message.content ?? '',
                  style: TextStyle(
                    color: isMine ? Colors.white : context.appThemeColors.textPrimary,
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
                            : context.appThemeColors.textHint,
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
      backgroundColor: context.appThemeColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: context.appThemeColors.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.reply_rounded, color: AppColors.primary),
              title: Text('Répondre'),
              onTap: () { Navigator.pop(context); onReply(); },
            ),
            ListTile(
              leading: Icon(Icons.copy_rounded),
              title: Text('Copier'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content ?? ''));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copié !')));
              },
            ),
            if (onDelete != null)
              ListTile(
                leading: Icon(Icons.delete_rounded, color: Colors.red),
                title: Text('Supprimer',
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
    final colors = context.appThemeColors;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.deleted, color: colors.textHint, size: 16),
            const SizedBox(width: 6),
            Text('Message supprimé',
              style: TextStyle(color: colors.textHint,
                  fontStyle: FontStyle.italic, fontSize: 13)),
          ],
        ),
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
        return Icon(Icons.access_time_rounded, size: 12, color: Colors.white70);
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, size: 12, color: Colors.white70);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 12, color: Colors.white70);
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded, size: 12, color: AppColors.accent);
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
      color: context.appThemeColors.surface,
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
                  style: TextStyle(color: AppColors.primary,
                      fontWeight: FontWeight.w600, fontSize: 12)),
                Text(message.content ?? '',
                  style: TextStyle(color: context.appThemeColors.textSecondary,
                      fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
              icon: Icon(Icons.close_rounded, size: 18),
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
  final VoidCallback onEmoji;
  final ValueChanged<String> onChanged;
  final bool isTyping;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onMicHold,
    required this.onEmoji,
    required this.onChanged,
    required this.isTyping,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appThemeColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        child: Row(
          children: [
            // Champ texte
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.appThemeColors.inputFill,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.emoji_emotions_outlined,
                          color: context.appThemeColors.textHint),
                      onPressed: onEmoji,
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        onChanged:  onChanged,
                        maxLines:   5, minLines: 1,
                        style: TextStyle(color: context.appThemeColors.textPrimary),
                        decoration: InputDecoration(
                          hintText:  'Message...',
                          hintStyle: TextStyle(color: context.appThemeColors.textHint),
                          border:    InputBorder.none,
                          isDense:   true,
                        ),
                      ),
                    ),
                    // Bouton pièce jointe
                    IconButton(
                      icon: Icon(Icons.attach_file_rounded,
                          color: context.appThemeColors.textHint),
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
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return Container(
      width: 38, height: 38,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Emoji picker (stickers simples) ────────────────────────────────────
class _EmojiPicker extends StatelessWidget {
  final ValueChanged<String> onSelect;
  const _EmojiPicker({required this.onSelect});
  //KILO don't touch these _emojis
  static const _emojis = [
  // === Visages et émotions (ajouts récents et variantes) ===
  '😀','😁','😂','🤣','😊','😍','😘','😎','🤩','🥳',
  '😇','🙂','🙃','😉','😌','😜','🤪','😢','😭','😡',
  '😤','😱','🥶','🥵','🤯','😴','🤔','🤫','🤐','😬',
  '😐','😑','😶','😏','😒','🙄','😬','🤥','😌','😔',
  '😪','🤤','😴','😷','🤒','🤕','🤢','🤮','🤧','🥴',
  '🤠','🥱','😎','🤓','🧐','😕','😟','🙁','☹️','😮',
  '😯','😲','😳','🥺','😦','😧','😨','😰','😥','😓',
  '🤗','🤔','🤭','🤫','🤥','😶','😐','😑','😬','🙄',
  '🥹','🫠','🫡','🫢','🫣','🫤','🥸','🤐','🫥','🫨',

  // === Gestes et parties du corps (avec variantes récentes) ===
  '👍','👎','👏','🙏','🤝','💪','✌️','🤟','🤘','👌',
  '🤞','🤙','👈','👉','👆','👇','☝️','👊','👋','🤚',
  '🖐️','✋','👌','🤏','🫶','🤲','🙌','👐','🤝','🙏',
  '💅','👄','👅','👂','👃','👣','🧠','🫀','🫁','🦷',
  '🦴','👀','👁️','🫵','🫱','🫲','🫳','🫴','🫸','🫹',
  '🫷','🫸','🫲','🫱','🫳','🫴','🫶','🫰','🫱','🫲',
  '🫳','🫴','🫵','🫶','🫷','🫸',

  // === Animaux et nature (nouveaux + existants) ===
  '🐶','🐱','🐻','🐼','🐨','🐯','🦁','🐸','🐵','🐧',
  '🐦','🐤','🐣','🐥','🐺','🐗','🐴','🦄','🐝','🐛',
  '🦋','🐌','🐞','🐜','🦟','🦗','🕷️','🕸️','🦂','🐢',
  '🐍','🦎','🐙','🦑','🦐','🦞','🐠','🐟','🐡','🐬',
  '🐳','🐋','🦈','🐊','🐅','🐆','🦓','🦍','🦧','🦣',
  '🐘','🦏','🐪','🐫','🦒','🦘','🐃','🐂','🐄','🐎',
  '🐖','🐏','🐑','🐐','🦌','🐕','🐩','🐈','🐓','🦃',
  '🦤','🦚','🦜','🦢','🦩','🐇','🦝','🦨','🦡','🦫',
  '🦆','🦅','🦉','🦇','🐿️','🦔','🦊','🦦','🦥','🪿',
  '🦫','🦡','🦨','🦝','🐁','🐀','🐿️','🦔','🦇','🐦‍⬛',
  '🕊️','🦃','🦤','🦩','🦢','🦚','🦜','🦆','🦅','🦉',
  '🪹','🪺','🌱','🌿','☘️','🍀','🍁','🍂','🍃','🌾',
  '🌺','🌻','🌼','🌸','🌷','🌹','🥀','🪷','🌲','🌳',
  '🌴','🌵','🎍','🎋','🪴','🌿','🍀','🌱','🌿','🍃',

  // === Nourriture et boissons (complément) ===
  '🍕','🍔','🍟','🌭','🥗','🍣','🍩','🍪','🍫','🍰',
  '🍎','🍏','🍊','🍋','🍌','🍉','🍇','🍓','🫐','🍒',
  '🍑','🥭','🍍','🥥','🥝','🍅','🍆','🥑','🥦','🥬',
  '🥒','🌶️','🫑','🌽','🥕','🫒','🧄','🧅','🥔','🍠',
  '🥐','🥯','🍞','🥖','🥨','🧀','🥚','🍳','🧈','🥞',
  '🧇','🥓','🥩','🍗','🍖','🦴','🌮','🌯','🫔','🥙',
  '🧆','🥚','🍲','🫕','🥣','🥗','🍿','🧈','🧂','🥤',
  '🧃','🧉','🧊','🍺','🍻','🥂','🍷','🥃','🍸','🍹',
  '🥮','🍡','🍢','🍥','🥟','🥠','🥡','🦪','🍲','🥘',
  '🍛','🍜','🍝','🍠','🍯','🥛','☕','🍵','🍶','🍾',
  '🍴','🥄','🔪','🏺','🍽️',

  // === Sports et activités (nouveaux) ===
  '⚽','🏀','🏈','🎮','🎧','🎵','🎬','📷','✈️','🚗',
  '🏀','⚾','🥎','🏐','🏉','🎾','🥏','🎳','🏏','🏑',
  '🏒','🥍','🏓','🏸','🥊','🥋','🥅','⛳','🏹','🎣',
  '🤿','🥌','🛹','🛼','🛷','⛸️','🥌','🎿','🏂','🪂',
  '🏌️','🏌️‍♂️','🏌️‍♀️','🏄','🏄‍♂️','🏄‍♀️','🏊','🏊‍♂️','🏊‍♀️','⛹️',
  '⛹️‍♂️','⛹️‍♀️','🏋️','🏋️‍♂️','🏋️‍♀️','🚴','🚴‍♂️','🚴‍♀️','🚵','🚵‍♂️',
  '🚵‍♀️','🤸','🤸‍♂️','🤸‍♀️','🤼','🤼‍♂️','🤼‍♀️','🤽','🤽‍♂️','🤽‍♀️',
  '🤾','🤾‍♂️','🤾‍♀️','🤹','🤹‍♂️','🤹‍♀️','🧘','🧘‍♂️','🧘‍♀️','🪁',

  // === Voyage et lieux (complément) ===
  '🏡','🌍','✈️','🚗','🚲','🏍️','🚂','🚢','⛵','🛸',
  '🚀','🛰️','🏖️','🏝️','🏜️','🏔️','⛰️','🌋','🏕️',
  '🏞️','🏟️','🏛️','🏗️','🏘️','🏚️','🏠','🏡','🏢',
  '🏣','🏤','🏥','🏦','🏨','🏩','🏪','🏫','🏬','🏭',
  '🏮','🏯','🏰','💒','🗼','🗽','⛲','⛪','🕌','🕍',
  '⛩️','🕋','⛺','🌁','🌃','🌄','🌅','🌆','🌇','🌉',
  '🌌','🗿','🛕','🕍','⛩️',

  // === Objets et symboles (très complet) ===
  '🔥','✨','🎉','💯','💥','⭐','🌈','⚡','☀️','🌙',
  '❤️','💔','💙','💚','💛','🧡','💜','🤍','🤎','🖤',
  '💋','💌','💘','💝','💖','💗','💓','💞','💕','💟',
  '💤','💢','💣','💥','💦','💨','💫','💬','🗨️','🗯️',
  '🕳️','💭','💠','🔮','🧿','🪬','💈','⚗️','🔭','🔬',
  '🕯️','💡','🔦','🏮','📔','📕','📗','📘','📙','📚',
  '📖','🔖','🧷','🔗','📎','🖇️','📐','📏','🧮','📌',
  '📍','✂️','🖊️','🖋️','✒️','🖌️','🖍️','📝','📁','📂',
  '🗂️','📅','📆','🗒️','🗓️','📇','📈','📉','📊','📋',
  '📌','📍','📎','🖇️','📏','📐','✂️','🔒','🔓','🔏',
  '🔐','🔑','🗝️','🔨','🪓','⛏️','⚒️','🛠️','🔧','🔩',
  '⚙️','🗜️','⚖️','🦯','🔗','⛓️','🧰','🧲','⚗️','🧪',
  '🧫','🧬','🔬','🔭','📡','💉','🩸','💊','🩹','🩺',
  '📿','💎','⚜️','🔱','📛','🔰','⭕','✅','❌','❎',
  '➕','➖','➗','✖️','♾️','‼️','⁉️','❓','❔','❕',
  '❗','〰️','➰','➿','🔴','🟠','🟡','🟢','🔵','🟣',
  '🟤','⚫','⚪','🟥','🟧','🟨','🟩','🟦','🟪','🟫',
  '⬛','⬜','🔶','🔷','🔸','🔹','🔺','🔻','💠','🔘',
  '🔲','🔳','⚪','⚫',

  // === Drapeaux (sélection étendue) ===
  '🏁','🚩','🎌','🏴','🏳️','🏳️‍🌈','🏳️‍⚧️','🇫🇷','🇬🇧','🇺🇸',
  '🇨🇳','🇯🇵','🇩🇪','🇮🇹','🇪🇸','🇵🇹','🇳🇱','🇧🇪','🇨🇦','🇧🇷',
  '🇷🇺','🇮🇳','🇦🇺','🇳🇿','🇿🇦','🇪🇬','🇸🇦','🇦🇪','🇮🇱','🇹🇷',
  '🇬🇷','🇸🇪','🇳🇴','🇩🇰','🇫🇮','🇮🇸','🇮🇪','🇨🇭','🇦🇹','🇵🇱',
  '🇨🇿','🇭🇺','🇸🇰','🇸🇮','🇭🇷','🇷🇸','🇧🇬','🇷🇴','🇲🇩','🇺🇦',
  '🇧🇾','🇱🇹','🇱🇻','🇪🇪','🇦🇲','🇬🇪','🇦🇿','🇰🇿','🇺🇿','🇹🇲',
  '🇰🇬','🇹🇯','🇦🇫','🇵🇰','🇧🇩','🇱🇰','🇳🇵','🇧🇹','🇲🇲','🇹🇭',
  '🇱🇦','🇻🇳','🇰🇭','🇲🇾','🇸🇬','🇵🇭','🇮🇩','🇹🇱','🇰🇷','🇰🇵',
  '🇲🇳','🇯🇴','🇱🇧','🇸🇾','🇮🇶','🇮🇷','🇰🇼','🇧🇭','🇶🇦','🇴🇲',
  '🇾🇪','🇩🇿','🇲🇦','🇹🇳','🇱🇾','🇸🇩','🇪🇷','🇩🇯','🇸🇴','🇪🇹',
  '🇰🇪','🇹🇿','🇺🇬','🇷🇼','🇧🇮','🇲🇿','🇿🇲','🇲🇼','🇿🇼','🇧🇼',
  '🇳🇦','🇿🇦','🇱🇸','🇸🇿','🇰🇲','🇲🇬','🇸🇨','🇲🇺','🇨🇻','🇸🇹',
  '🇬🇼','🇬🇶','🇬🇦','🇨🇬','🇨🇩','🇦🇴','🇳🇬','🇬🇭','🇨🇮','🇱🇷',
  '🇸🇱','🇬🇳','🇸🇳','🇬🇲','🇲🇱','🇧🇫','🇳🇪','🇹🇩','🇨🇲','🇨🇫',
  '🇬🇶','🇬🇦','🇨🇬','🇨🇩','🇷🇼','🇧🇮','🇺🇬','🇰🇪','🇹🇿','🇲🇿',
  '🇲🇼','🇿🇲','🇿🇼','🇧🇼','🇳🇦','🇿🇦','🇸🇿','🇱🇸','🇰🇲','🇲🇬',
  '🇸🇨','🇲🇺','🇨🇻','🇸🇹','🇬🇼','🇬🇶','🇬🇦','🇨🇬','🇨🇩','🇦🇴',
  '🇳🇬','🇬🇭','🇨🇮','🇱🇷','🇸🇱','🇬🇳','🇸🇳','🇬🇲','🇲🇱','🇧🇫',
  '🇳🇪','🇹🇩','🇨🇲','🇨🇫','🇬🇶','🇬🇦','🇨🇬','🇨🇩','🇷🇼','🇧🇮',
  '🇺🇬','🇰🇪','🇹🇿','🇲🇿','🇲🇼','🇿🇲','🇿🇼','🇧🇼','🇳🇦','🇿🇦',
  '🇸🇿','🇱🇸','🇰🇲','🇲🇬','🇸🇨','🇲🇺','🇨🇻','🇸🇹','🇬🇼','🇬🇶',
  '🇬🇦','🇨🇬','🇨🇩','🇦🇴',

  // === Personnes et rôles (famille, métiers, etc.) ===
  '👶','🧒','👦','👧','🧑','👨','👩','🧓','👴','👵',
  '👨‍⚕️','👩‍⚕️','👨‍🎓','👩‍🎓','👨‍🏫','👩‍🏫','👨‍⚖️','👩‍⚖️','👨‍🌾','👩‍🌾',
  '👨‍🍳','👩‍🍳','👨‍🔧','👩‍🔧','👨‍🏭','👩‍🏭','👨‍💼','👩‍💼','👨‍🔬','👩‍🔬',
  '👨‍💻','👩‍💻','👨‍🎤','👩‍🎤','👨‍🎨','👩‍🎨','👨‍✈️','👩‍✈️','👨‍🚀','👩‍🚀',
  '👨‍🚒','👩‍🚒','👮','👮‍♂️','👮‍♀️','🕵️','🕵️‍♂️','🕵️‍♀️','💂','💂‍♂️',
  '💂‍♀️','👷','👷‍♂️','👷‍♀️','🤴','👸','👳','👳‍♂️','👳‍♀️','👲',
  '🧕','🤵','🤵‍♂️','🤵‍♀️','👰','👰‍♂️','👰‍♀️','🤰','🤱','👩‍🍼',
  '👨‍🍼','🧑‍🍼','👼','🎅','🤶','🧑‍🎄','🦸','🦸‍♂️','🦸‍♀️','🦹',
  '🦹‍♂️','🦹‍♀️','🧙','🧙‍♂️','🧙‍♀️','🧚','🧚‍♂️','🧚‍♀️','🧛','🧛‍♂️',
  '🧛‍♀️','🧜','🧜‍♂️','🧜‍♀️','🧝','🧝‍♂️','🧝‍♀️','🧞','🧞‍♂️','🧞‍♀️',
  '🧟','🧟‍♂️','🧟‍♀️','💆','💆‍♂️','💆‍♀️','💇','💇‍♂️','💇‍♀️','🚶',
  '🚶‍♂️','🚶‍♀️','🧍','🧍‍♂️','🧍‍♀️','🧎','🧎‍♂️','🧎‍♀️','🏃','🏃‍♂️',
  '🏃‍♀️','💃','🕺','👯','👯‍♂️','👯‍♀️','🧖','🧖‍♂️','🧖‍♀️','🧗',
  '🧗‍♂️','🧗‍♀️','🤺','🏇','⛷️','🏂','🏌️','🏌️‍♂️','🏌️‍♀️','🏄',
  '🏄‍♂️','🏄‍♀️','🚣','🚣‍♂️','🚣‍♀️','🏊','🏊‍♂️','🏊‍♀️','⛹️','⛹️‍♂️',
  '⛹️‍♀️','🏋️','🏋️‍♂️','🏋️‍♀️','🚴','🚴‍♂️','🚴‍♀️','🚵','🚵‍♂️','🚵‍♀️',
  '🤸','🤸‍♂️','🤸‍♀️','🤼','🤼‍♂️','🤼‍♀️','🤽','🤽‍♂️','🤽‍♀️','🤾',
  '🤾‍♂️','🤾‍♀️','🤹','🤹‍♂️','🤹‍♀️','🧘','🧘‍♂️','🧘‍♀️','🛀','🛌',

  // === Vêtements et accessoires ===
  '🧥','🧦','🧤','🧣','👚','👕','👖','👔','👗','👘',
  '🥻','🩳','👙','🩱','🩲','🩳','👠','👡','👢','👞',
  '👟','🥾','🥿','🧦','🧢','🎩','🎓','🧳','👝','👛',
  '👜','💼','🎒','👓','🕶️','🥽','🥼','🦺','👔','👕',

  // === Musique, arts, technologie ===
  '🎵','🎶','🎼','🎤','🎧','🎷','🎺','🎸','🎻','🪕',
  '🥁','🎹','📻','📺','📱','📲','☎️','📞','📟','📠',
  '🔋','🔌','💻','🖥️','🖨️','⌨️','🖱️','🖲️','💽','💾',
  '💿','📀','🎥','🎞️','📽️','🎬','📷','📸','📹','📼',
  '🔍','🔎','🕯️','💡','🔦','🏮','📔','📕','📗','📘',
  '📙','📚','📖','🔖','🧷','🔗','📎','🖇️','📐','📏',
  '🧮','📌','📍','✂️','🖊️','🖋️','✒️','🖌️','🖍️','📝',

  // === Nature, météo, astres (complément) ===
  '🌞','🌝','🌚','🌛','🌜','🌙','🌖','🌗','🌘','🌑',
  '🌒','🌓','🌔','🌕','🌖','🌗','🌘','🌙','🌚','🌛',
  '🌜','☀️','🌤️','⛅','🌥️','🌦️','🌧️','🌨️','🌩️','🌪️',
  '🌫️','🌬️','🌀','🌈','🌂','☂️','☔','⛱️','⚡','❄️',
  '☃️','⛄','🔥','💧','🌊','🌫️','🌬️','☀️','🌤️','⛅',

  // === Horloges et temps ===
  '🕐','🕑','🕒','🕓','🕔','🕕','🕖','🕗','🕘','🕙',
  '🕚','🕛','🕜','🕝','🕞','🕟','🕠','🕡','🕢','🕣',
  '🕤','🕥','🕦','🕧','⌚','⏰','⏱️','⏲️','🕰️','⌛',
  '⏳',

  // === Divers (objets du quotidien) ===
  '🛒','🛍️','🎁','🎈','🎉','🎊','🎄','🎃','🎆','🎇',
  '🧨','✨','💥','💫','💦','💨','🕳️','💬','🗯️','💭',
  '💤','💢','💣','💥','💧','💨','🕳️','🪑','🛏️','🛋️',
  '🪜','🧰','🧲','🧪','🧫','🧬','🔬','🔭','📡','💉',
  '🩸','💊','🩹','🩺','🚽','🚿','🛁','🧴','🧷','🧹',
  '🧺','🧻','🧼','🧽','🧯','🛒','🛍️','🎁','🎈','🎉',
  '🎊','🎄','🎃','🎆','🎇','🧨','✨','💥','💫','💦',
  '💨','🕳️','💬','🗯️','💭','💤','💢','💣','💥','💧',
  '💨','🕳️','🪑','🛏️','🛋️','🪜','🧰','🧲','🧪','🧫',
  '🧬','🔬','🔭','📡','💉','🩸','💊','🩹','🩺','🚽',
  '🚿','🛁','🧴','🧷','🧹','🧺','🧻','🧼','🧽','🧯',
  '🪔','🪙','🪣','🪤','🪥','🪦','🪧','🪨','🪩','🪪',
  '🪫','🪬','🪭','🪮','🪯'
];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appThemeColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxH = constraints.maxHeight;
            final height = maxH.isFinite ? maxH * 0.6 : 360.0;
            return SizedBox(
              height: height,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appThemeColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Stickers (emojis)',
                    style: TextStyle(
                      color: context.appThemeColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    )),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: _emojis.length,
                      itemBuilder: (_, i) {
                        final emoji = _emojis[i];
                        return GestureDetector(
                          onTap: () => onSelect(emoji),
                          child: Center(
                            child: Text(
                              emoji,
                              style: TextStyle(fontSize: 24),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Présence utilisateur ──────────────────────────────────────────────
class _PresenceText extends StatelessWidget {
  final String userId;
  const _PresenceText({required this.userId});

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);

    if (date == today) {
      return 'Aujourd\'hui à ${DateFormat('HH:mm').format(lastSeen)}';
    }
    if (date == yesterday) {
      return 'Hier à ${DateFormat('HH:mm').format(lastSeen)}';
    }
    return 'Vu le ${DateFormat('dd/MM/yyyy HH:mm').format(lastSeen)}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final isOnline = data?['isOnline'] == true;
        final lastSeenTs = data?['lastSeen'];
        DateTime? lastSeen;
        if (lastSeenTs is Timestamp) {
          lastSeen = lastSeenTs.toDate();
        }

        if (isOnline) {
          return Text('En ligne',
            style: TextStyle(fontSize: 11, color: AppColors.accent));
        }

        if (lastSeen != null) {
          return Text(_formatLastSeen(lastSeen),
            style: TextStyle(fontSize: 11, color: context.appThemeColors.textSecondary));
        }

        return Text('Hors ligne',
          style: TextStyle(fontSize: 11, color: context.appThemeColors.textSecondary));
      },
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
          Expanded(child: Divider(color: context.appThemeColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(text, style: TextStyle(
                color: context.appThemeColors.textHint, fontSize: 11,
                fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Divider(color: context.appThemeColors.divider)),
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
    final colors = context.appThemeColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(AppIcons.waving, size: 48, color: colors.textHint),
          const SizedBox(height: 12),
          Text('Dites bonjour à $name !',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text("Aucun message pour l'instant.",
              style: TextStyle(color: colors.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}
