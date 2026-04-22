// lib/features/chat/presentation/chat_screen.dart

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/data/backend_user_providers.dart';
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
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  MessageModel? _replyTo;
  bool _isTyping = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  void _markAsRead() {
    final uid = ref.read(currentAlanyaIDStringProvider);
    if (uid.isEmpty) return;
    ref.read(chatServiceProvider).markAsRead(
          conversationId: widget.conversationId,
          userId: uid,
        );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final uid = ref.read(currentAlanyaIDStringProvider);
    if (uid.isEmpty) return;

    ref.read(sendMessageProvider.notifier).send(
          conversationId: widget.conversationId,
          senderId: uid,
          content: text,
          replyToId: _replyTo?.id,
          replyToContent: _replyTo?.content,
        );

    _controller.clear();
    setState(() {
      _replyTo = null;
      _isTyping = false;
    });
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
    final uid = ref.read(currentAlanyaIDStringProvider);
    if (uid.isEmpty) return;
    final senderName = await ref.read(currentUserNameProvider.future);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MediaPickerSheet(
        conversationId: widget.conversationId,
        senderId: uid,
        senderName: senderName,
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
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final currentUid = ref.watch(currentAlanyaIDStringProvider);
    final convos = ref.watch(conversationsProvider);

    ref.listen(messagesProvider(widget.conversationId), (_, next) {
      final uid = ref.read(currentAlanyaIDStringProvider);
      if (uid.isEmpty) return;
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
    final otherId = (convo == null || currentUid.isEmpty)
        ? ''
        : convo.participantIds.firstWhere(
            (id) => id != currentUid,
            orElse: () => '',
          );
    final contactsService = ref.read(phoneContactsServiceProvider);
    final user = (!isGroup && otherId.isNotEmpty)
        ? ref.watch(userProfileStreamProvider(otherId)).asData?.value
        : null;
    final resolvedName = user?.name.trim();
    final baseName = (resolvedName != null && resolvedName.isNotEmpty)
        ? resolvedName
        : widget.contactName;
    final displayName = isGroup
        ? (convo?.groupName ?? widget.contactName)
        : contactsService.resolveNameFromCache(
            fallbackName: baseName,
            phone: user?.phone,
          );
    final displayPhoto =
        isGroup ? widget.contactPhoto : (user?.photoUrl ?? widget.contactPhoto);

    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar:
          _buildAppBar(context, convo, currentUid, displayName, displayPhoto),
      body: Column(
        children: [
          // Liste messages
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (list) {
                // Filtrer les messages supprimés pour l'utilisateur courant
                final filteredList = list.where((m) {
                  // Ne pas afficher si le message est supprimé pour cet utilisateur
                  return !m.deletedFor.contains(currentUid);
                }).toList();

                if (filteredList.isEmpty) {
                  return _EmptyChatState(name: displayName);
                }

                // Déterminer si c'est un groupe
                final isGroup = convo?.isGroup ?? false;

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filteredList.length,
                  itemBuilder: (_, i) {
                    final msg = filteredList[i];
                    final isMine = msg.senderId == currentUid;
                    final showDate = i == 0 ||
                        !_isSameDay(filteredList[i - 1].sentAt, msg.sentAt);
                    return Column(
                      children: [
                        if (showDate) _DateDivider(date: msg.sentAt),
                        _buildMessageWidget(msg, isMine, isGroup, currentUid),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Barre de réponse
          if (_replyTo != null)
            _ReplyBar(
              message: _replyTo!,
              onCancel: () => setState(() => _replyTo = null),
            ),

          // Enregistrement vocal OU barre de saisie
          if (_isRecording)
            VoiceRecorderWidget(
              onRecordingComplete: (path, duration) async {
                setState(() => _isRecording = false);
                final uid = ref.read(currentAlanyaIDStringProvider);
                if (uid.isEmpty) return;
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
                        senderId: uid,
                        senderName: senderName,
                        mediaUrl: url,
                        type: MessageType.audio,
                        mediaDuration: duration,
                      );
                } catch (_) {}
              },
              onCancel: () => setState(() => _isRecording = false),
            )
          else
            _InputBar(
              controller: _controller,
              onSend: _send,
              onAttach: _openMediaPicker,
              onMicHold: () => setState(() => _isRecording = true),
              onEmoji: _openEmojiPicker,
              onChanged: (v) => setState(() => _isTyping = v.isNotEmpty),
              isTyping: _isTyping,
            ),
        ],
      ),
    );
  }

  Widget _buildMessageWidget(
      MessageModel msg, bool isMine, bool isGroup, String currentUid) {
    if (msg.isDeleted) {
      return _DeletedBubble(isMine: isMine);
    }

    switch (msg.type) {
      case MessageType.image:
        return MessageImageBubble(
            message: msg, isMine: isMine, isGroup: isGroup);
      case MessageType.audio:
        return VoiceMessageBubble(
          audioUrl: msg.mediaUrl,
          durationSeconds: msg.mediaDuration,
          isMine: isMine,
          isGroup: isGroup,
          senderName: msg.senderName,
          sentAt: msg.sentAt,
        );
      case MessageType.video:
        return VideoMessageBubble(
            message: msg, isMine: isMine, isGroup: isGroup);
      default:
        return _MessageBubble(
          message: msg,
          isMine: isMine,
          isGroup: isGroup,
          currentUid: currentUid,
          onReply: () => setState(() => _replyTo = msg),
          onEdit: isMine ? () => _showEditDialog(msg) : null,
          onDeleteForAll: isMine ? () => _deleteMessage(msg) : null,
          onDeleteForMe: () => _deleteMessageForMe(msg),
        );
    }
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ConversationModel? convo,
    String currentUid,
    String displayName,
    String? displayPhoto,
  ) {
    final canPop = Navigator.of(context).canPop();
    final isGroup = convo?.isGroup ?? false;
    final otherUserId = (convo == null || currentUid.isEmpty)
        ? null
        : convo.participantIds.firstWhere(
            (id) => id != currentUid,
            orElse: () => '',
          );
    final canCall = otherUserId != null && otherUserId.isNotEmpty;

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
          _AvatarWidget(name: displayName, photoUrl: displayPhoto),
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(displayName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                if (isGroup)
                  Text('Groupe',
                      style: TextStyle(
                          fontSize: 11,
                          color: context.appThemeColors.textSecondary))
                else if (otherUserId != null && otherUserId.isNotEmpty)
                  _PresenceText(userId: otherUserId)
                else
                  Text('Hors ligne',
                      style: TextStyle(
                          fontSize: 11,
                          color: context.appThemeColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.videocam_rounded),
          onPressed: canCall
              ? () => isGroup
                  ? _startGroupCallFromChat(
                      context,
                      convo,
                      currentUid,
                      displayName,
                      isVideo: true,
                    )
                  : _startCallFromChat(
                      context,
                      otherUserId!,
                      displayName: displayName,
                      isVideo: true,
                    )
              : () => _showCallDisabled(context, isGroup),
        ),
        IconButton(
          icon: Icon(Icons.call_rounded),
          onPressed: canCall
              ? () => isGroup
                  ? _startGroupCallFromChat(
                      context,
                      convo,
                      currentUid,
                      displayName,
                      isVideo: false,
                    )
                  : _startCallFromChat(
                      context,
                      otherUserId!,
                      displayName: displayName,
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
                  contactName: displayName,
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
    final msg =
        isGroup ? 'Appel de groupe non supporté' : 'Contact indisponible';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _startGroupCallFromChat(
    BuildContext context,
    ConversationModel? convo,
    String currentUid,
    String displayName, {
    required bool isVideo,
  }) async {
    if (convo == null) return;
    final participantIds =
        convo.participantIds.where((id) => id != currentUid).toList();
    if (participantIds.isEmpty) {
      _showCallDisabled(context, true);
      return;
    }

    final participants = convo.participantIds.map((id) {
      return GroupParticipant(
        id: id,
        name: convo.participantNames[id] ?? 'Utilisateur',
        photo: convo.participantPhotos[id],
      );
    }).toList();

    await ref.read(callProvider.notifier).startGroupCall(
          targetUserIds: participantIds,
          isVideo: isVideo,
          initialParticipants: participants,
          groupName: convo.groupName ?? displayName,
        );

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CallScreen()),
      );
    }
  }

  Future<void> _startCallFromChat(
    BuildContext context,
    String targetUserId, {
    required String displayName,
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
            targetName: displayName,
            targetPhoto: widget.contactPhoto,
            isVideo: isVideo,
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(chatServiceProvider).deleteMessageForAll(
            conversationId: widget.conversationId,
            messageId: msg.id,
          );
    }
  }

  Future<void> _deleteMessageForMe(MessageModel msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.appThemeColors.surface,
        title: Text('Supprimer le message'),
        content: Text('Ce message sera supprimé uniquement pour vous.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(chatServiceProvider).deleteMessageForMe(
            conversationId: widget.conversationId,
            messageId: msg.id,
            userId: ref.read(currentAlanyaIDStringProvider),
          );
    }
  }

  Future<void> _showEditDialog(MessageModel msg) async {
    final editController = TextEditingController(text: msg.content ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.appThemeColors.surface,
        title: Text('Modifier le message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          style: TextStyle(color: context.appThemeColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Votre message...',
            hintStyle: TextStyle(color: context.appThemeColors.textHint),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.primaryColor),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Annuler')),
          TextButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: Text('Enregistrer',
                style: TextStyle(color: context.primaryColor)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final newContent = editController.text.trim();
      if (newContent.isNotEmpty && newContent != msg.content) {
        await ref.read(chatServiceProvider).editMessage(
              conversationId: widget.conversationId,
              messageId: msg.id,
              newContent: newContent,
            );
      }
    }
    editController.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Message texte ──────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final bool isGroup;
  final String currentUid;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleteForAll;
  final VoidCallback? onDeleteForMe;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isGroup,
    required this.currentUid,
    required this.onReply,
    this.onEdit,
    this.onDeleteForAll,
    this.onDeleteForMe,
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
            color:
                isMine ? context.primaryColor : context.appThemeColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
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
                        color: context.primaryColor,
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
                          left: BorderSide(
                              color: message.isStatusReply
                                  ? context.primaryColor
                                  : context.accentColor,
                              width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label with icon for status vs message reply
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              message.isStatusReply
                                  ? Icons.auto_awesome
                                  : Icons.reply,
                              size: 12,
                              color: message.isStatusReply
                                  ? context.primaryColor
                                  : context.accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              message.isStatusReply
                                  ? 'Réponse au Statut'
                                  : 'Réponse à:',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: message.isStatusReply
                                    ? context.primaryColor
                                    : context.accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(message.replyToContent!,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.appThemeColors.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                Text(message.content ?? '',
                    style: TextStyle(
                      color: isMine
                          ? Colors.white
                          : context.appThemeColors.textPrimary,
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
                    // Badge "modifié" si le message a été modifié
                    if (message.isEdited) ...[
                      const SizedBox(width: 4),
                      Text(
                        'modifié',
                        style: TextStyle(
                          fontSize: 9,
                          fontStyle: FontStyle.italic,
                          color: isMine
                              ? Colors.white.withOpacity(0.6)
                              : context.appThemeColors.textHint,
                        ),
                      ),
                    ],
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
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: context.appThemeColors.divider,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.reply_rounded, color: context.primaryColor),
              title: Text('Répondre'),
              onTap: () {
                Navigator.pop(context);
                onReply();
              },
            ),
            ListTile(
              leading: Icon(Icons.copy_rounded),
              title: Text('Copier'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content ?? ''));
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Copié !')));
              },
            ),
            // Option Modifier (visible uniquement si: auteur ET message texte ET non supprimé)
            if (onEdit != null &&
                message.type == MessageType.text &&
                !message.isDeleted)
              ListTile(
                leading: Icon(Icons.edit_rounded, color: context.primaryColor),
                title: Text('Modifier'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit!();
                },
              ),
            // Option Supprimer pour tous (visible uniquement si auteur ET non supprimé)
            if (onDeleteForAll != null && !message.isDeleted)
              ListTile(
                leading: Icon(Icons.delete_sweep_rounded, color: Colors.orange),
                title: Text('Supprimer pour tous',
                    style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  onDeleteForAll!();
                },
              ),
            // Option Supprimer pour moi (toujours visible)
            if (onDeleteForMe != null)
              ListTile(
                leading: Icon(Icons.delete_rounded, color: Colors.red),
                title: Text('Supprimer pour moi',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  onDeleteForMe!();
                },
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
                style: TextStyle(
                    color: colors.textHint,
                    fontStyle: FontStyle.italic,
                    fontSize: 13)),
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
        return Icon(Icons.done_all_rounded,
            size: 12, color: context.accentColor);
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
          Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                  color: context.primaryColor,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.senderName,
                    style: TextStyle(
                        color: context.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
                Text(message.content ?? '',
                    style: TextStyle(
                        color: context.appThemeColors.textSecondary,
                        fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
              icon: Icon(Icons.close_rounded, size: 18), onPressed: onCancel),
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
                        onChanged: onChanged,
                        maxLines: 5,
                        minLines: 1,
                        style: TextStyle(
                            color: context.appThemeColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Message...',
                          hintStyle:
                              TextStyle(color: context.appThemeColors.textHint),
                          border: InputBorder.none,
                          isDense: true,
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
              onTap: isTyping ? onSend : onMicHold,
              onLongPress: isTyping ? null : onMicHold,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: context.primaryColor.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isTyping ? Icons.send_rounded : Icons.mic_rounded,
                    key: ValueKey(isTyping),
                    color: Colors.white,
                    size: 20,
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
class _AvatarWidget extends ConsumerWidget {
  final String name;
  final String? photoUrl;
  const _AvatarWidget({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.primaryColor,
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.primaryColor,
            ),
            child: const Center(
              child: Icon(Icons.person_rounded, color: Colors.white, size: 24),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.primaryColor,
      ),
      child: const Center(
        child: Icon(Icons.person_rounded, color: Colors.white, size: 24),
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
    '😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😎', '🤩', '🥳',
    '😇', '🙂', '🙃', '😉', '😌', '😜', '🤪', '😢', '😭', '😡',
    '😤', '😱', '🥶', '🥵', '🤯', '😴', '🤔', '🤫', '🤐', '😬',
    '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥', '😌', '😔',
    '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧', '🥴',
    '🤠', '🥱', '😎', '🤓', '🧐', '😕', '😟', '🙁', '☹️', '😮',
    '😯', '😲', '😳', '🥺', '😦', '😧', '😨', '😰', '😥', '😓',
    '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄',
    '🥹', '🫠', '🫡', '🫢', '🫣', '🫤', '🥸', '🤐', '🫥', '🫨',

    // === Gestes et parties du corps (avec variantes récentes) ===
    '👍', '👎', '👏', '🙏', '🤝', '💪', '✌️', '🤟', '🤘', '👌',
    '🤞', '🤙', '👈', '👉', '👆', '👇', '☝️', '👊', '👋', '🤚',
    '🖐️', '✋', '👌', '🤏', '🫶', '🤲', '🙌', '👐', '🤝', '🙏',
    '💅', '👄', '👅', '👂', '👃', '👣', '🧠', '🫀', '🫁', '🦷',
    '🦴', '👀', '👁️', '🫵', '🫱', '🫲', '🫳', '🫴', '🫸', '🫹',
    '🫷', '🫸', '🫲', '🫱', '🫳', '🫴', '🫶', '🫰', '🫱', '🫲',
    '🫳', '🫴', '🫵', '🫶', '🫷', '🫸',

    // === Animaux et nature (nouveaux + existants) ===
    '🐶', '🐱', '🐻', '🐼', '🐨', '🐯', '🦁', '🐸', '🐵', '🐧',
    '🐦', '🐤', '🐣', '🐥', '🐺', '🐗', '🐴', '🦄', '🐝', '🐛',
    '🦋', '🐌', '🐞', '🐜', '🦟', '🦗', '🕷️', '🕸️', '🦂', '🐢',
    '🐍', '🦎', '🐙', '🦑', '🦐', '🦞', '🐠', '🐟', '🐡', '🐬',
    '🐳', '🐋', '🦈', '🐊', '🐅', '🐆', '🦓', '🦍', '🦧', '🦣',
    '🐘', '🦏', '🐪', '🐫', '🦒', '🦘', '🐃', '🐂', '🐄', '🐎',
    '🐖', '🐏', '🐑', '🐐', '🦌', '🐕', '🐩', '🐈', '🐓', '🦃',
    '🦤', '🦚', '🦜', '🦢', '🦩', '🐇', '🦝', '🦨', '🦡', '🦫',
    '🦆', '🦅', '🦉', '🦇', '🐿️', '🦔', '🦊', '🦦', '🦥', '🪿',
    '🦫', '🦡', '🦨', '🦝', '🐁', '🐀', '🐿️', '🦔', '🦇', '🐦‍⬛',
    '🕊️', '🦃', '🦤', '🦩', '🦢', '🦚', '🦜', '🦆', '🦅', '🦉',
    '🪹', '🪺', '🌱', '🌿', '☘️', '🍀', '🍁', '🍂', '🍃', '🌾',
    '🌺', '🌻', '🌼', '🌸', '🌷', '🌹', '🥀', '🪷', '🌲', '🌳',
    '🌴', '🌵', '🎍', '🎋', '🪴', '🌿', '🍀', '🌱', '🌿', '🍃',

    // === Nourriture et boissons (complément) ===
    '🍕', '🍔', '🍟', '🌭', '🥗', '🍣', '🍩', '🍪', '🍫', '🍰',
    '🍎', '🍏', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐', '🍒',
    '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦', '🥬',
    '🥒', '🌶️', '🫑', '🌽', '🥕', '🫒', '🧄', '🧅', '🥔', '🍠',
    '🥐', '🥯', '🍞', '🥖', '🥨', '🧀', '🥚', '🍳', '🧈', '🥞',
    '🧇', '🥓', '🥩', '🍗', '🍖', '🦴', '🌮', '🌯', '🫔', '🥙',
    '🧆', '🥚', '🍲', '🫕', '🥣', '🥗', '🍿', '🧈', '🧂', '🥤',
    '🧃', '🧉', '🧊', '🍺', '🍻', '🥂', '🍷', '🥃', '🍸', '🍹',
    '🥮', '🍡', '🍢', '🍥', '🥟', '🥠', '🥡', '🦪', '🍲', '🥘',
    '🍛', '🍜', '🍝', '🍠', '🍯', '🥛', '☕', '🍵', '🍶', '🍾',
    '🍴', '🥄', '🔪', '🏺', '🍽️',

    // === Sports et activités (nouveaux) ===
    '⚽', '🏀', '🏈', '🎮', '🎧', '🎵', '🎬', '📷', '✈️', '🚗',
    '🏀', '⚾', '🥎', '🏐', '🏉', '🎾', '🥏', '🎳', '🏏', '🏑',
    '🏒', '🥍', '🏓', '🏸', '🥊', '🥋', '🥅', '⛳', '🏹', '🎣',
    '🤿', '🥌', '🛹', '🛼', '🛷', '⛸️', '🥌', '🎿', '🏂', '🪂',
    '🏌️', '🏌️‍♂️', '🏌️‍♀️', '🏄', '🏄‍♂️', '🏄‍♀️', '🏊', '🏊‍♂️', '🏊‍♀️',
    '⛹️',
    '⛹️‍♂️', '⛹️‍♀️', '🏋️', '🏋️‍♂️', '🏋️‍♀️', '🚴', '🚴‍♂️', '🚴‍♀️', '🚵',
    '🚵‍♂️',
    '🚵‍♀️', '🤸', '🤸‍♂️', '🤸‍♀️', '🤼', '🤼‍♂️', '🤼‍♀️', '🤽', '🤽‍♂️',
    '🤽‍♀️',
    '🤾', '🤾‍♂️', '🤾‍♀️', '🤹', '🤹‍♂️', '🤹‍♀️', '🧘', '🧘‍♂️', '🧘‍♀️',
    '🪁',

    // === Voyage et lieux (complément) ===
    '🏡', '🌍', '✈️', '🚗', '🚲', '🏍️', '🚂', '🚢', '⛵', '🛸',
    '🚀', '🛰️', '🏖️', '🏝️', '🏜️', '🏔️', '⛰️', '🌋', '🏕️',
    '🏞️', '🏟️', '🏛️', '🏗️', '🏘️', '🏚️', '🏠', '🏡', '🏢',
    '🏣', '🏤', '🏥', '🏦', '🏨', '🏩', '🏪', '🏫', '🏬', '🏭',
    '🏮', '🏯', '🏰', '💒', '🗼', '🗽', '⛲', '⛪', '🕌', '🕍',
    '⛩️', '🕋', '⛺', '🌁', '🌃', '🌄', '🌅', '🌆', '🌇', '🌉',
    '🌌', '🗿', '🛕', '🕍', '⛩️',

    // === Objets et symboles (très complet) ===
    '🔥', '✨', '🎉', '💯', '💥', '⭐', '🌈', '⚡', '☀️', '🌙',
    '❤️', '💔', '💙', '💚', '💛', '🧡', '💜', '🤍', '🤎', '🖤',
    '💋', '💌', '💘', '💝', '💖', '💗', '💓', '💞', '💕', '💟',
    '💤', '💢', '💣', '💥', '💦', '💨', '💫', '💬', '🗨️', '🗯️',
    '🕳️', '💭', '💠', '🔮', '🧿', '🪬', '💈', '⚗️', '🔭', '🔬',
    '🕯️', '💡', '🔦', '🏮', '📔', '📕', '📗', '📘', '📙', '📚',
    '📖', '🔖', '🧷', '🔗', '📎', '🖇️', '📐', '📏', '🧮', '📌',
    '📍', '✂️', '🖊️', '🖋️', '✒️', '🖌️', '🖍️', '📝', '📁', '📂',
    '🗂️', '📅', '📆', '🗒️', '🗓️', '📇', '📈', '📉', '📊', '📋',
    '📌', '📍', '📎', '🖇️', '📏', '📐', '✂️', '🔒', '🔓', '🔏',
    '🔐', '🔑', '🗝️', '🔨', '🪓', '⛏️', '⚒️', '🛠️', '🔧', '🔩',
    '⚙️', '🗜️', '⚖️', '🦯', '🔗', '⛓️', '🧰', '🧲', '⚗️', '🧪',
    '🧫', '🧬', '🔬', '🔭', '📡', '💉', '🩸', '💊', '🩹', '🩺',
    '📿', '💎', '⚜️', '🔱', '📛', '🔰', '⭕', '✅', '❌', '❎',
    '➕', '➖', '➗', '✖️', '♾️', '‼️', '⁉️', '❓', '❔', '❕',
    '❗', '〰️', '➰', '➿', '🔴', '🟠', '🟡', '🟢', '🔵', '🟣',
    '🟤', '⚫', '⚪', '🟥', '🟧', '🟨', '🟩', '🟦', '🟪', '🟫',
    '⬛', '⬜', '🔶', '🔷', '🔸', '🔹', '🔺', '🔻', '💠', '🔘',
    '🔲', '🔳', '⚪', '⚫',

    // === Drapeaux (sélection étendue) ===
    '🏁', '🚩', '🎌', '🏴', '🏳️', '🏳️‍🌈', '🏳️‍⚧️', '🇫🇷', '🇬🇧', '🇺🇸',
    '🇨🇳', '🇯🇵', '🇩🇪', '🇮🇹', '🇪🇸', '🇵🇹', '🇳🇱', '🇧🇪', '🇨🇦',
    '🇧🇷',
    '🇷🇺', '🇮🇳', '🇦🇺', '🇳🇿', '🇿🇦', '🇪🇬', '🇸🇦', '🇦🇪', '🇮🇱',
    '🇹🇷',
    '🇬🇷', '🇸🇪', '🇳🇴', '🇩🇰', '🇫🇮', '🇮🇸', '🇮🇪', '🇨🇭', '🇦🇹',
    '🇵🇱',
    '🇨🇿', '🇭🇺', '🇸🇰', '🇸🇮', '🇭🇷', '🇷🇸', '🇧🇬', '🇷🇴', '🇲🇩',
    '🇺🇦',
    '🇧🇾', '🇱🇹', '🇱🇻', '🇪🇪', '🇦🇲', '🇬🇪', '🇦🇿', '🇰🇿', '🇺🇿',
    '🇹🇲',
    '🇰🇬', '🇹🇯', '🇦🇫', '🇵🇰', '🇧🇩', '🇱🇰', '🇳🇵', '🇧🇹', '🇲🇲',
    '🇹🇭',
    '🇱🇦', '🇻🇳', '🇰🇭', '🇲🇾', '🇸🇬', '🇵🇭', '🇮🇩', '🇹🇱', '🇰🇷',
    '🇰🇵',
    '🇲🇳', '🇯🇴', '🇱🇧', '🇸🇾', '🇮🇶', '🇮🇷', '🇰🇼', '🇧🇭', '🇶🇦',
    '🇴🇲',
    '🇾🇪', '🇩🇿', '🇲🇦', '🇹🇳', '🇱🇾', '🇸🇩', '🇪🇷', '🇩🇯', '🇸🇴',
    '🇪🇹',
    '🇰🇪', '🇹🇿', '🇺🇬', '🇷🇼', '🇧🇮', '🇲🇿', '🇿🇲', '🇲🇼', '🇿🇼',
    '🇧🇼',
    '🇳🇦', '🇿🇦', '🇱🇸', '🇸🇿', '🇰🇲', '🇲🇬', '🇸🇨', '🇲🇺', '🇨🇻',
    '🇸🇹',
    '🇬🇼', '🇬🇶', '🇬🇦', '🇨🇬', '🇨🇩', '🇦🇴', '🇳🇬', '🇬🇭', '🇨🇮',
    '🇱🇷',
    '🇸🇱', '🇬🇳', '🇸🇳', '🇬🇲', '🇲🇱', '🇧🇫', '🇳🇪', '🇹🇩', '🇨🇲',
    '🇨🇫',
    '🇬🇶', '🇬🇦', '🇨🇬', '🇨🇩', '🇷🇼', '🇧🇮', '🇺🇬', '🇰🇪', '🇹🇿',
    '🇲🇿',
    '🇲🇼', '🇿🇲', '🇿🇼', '🇧🇼', '🇳🇦', '🇿🇦', '🇸🇿', '🇱🇸', '🇰🇲',
    '🇲🇬',
    '🇸🇨', '🇲🇺', '🇨🇻', '🇸🇹', '🇬🇼', '🇬🇶', '🇬🇦', '🇨🇬', '🇨🇩',
    '🇦🇴',
    '🇳🇬', '🇬🇭', '🇨🇮', '🇱🇷', '🇸🇱', '🇬🇳', '🇸🇳', '🇬🇲', '🇲🇱',
    '🇧🇫',
    '🇳🇪', '🇹🇩', '🇨🇲', '🇨🇫', '🇬🇶', '🇬🇦', '🇨🇬', '🇨🇩', '🇷🇼',
    '🇧🇮',
    '🇺🇬', '🇰🇪', '🇹🇿', '🇲🇿', '🇲🇼', '🇿🇲', '🇿🇼', '🇧🇼', '🇳🇦',
    '🇿🇦',
    '🇸🇿', '🇱🇸', '🇰🇲', '🇲🇬', '🇸🇨', '🇲🇺', '🇨🇻', '🇸🇹', '🇬🇼',
    '🇬🇶',
    '🇬🇦', '🇨🇬', '🇨🇩', '🇦🇴',

    // === Personnes et rôles (famille, métiers, etc.) ===
    '👶', '🧒', '👦', '👧', '🧑', '👨', '👩', '🧓', '👴', '👵',
    '👨‍⚕️', '👩‍⚕️', '👨‍🎓', '👩‍🎓', '👨‍🏫', '👩‍🏫', '👨‍⚖️', '👩‍⚖️',
    '👨‍🌾', '👩‍🌾',
    '👨‍🍳', '👩‍🍳', '👨‍🔧', '👩‍🔧', '👨‍🏭', '👩‍🏭', '👨‍💼', '👩‍💼',
    '👨‍🔬', '👩‍🔬',
    '👨‍💻', '👩‍💻', '👨‍🎤', '👩‍🎤', '👨‍🎨', '👩‍🎨', '👨‍✈️', '👩‍✈️',
    '👨‍🚀', '👩‍🚀',
    '👨‍🚒', '👩‍🚒', '👮', '👮‍♂️', '👮‍♀️', '🕵️', '🕵️‍♂️', '🕵️‍♀️', '💂',
    '💂‍♂️',
    '💂‍♀️', '👷', '👷‍♂️', '👷‍♀️', '🤴', '👸', '👳', '👳‍♂️', '👳‍♀️', '👲',
    '🧕', '🤵', '🤵‍♂️', '🤵‍♀️', '👰', '👰‍♂️', '👰‍♀️', '🤰', '🤱', '👩‍🍼',
    '👨‍🍼', '🧑‍🍼', '👼', '🎅', '🤶', '🧑‍🎄', '🦸', '🦸‍♂️', '🦸‍♀️', '🦹',
    '🦹‍♂️', '🦹‍♀️', '🧙', '🧙‍♂️', '🧙‍♀️', '🧚', '🧚‍♂️', '🧚‍♀️', '🧛',
    '🧛‍♂️',
    '🧛‍♀️', '🧜', '🧜‍♂️', '🧜‍♀️', '🧝', '🧝‍♂️', '🧝‍♀️', '🧞', '🧞‍♂️',
    '🧞‍♀️',
    '🧟', '🧟‍♂️', '🧟‍♀️', '💆', '💆‍♂️', '💆‍♀️', '💇', '💇‍♂️', '💇‍♀️',
    '🚶',
    '🚶‍♂️', '🚶‍♀️', '🧍', '🧍‍♂️', '🧍‍♀️', '🧎', '🧎‍♂️', '🧎‍♀️', '🏃',
    '🏃‍♂️',
    '🏃‍♀️', '💃', '🕺', '👯', '👯‍♂️', '👯‍♀️', '🧖', '🧖‍♂️', '🧖‍♀️', '🧗',
    '🧗‍♂️', '🧗‍♀️', '🤺', '🏇', '⛷️', '🏂', '🏌️', '🏌️‍♂️', '🏌️‍♀️', '🏄',
    '🏄‍♂️', '🏄‍♀️', '🚣', '🚣‍♂️', '🚣‍♀️', '🏊', '🏊‍♂️', '🏊‍♀️', '⛹️',
    '⛹️‍♂️',
    '⛹️‍♀️', '🏋️', '🏋️‍♂️', '🏋️‍♀️', '🚴', '🚴‍♂️', '🚴‍♀️', '🚵', '🚵‍♂️',
    '🚵‍♀️',
    '🤸', '🤸‍♂️', '🤸‍♀️', '🤼', '🤼‍♂️', '🤼‍♀️', '🤽', '🤽‍♂️', '🤽‍♀️',
    '🤾',
    '🤾‍♂️', '🤾‍♀️', '🤹', '🤹‍♂️', '🤹‍♀️', '🧘', '🧘‍♂️', '🧘‍♀️', '🛀',
    '🛌',

    // === Vêtements et accessoires ===
    '🧥', '🧦', '🧤', '🧣', '👚', '👕', '👖', '👔', '👗', '👘',
    '🥻', '🩳', '👙', '🩱', '🩲', '🩳', '👠', '👡', '👢', '👞',
    '👟', '🥾', '🥿', '🧦', '🧢', '🎩', '🎓', '🧳', '👝', '👛',
    '👜', '💼', '🎒', '👓', '🕶️', '🥽', '🥼', '🦺', '👔', '👕',

    // === Musique, arts, technologie ===
    '🎵', '🎶', '🎼', '🎤', '🎧', '🎷', '🎺', '🎸', '🎻', '🪕',
    '🥁', '🎹', '📻', '📺', '📱', '📲', '☎️', '📞', '📟', '📠',
    '🔋', '🔌', '💻', '🖥️', '🖨️', '⌨️', '🖱️', '🖲️', '💽', '💾',
    '💿', '📀', '🎥', '🎞️', '📽️', '🎬', '📷', '📸', '📹', '📼',
    '🔍', '🔎', '🕯️', '💡', '🔦', '🏮', '📔', '📕', '📗', '📘',
    '📙', '📚', '📖', '🔖', '🧷', '🔗', '📎', '🖇️', '📐', '📏',
    '🧮', '📌', '📍', '✂️', '🖊️', '🖋️', '✒️', '🖌️', '🖍️', '📝',

    // === Nature, météo, astres (complément) ===
    '🌞', '🌝', '🌚', '🌛', '🌜', '🌙', '🌖', '🌗', '🌘', '🌑',
    '🌒', '🌓', '🌔', '🌕', '🌖', '🌗', '🌘', '🌙', '🌚', '🌛',
    '🌜', '☀️', '🌤️', '⛅', '🌥️', '🌦️', '🌧️', '🌨️', '🌩️', '🌪️',
    '🌫️', '🌬️', '🌀', '🌈', '🌂', '☂️', '☔', '⛱️', '⚡', '❄️',
    '☃️', '⛄', '🔥', '💧', '🌊', '🌫️', '🌬️', '☀️', '🌤️', '⛅',

    // === Horloges et temps ===
    '🕐', '🕑', '🕒', '🕓', '🕔', '🕕', '🕖', '🕗', '🕘', '🕙',
    '🕚', '🕛', '🕜', '🕝', '🕞', '🕟', '🕠', '🕡', '🕢', '🕣',
    '🕤', '🕥', '🕦', '🕧', '⌚', '⏰', '⏱️', '⏲️', '🕰️', '⌛',
    '⏳',

    // === Divers (objets du quotidien) ===
    '🛒', '🛍️', '🎁', '🎈', '🎉', '🎊', '🎄', '🎃', '🎆', '🎇',
    '🧨', '✨', '💥', '💫', '💦', '💨', '🕳️', '💬', '🗯️', '💭',
    '💤', '💢', '💣', '💥', '💧', '💨', '🕳️', '🪑', '🛏️', '🛋️',
    '🪜', '🧰', '🧲', '🧪', '🧫', '🧬', '🔬', '🔭', '📡', '💉',
    '🩸', '💊', '🩹', '🩺', '🚽', '🚿', '🛁', '🧴', '🧷', '🧹',
    '🧺', '🧻', '🧼', '🧽', '🧯', '🛒', '🛍️', '🎁', '🎈', '🎉',
    '🎊', '🎄', '🎃', '🎆', '🎇', '🧨', '✨', '💥', '💫', '💦',
    '💨', '🕳️', '💬', '🗯️', '💭', '💤', '💢', '💣', '💥', '💧',
    '💨', '🕳️', '🪑', '🛏️', '🛋️', '🪜', '🧰', '🧲', '🧪', '🧫',
    '🧬', '🔬', '🔭', '📡', '💉', '🩸', '💊', '🩹', '🩺', '🚽',
    '🚿', '🛁', '🧴', '🧷', '🧹', '🧺', '🧻', '🧼', '🧽', '🧯',
    '🪔', '🪙', '🪣', '🪤', '🪥', '🪦', '🪧', '🪨', '🪩', '🪪',
    '🪫', '🪬', '🪭', '🪮', '🪯'
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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
class _PresenceText extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileStreamProvider(userId)).asData?.value;
    final isOnline = user?.isOnline == true;
    final lastSeen = user?.lastSeen;

    if (isOnline) {
      return Text('En ligne',
          style: TextStyle(fontSize: 11, color: context.accentColor));
    }

    if (lastSeen != null) {
      return Text(_formatLastSeen(lastSeen),
          style: TextStyle(
              fontSize: 11, color: context.appThemeColors.textSecondary));
    }

    return Text('Hors ligne',
        style: TextStyle(
            fontSize: 11, color: context.appThemeColors.textSecondary));
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
    if (DateUtils.isSameDay(date, now))
      text = "Aujourd'hui";
    else if (DateUtils.isSameDay(date, yesterday))
      text = 'Hier';
    else
      text = DateFormat('d MMMM yyyy', 'fr').format(date);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: context.appThemeColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(text,
                style: TextStyle(
                    color: context.appThemeColors.textHint,
                    fontSize: 11,
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
