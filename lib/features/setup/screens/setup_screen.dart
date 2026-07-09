import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/janus_config.dart';
import '../providers/setup_provider.dart';
import '../../live_stream/screens/live_stream_screen.dart';
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
    final s = ref.read(setupProvider);
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

  // Sync external state changes (e.g. from QR scan) into text controllers.
  void _syncControllers(SetupState s) {
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
      ref.read(setupProvider.notifier).applyConfig(result);
    }
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    final config = await ref.read(setupProvider.notifier).connect();
    if (config != null && mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => LiveStreamScreen(config: config),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setupProvider);
    final notifier = ref.read(setupProvider.notifier);

    // Keep text controllers in sync when QR populates fields.
    _syncControllers(state);

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  // ── Header ────────────────────────────────────────────────
                  _Header(),
                  const SizedBox(height: 32),

                  // ── QR Section ────────────────────────────────────────────
                  _QrSection(onTap: _openQrScanner),
                  const SizedBox(height: 24),

                  // ── OR divider ────────────────────────────────────────────
                  _OrDivider(),
                  const SizedBox(height: 24),

                  // ── Server URL ────────────────────────────────────────────
                  _FieldLabel('Janus Server URL'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _serverCtrl,
                    hint: 'https://my-janus-server.com',
                    keyboardType: TextInputType.url,
                    onChanged: notifier.setServerUrl,
                  ),
                  const SizedBox(height: 16),

                  // ── Room + Pin ─────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Room'),
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
                            _FieldLabel('Pin'),
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

                  // ── Display Name ──────────────────────────────────────────
                  _FieldLabel('Display Name'),
                  const SizedBox(height: 8),
                  _InputField(
                    controller: _nameCtrl,
                    hint: 'My First name & Last name',
                    onChanged: notifier.setDisplayName,
                  ),
                  const SizedBox(height: 20),

                  // ── Save as default ────────────────────────────────────────
                  _SaveCheckbox(
                    value: state.saveAsDefault,
                    onChanged: notifier.setSaveAsDefault,
                  ),
                  const SizedBox(height: 8),

                  // ── Error message ──────────────────────────────────────────
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 4),
                    _ErrorBanner(message: state.errorMessage!),
                    const SizedBox(height: 4),
                  ],
                  const SizedBox(height: 20),

                  // ── Connect button ────────────────────────────────────────
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

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // App logo square
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
        const Text(
          'App Title',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            letterSpacing: -0.3,
          ),
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
          child: Text(
            'Scan QR Code',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF3B6FF5),
              decoration: TextDecoration.underline,
              decorationColor: const Color(0xFF3B6FF5),
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
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // QR icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    size: 44,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to scan',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textGrey,
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
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: AppColors.border,
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
              color: AppColors.textGrey,
              letterSpacing: 1.4,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: AppColors.border,
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
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
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
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textGrey,
        ),
        filled: true,
        fillColor: AppColors.cardWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
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
              side: const BorderSide(color: AppColors.border, width: 1.5),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Save as default profile',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textDark,
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
        color: AppColors.liveRed.withOpacity(0.08),
        border: Border.all(color: AppColors.liveRed.withOpacity(0.3)),
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
          disabledBackgroundColor: AppColors.orange.withOpacity(0.6),
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
