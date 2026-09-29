import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../controllers/chat_controller.dart';
import '../models/chat_message.dart';
import '../services/chat_settings.dart';

const _green = Color(0xFF10A37F);

// Light-theme colors
const _lightSurface = Color(0xFFFFFFFF);
const _lightBorder = Color(0xFFE5E7E9);
const _lightUserBubble = Color(0xFFE9F4F0);
const _lightCodeBg = Color(0xFFF0F1F2);

// Dark-theme colors
const _darkSurface = Color(0xFF1E2328);
const _darkBorder = Color(0xFF2A3036);
const _darkUserBubble = Color(0xFF1B3A31);
const _darkCodeBg = Color(0xFF252A2F);

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollController = ScrollController();
  final _speech = stt.SpeechToText();
  Timer? _restartTimer;
  bool _speechAvailable = false;
  bool _voiceActive = false;
  bool _startingSpeech = false;
  bool _showSpeechError = false;
  bool _isNearBottom = true;
  int _speechRestartAttempts = 0;
  String _speechBaseText = '';
  String _speechDraft = '';

  static const _maxSpeechRestartAttempts = 3;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
    unawaited(_initializeSpeech());
  }

  void _onScrollChanged() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _isNearBottom = position.pixels >= position.maxScrollExtent - 120;
  }

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: (error) {
          if (!mounted) return;
          if (_voiceActive) {
            setState(() => _showSpeechError = true);
          }
          _scheduleSpeechRestart();
        },
        finalTimeout: const Duration(milliseconds: 900),
      );
      if (!mounted) return;
      setState(() => _speechAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  void _onSpeechStatus(String status) {
    if (status == 'listening') {
      if (mounted) setState(() => _showSpeechError = false);
      _speechRestartAttempts = 0;
      _restartTimer?.cancel();
    } else if (_voiceActive && (status == 'notListening' || status == 'done')) {
      _commitSpeechDraft();
      _scheduleSpeechRestart();
    }
  }

  void _scheduleSpeechRestart() {
    if (!_voiceActive) return;
    if (_speechRestartAttempts >= _maxSpeechRestartAttempts) {
      if (mounted) setState(() => _showSpeechError = true);
      return;
    }
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 450), () {
      if (_voiceActive && mounted) unawaited(_startSpeechSession());
    });
  }

  Future<void> _startSpeechSession() async {
    if (!_voiceActive || _startingSpeech || _speech.isListening) return;
    _startingSpeech = true;
    _speechRestartAttempts++;
    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted || !_voiceActive) return;
          final words = result.recognizedWords.trim();
          if (words.isEmpty) return;
          setState(() {
            if (result.finalResult) {
              _speechBaseText = _joinText(_speechBaseText, words);
              _speechDraft = '';
            } else {
              _speechDraft = words;
            }
            _inputController.value = TextEditingValue(
              text: _joinText(_speechBaseText, _speechDraft),
              selection: TextSelection.collapsed(
                offset: _joinText(_speechBaseText, _speechDraft).length,
              ),
            );
          });
        },
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.dictation,
          pauseFor: const Duration(seconds: 5),
          listenFor: const Duration(seconds: 45),
          autoPunctuation: true,
          cancelOnError: false,
        ),
      );
    } catch (_) {
      if (mounted && _voiceActive) setState(() => _showSpeechError = true);
      _scheduleSpeechRestart();
    } finally {
      _startingSpeech = false;
    }
  }

  void _commitSpeechDraft() {
    final draft = _speechDraft.trim();
    if (draft.isNotEmpty) {
      _speechBaseText = _joinText(_speechBaseText, draft);
      _speechDraft = '';
      final text = _speechBaseText;
      _inputController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  String _joinText(String first, String second) {
    if (first.trim().isEmpty) return second;
    if (second.trim().isEmpty) return first;
    return '${first.trimRight()} ${second.trimLeft()}';
  }

  Future<void> _toggleVoice() async {
    if (_voiceActive) {
      await _stopVoice();
      return;
    }
    if (!_speechAvailable) {
      await _initializeSpeech();
      if (!_speechAvailable) {
        if (mounted) _showMessage('语音识别不可用，请检查麦克风和语音识别权限。');
        return;
      }
    }

    _inputFocus.unfocus();
    _speechBaseText = _inputController.text.trim();
    _speechDraft = '';
    setState(() {
      _voiceActive = true;
      _showSpeechError = false;
    });
    HapticFeedback.selectionClick();
    await _startSpeechSession();
  }

  Future<void> _stopVoice() async {
    _voiceActive = false;
    _restartTimer?.cancel();
    _commitSpeechDraft();
    if (mounted) setState(() {});
    try {
      await _speech.stop();
    } catch (_) {
      // The speech service may already have ended its session.
    }
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (_voiceActive) unawaited(_stopVoice());
    _inputController.clear();
    _speechBaseText = '';
    _speechDraft = '';
    _inputFocus.unfocus();
    _isNearBottom = true;
    unawaited(context.read<ChatController>().sendMessage(text));
    _scrollToBottom(force: true, animate: true);
  }

  void _scrollToBottom({bool force = false, bool animate = false}) {
    if (!force && !_isNearBottom) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _showSettings() async {
    final controller = context.read<ChatController>();
    final updated = await showModalBottomSheet<ChatSettings>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsSheet(settings: controller.settings),
    );
    if (updated == null || !mounted) return;
    await SettingsStore.save(updated);
    await controller.updateSettings(updated);
    if (mounted) _showMessage('设置已保存');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    _voiceActive = false;
    unawaited(_speech.cancel());
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    if (chat.messages.isNotEmpty && _isNearBottom) {
      _scrollToBottom();
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_rounded, color: _green, size: 22),
            SizedBox(width: 9),
            Text('Chat Niu', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '新对话',
            onPressed: chat.isBusy
                ? null
                : () {
                    chat.clearConversation();
                    _inputController.clear();
                  },
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: '设置',
            onPressed: _showSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chat.messages.isEmpty
                ? _WelcomeView(onSuggestion: (text) {
                    _inputController.text = text;
                    _inputFocus.requestFocus();
                  })
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: chat.messages.length,
                    itemBuilder: (context, index) => _MessageBubble(
                      message: chat.messages[index],
                    ),
                  ),
          ),
          if (_voiceActive || _showSpeechError)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(
                    _showSpeechError ? Icons.error_outline : Icons.graphic_eq,
                    size: 16,
                    color: _showSpeechError ? Colors.deepOrange : _green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _showSpeechError
                          ? '语音识别暂时中断，正在尝试恢复…'
                          : '正在聆听 · 停顿后会自动续听，点麦克风结束',
                      style: TextStyle(
                        fontSize: 12,
                        color: _showSpeechError ? Colors.deepOrange : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _Composer(
            controller: _inputController,
            focusNode: _inputFocus,
            voiceActive: _voiceActive,
            speechAvailable: _speechAvailable,
            isBusy: chat.isBusy,
            onVoiceTap: _toggleVoice,
            onSend: _send,
            onStop: chat.cancelStream,
          ),
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      '用简单的话解释一个复杂概念',
      '帮我写一封礼貌、简洁的邮件',
      '给我一些周末放松的灵感',
    ];
    final dark = _isDark(context);
    final cardBorder = Border.all(color: dark ? _darkBorder : _lightBorder);
    final cardBg = dark ? _darkSurface : const Color(0xFFFFFFFF);
    final muted = dark ? Colors.white54 : Colors.black54;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.11),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: _green, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                '今天有什么可以帮你？',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 9),
              Text(
                '输入消息，或点麦克风开始语音输入',
                style: TextStyle(color: muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ...suggestions.map(
                (suggestion) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Material(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => onSuggestion(suggestion),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: cardBorder,
                        ),
                        child: Text(suggestion),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final dark = _isDark(context);
    if (!isUser && message.content.isEmpty && message.isStreaming) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2, color: _green),
            ),
            const SizedBox(width: 12),
            Text('正在思考…', style: TextStyle(color: dark ? Colors.white54 : Colors.black54)),
          ],
        ),
      );
    }

    final userBg = dark ? _darkUserBubble : _lightUserBubble;
    final codeBg = dark ? _darkCodeBg : _lightCodeBg;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * (isUser ? 0.84 : 0.96),
        ),
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: EdgeInsets.symmetric(
          horizontal: isUser ? 15 : 2,
          vertical: isUser ? 11 : 5,
        ),
        decoration: isUser
            ? BoxDecoration(
                color: userBg,
                borderRadius: BorderRadius.circular(19),
              )
            : null,
        child: isUser
            ? SelectableText(
                message.content,
                style: TextStyle(fontSize: 15, height: 1.48, color: dark ? Colors.white : null),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message.content,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: message.isError
                            ? (dark ? Colors.red.shade300 : Colors.red.shade700)
                            : null,
                        fontSize: 15,
                        height: 1.58,
                      ),
                      code: TextStyle(
                        fontFamily: 'monospace',
                        backgroundColor: codeBg,
                        color: dark ? Colors.green.shade200 : null,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: codeBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: dark ? _darkBorder : _lightBorder, width: 0.5),
                      ),
                      blockquoteDecoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: _green, width: 3)),
                      ),
                    ),
                  ),
                  if (message.isStreaming)
                    Container(
                      width: 7,
                      height: 16,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.voiceActive,
    required this.speechAvailable,
    required this.isBusy,
    required this.onVoiceTap,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool voiceActive;
  final bool speechAvailable;
  final bool isBusy;
  final VoidCallback onVoiceTap;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? _darkSurface : _lightSurface,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: dark ? _darkBorder : _lightBorder),
            boxShadow: const [
              BoxShadow(color: Color(0x0C000000), blurRadius: 12, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) {
                    if (!isBusy) onSend();
                  },
                  decoration: const InputDecoration(
                    hintText: '发消息…',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(18, 15, 8, 14),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 6, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _VoiceButton(
                      active: voiceActive,
                      enabled: speechAvailable || voiceActive,
                      onTap: onVoiceTap,
                    ),
                    const SizedBox(width: 5),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        if (isBusy) return _StopButton(onPressed: onStop);
                        return _SendButton(
                          enabled: value.text.trim().isNotEmpty,
                          onPressed: onSend,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    return Semantics(
      button: true,
      label: active ? '停止语音输入' : '开始语音输入',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFE9E8) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          tooltip: active ? '停止语音输入' : '语音输入',
          onPressed: enabled ? onTap : null,
          icon: AnimatedScale(
            scale: active ? 1.12 : 1,
            duration: const Duration(milliseconds: 220),
            child: Icon(
              active ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: active ? const Color(0xFFE5484D) : (dark ? Colors.white54 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? _green : Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _green,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.stop_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.settings});

  final ChatSettings settings;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late final _baseUrlController = TextEditingController(text: widget.settings.baseUrl);
  late final _apiKeyController = TextEditingController(text: widget.settings.apiKey);
  late final _modelController = TextEditingController(text: widget.settings.model);
  bool _hideKey = true;
  late int _themeMode = widget.settings.themeMode;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  void _save() {
    final url = _baseUrlController.text.trim();
    final model = _modelController.text.trim();
    if (url.isEmpty || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API 地址和模型名称不能为空')),
      );
      return;
    }
    Navigator.of(context).pop(ChatSettings(
      baseUrl: url,
      apiKey: _apiKeyController.text.trim(),
      model: model,
      themeMode: _themeMode,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final dark = _isDark(context);
    final containerBg = dark ? const Color(0xFF1A1D22) : Colors.white;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('外观',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('自动')),
                  ButtonSegment(value: 1, label: Text('浅色')),
                  ButtonSegment(value: 2, label: Text('深色')),
                ],
                selected: {_themeMode},
                onSelectionChanged: (selected) => setState(() => _themeMode = selected.first),
              ),
              const SizedBox(height: 24),
              Text('连接设置',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '支持 OpenAI 兼容的聊天补全接口。API Key 仅保存在本机。',
                style: TextStyle(color: dark ? Colors.white54 : Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _baseUrlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'API 地址',
                  hintText: 'https://api.openai.com/v1',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 13),
              TextField(
                controller: _apiKeyController,
                obscureText: _hideKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    tooltip: _hideKey ? '显示 API Key' : '隐藏 API Key',
                    onPressed: () => setState(() => _hideKey = !_hideKey),
                    icon: Icon(_hideKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              TextField(
                controller: _modelController,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: '模型',
                  hintText: 'gpt-4o-mini',
                  prefixIcon: Icon(Icons.smart_toy_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('保存设置'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
