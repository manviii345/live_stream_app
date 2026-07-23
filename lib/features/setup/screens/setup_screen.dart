import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/janus_config.dart';
import '../../../providers/app_state_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../live_stream/screens/live_stream_screen.dart';
import '../../../services/janus_service.dart';
import 'qr_scanner_sheet.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  late final TextEditingController _serverCtrl;
  late final TextEditingController _roomCtrl;
  late final TextEditingController _pinCtrl;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(appStateProvider);
    _serverCtrl = TextEditingController(text: s.serverUrl);
    _roomCtrl = TextEditingController(text: s.roomId);
    _pinCtrl = TextEditingController(text: s.pin);
    _nameCtrl = TextEditingController(text: s.displayName);
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    _roomCtrl.dispose();
    _pinCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _syncControllers(AppState s) {
    if (_serverCtrl.text != s.serverUrl) {
      _serverCtrl.text = s.serverUrl;
      _serverCtrl.selection =
          TextSelection.collapsed(offset: s.serverUrl.length);
    }
    if (_roomCtrl.text != s.roomId) {
      _roomCtrl.text = s.roomId;
      _roomCtrl.selection =
          TextSelection.collapsed(offset: s.roomId.length);
    }
    if (_pinCtrl.text != s.pin) {
      _pinCtrl.text = s.pin;
      _pinCtrl.selection = TextSelection.collapsed(offset: s.pin.length);
    }
    if (_nameCtrl.text != s.displayName) {
      _nameCtrl.text = s.displayName;
      _nameCtrl.selection =
          TextSelection.collapsed(offset: s.displayName.length);
    }
  }

  Future<void> _openQrScanner() async {
    final result = await showModalBottomSheet<JanusConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QrScannerSheet(),
    );
    if (result != null && mounted) {
      ref.read(appStateProvider.notifier).applyJanusConfig(result);
    }
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    final notifier = ref.read(appStateProvider.notifier);

    final config = await notifier.connect();
    if (config == null || !mounted) return;

    try {
      final streamConfig = ref.read(appStateProvider).streamConfig;
      await ref.read(janusServiceProvider).joinRoom(config, streamConfig);

      if (!mounted) return;
      notifier.clearConnecting();

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const LiveStreamScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } catch (e) {
      if (mounted) notifier.setError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);

    _syncControllers(state);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hPad = constraints.maxWidth > 600 ? 40.0 : 24.0;
            return SingleChildScrollView(
              padding:
                  EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Header(),
                  const SizedBox(height: 32),

                  _QrSection(onTap: _openQrScanner),
                  const SizedBox(height: 24),

                  const _OrDivider(),
                  const SizedBox(height: 24),

                  const _FieldLabel('Janus Server URL'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _serverCtrl,
                    hint: 'https://my-janus-server.com',
                    keyboardType: TextInputType.url,
                    onChanged: notifier.setServerUrl,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Room'),
                            const SizedBox(height: 8),
                            _InputField(
                              controller: _roomCtrl,
                              hint: '1234',
                              keyboardType: TextInputType.number,
                              onChanged: notifier.setRoomId,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Pin'),
                            const SizedBox(height: 8),
                            _InputField(
                              controller: _pinCtrl,
                              hint: '••••••••',
                              obscure: true,
                              onChanged: notifier.setPin,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const _FieldLabel('Display Name'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _nameCtrl,
                    hint: 'My First name & Last name',
                    onChanged: notifier.setDisplayName,
                  ),
                  const SizedBox(height: 20),

                  _SaveCheckbox(
                    value: state.saveAsDefault,
                    onChanged: notifier.setSaveAsDefault,
                  ),
                  const SizedBox(height: 8),

                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 4),
                    _ErrorBanner(message: state.errorMessage!),
                    const SizedBox(height: 4),
                  ],
                  const SizedBox(height: 20),

                  _ConnectButton(
                    isLoading: state.isConnecting,
                    onTap: state.isConnecting ? null : _connect,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF3B6FF5),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text(
            'L',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          'App Title',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark(context),
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: AppColors.textDark(context),
          ),
          tooltip: isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme',
          onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
        ),
      ],
    );
  }
}

class _QrSection extends StatelessWidget {
  final VoidCallback onTap;
  const _QrSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: const Text(
            'Scan QR Code',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF3B6FF5),
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF3B6FF5),
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.cardWhite(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.background(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: 44,
                    color: AppColors.textDark(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to scan',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: AppColors.border(context),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textGrey(context),
              letterSpacing: 1.4,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: AppColors.border(context),
            thickness: 1,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark(context),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 14,
        color: AppColors.textDark(context),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: AppColors.textGrey(context),
        ),
        filled: true,
        fillColor: AppColors.cardWhite(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF3B6FF5), width: 1.5),
        ),
      ),
    );
  }
}

class _SaveCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SaveCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: const Color(0xFF3B6FF5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: BorderSide(color: AppColors.border(context), width: 1.5),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Save as default profile',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textDark(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.liveRed.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.liveRed.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 16, color: AppColors.liveRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.liveRed),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onTap;

  const _ConnectButton({required this.isLoading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Connect to Server',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
      ),
    );
  }
}
