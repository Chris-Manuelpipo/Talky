// lib/features/status/presentation/add_status_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_colors_provider.dart';
import '../../auth/data/auth_providers.dart';
import '../../chat/data/chat_providers.dart';
import '../data/status_providers.dart';

class AddStatusScreen extends ConsumerStatefulWidget {
  const AddStatusScreen({super.key});

  @override
  ConsumerState<AddStatusScreen> createState() => _AddStatusScreenState();
}

class _AddStatusScreenState extends ConsumerState<AddStatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _textCtrl = TextEditingController();
  final _captionCtrl = TextEditingController();
  File? _selectedFile;
  bool _isVideo = false;
  bool _isLoading = false;

  // Couleurs de fond pour les statuts texte
  final _bgColors = [
    '#7C5CFC',
    '#4FC3F7',
    '#FF6B6B',
    '#51CF66',
    '#FF9F43',
    '#FD79A8',
    '#0984E3',
    '#6C5CE7',
    '#00B894',
    '#E17055',
  ];
  String _selectedBg = '#7C5CFC';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null)
      setState(() {
        _selectedFile = File(picked.path);
        _isVideo = false;
      });
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery, maxDuration: const Duration(minutes: 1));
    if (picked != null)
      setState(() {
        _selectedFile = File(picked.path);
        _isVideo = true;
      });
  }

  Future<void> _publish() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final myName = await ref.read(currentUserNameProvider.future);

    setState(() => _isLoading = true);
    try {
      final service = ref.read(statusServiceProvider);

      switch (_tabCtrl.index) {
        case 0: // Texte
          if (_textCtrl.text.trim().isEmpty) {
            _showSnack('Écris quelque chose !');
            return;
          }
          await service.postTextStatus(
            userId: user.uid,
            userName: myName,
            text: _textCtrl.text.trim(),
            backgroundColor: _selectedBg,
          );
          break;

        case 1: // Image
          if (_selectedFile == null) {
            _showSnack('Sélectionne une image');
            return;
          }
          await service.postImageStatus(
            userId: user.uid,
            userName: myName,
            imageFile: _selectedFile!,
            caption: _captionCtrl.text.trim().isEmpty
                ? null
                : _captionCtrl.text.trim(),
          );
          break;

        case 2: // Vidéo
          if (_selectedFile == null) {
            _showSnack('Sélectionne une vidéo');
            return;
          }
          await service.postVideoStatus(
            userId: user.uid,
            userName: myName,
            videoFile: _selectedFile!,
            caption: _captionCtrl.text.trim().isEmpty
                ? null
                : _captionCtrl.text.trim(),
          );
          break;
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack('Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: context.appThemeColors.error));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appThemeColors.background,
      appBar: AppBar(
        backgroundColor: context.appThemeColors.background,
        title: Text('Nouveau statut',
            style: TextStyle(
                color: context.appThemeColors.textPrimary,
                fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: context.appThemeColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _publish,
              child: Text('Publier',
                  style: TextStyle(
                      color: context.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            )
          else
            Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: context.primaryColor, strokeWidth: 2)),
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: context.primaryColor,
          labelColor: context.primaryColor,
          unselectedLabelColor: context.appThemeColors.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.text_fields_rounded), text: 'Texte'),
            Tab(icon: Icon(Icons.image_rounded), text: 'Image'),
            Tab(icon: Icon(Icons.videocam_rounded), text: 'Vidéo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _TextTab(
            controller: _textCtrl,
            bgColors: _bgColors,
            selectedBg: _selectedBg,
            onBgChanged: (c) => setState(() => _selectedBg = c),
          ),
          _MediaTab(
            isVideo: false,
            selectedFile: _selectedFile,
            captionCtrl: _captionCtrl,
            onPick: _pickImage,
            primaryColor: context.primaryColor,
          ),
          _MediaTab(
            isVideo: true,
            selectedFile: _selectedFile,
            captionCtrl: _captionCtrl,
            onPick: _pickVideo,
            primaryColor: context.primaryColor,
          ),
        ],
      ),
    );
  }
}

// ── Tab Texte ──────────────────────────────────────────────────────────
class _TextTab extends StatelessWidget {
  final TextEditingController controller;
  final List<String> bgColors;
  final String selectedBg;
  final void Function(String) onBgChanged;

  const _TextTab({
    required this.controller,
    required this.bgColors,
    required this.selectedBg,
    required this.onBgChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Color(int.parse(selectedBg.replaceFirst('#', '0xFF')));

    return Column(
      children: [
        // Preview
        Expanded(
          child: Container(
            width: double.infinity,
            color: bg,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Écris ton statut...',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 24),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Sélecteur couleur
        Container(
          height: 70,
          color: context.appThemeColors.surface,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: bgColors.length,
            itemBuilder: (_, i) {
              final c = Color(int.parse(bgColors[i].replaceFirst('#', '0xFF')));
              final isSelected = bgColors[i] == selectedBg;
              return GestureDetector(
                onTap: () => onBgChanged(bgColors[i]),
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Tab Média (image ou vidéo) ─────────────────────────────────────────
class _MediaTab extends StatelessWidget {
  final bool isVideo;
  final File? selectedFile;
  final TextEditingController captionCtrl;
  final VoidCallback onPick;
  final Color primaryColor;

  const _MediaTab({
    required this.isVideo,
    this.selectedFile,
    required this.captionCtrl,
    required this.onPick,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: selectedFile == null
              ? Center(
                  child: GestureDetector(
                    onTap: onPick,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor.withOpacity(0.1),
                          ),
                          child: Icon(
                              isVideo
                                  ? Icons.videocam_rounded
                                  : Icons.add_photo_alternate_rounded,
                              color: context.primaryColor,
                              size: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                            isVideo
                                ? 'Sélectionner une vidéo'
                                : 'Sélectionner une image',
                            style: TextStyle(
                                color: context.appThemeColors.textSecondary,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!isVideo)
                      Image.file(selectedFile!, fit: BoxFit.contain),
                    if (isVideo)
                      Center(
                          child: Icon(Icons.play_circle_fill_rounded,
                              color: context.primaryColor, size: 80)),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: onPick,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        // Caption
        Container(
          color: context.appThemeColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: TextField(
            controller: captionCtrl,
            style: TextStyle(color: context.appThemeColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ajouter une légende...',
              hintStyle: TextStyle(color: context.appThemeColors.textSecondary),
              filled: true,
              fillColor: context.appThemeColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
