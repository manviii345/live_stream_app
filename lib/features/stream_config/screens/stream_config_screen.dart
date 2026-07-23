import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/stream_config.dart';
import '../../../providers/app_state_provider.dart';
import '../../live_stream/providers/live_stream_provider.dart';

class StreamConfigScreen extends ConsumerStatefulWidget {
  const StreamConfigScreen({super.key});

  @override
  ConsumerState<StreamConfigScreen> createState() => _StreamConfigScreenState();
}

class _StreamConfigScreenState extends ConsumerState<StreamConfigScreen> {
  late StreamResolution _resolution;
  late int _fps;
  late double _bitrate;

  @override
  void initState() {
    super.initState();
    final config = ref.read(appStateProvider).streamConfig;
    _resolution = config.resolution;
    _fps = config.fps;
    _bitrate = config.bitrateKbps.toDouble();
  }

  Future<void> _applyChanges() async {
    final newConfig = StreamConfig(
      resolution: _resolution,
      fps: _fps,
      bitrateKbps: _bitrate.round(),
    );

    await ref.read(appStateProvider.notifier).applyStreamConfig(newConfig);

    if (mounted) {
      await ref.read(liveStreamProvider.notifier).applyStreamConfig(newConfig);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Stream configuration applied.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.orange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: _BackButton(),
        title: Text(
          'Stream Configuration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark(context),
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                children: [
                  const _SectionTitle(icon: Icons.high_quality_rounded, label: 'Resolution'),
                  const SizedBox(height: 14),
                  _ResolutionDropdown(
                    value: _resolution,
                    onChanged: (v) => setState(() => _resolution = v!),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SectionCard(
                children: [
                  const _SectionTitle(icon: Icons.speed_rounded, label: 'Frames per Second'),
                  const SizedBox(height: 8),
                  _FpsRadioGroup(
                    value: _fps,
                    onChanged: (v) => setState(() => _fps = v!),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SectionCard(
                children: [
                  const _SectionTitle(icon: Icons.tune_rounded, label: 'Bitrate'),
                  const SizedBox(height: 4),
                  _BitrateSlider(
                    value: _bitrate,
                    onChanged: (v) => setState(() => _bitrate = v),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              _ApplyButton(onPressed: _applyChanges),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite(context),
        borderRadius: BorderRadius.circular(18),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.orange),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark(context),
          ),
        ),
      ],
    );
  }
}

class _ResolutionDropdown extends StatelessWidget {
  final StreamResolution value;
  final ValueChanged<StreamResolution?> onChanged;

  const _ResolutionDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<StreamResolution>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.background(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
      ),
      dropdownColor: AppColors.cardWhite(context),
      icon: Icon(Icons.expand_more_rounded, color: AppColors.textGrey(context)),
      style: TextStyle(
        fontSize: 14,
        color: AppColors.textDark(context),
        fontWeight: FontWeight.w500,
      ),
      items: StreamResolution.values.map((res) {
        return DropdownMenuItem(
          value: res,
          child: Text(res.label),
        );
      }).toList(),
    );
  }
}

class _FpsRadioGroup extends StatelessWidget {
  final int value;
  final ValueChanged<int?> onChanged;

  const _FpsRadioGroup({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [30, 60].map((fps) {
        final selected = value == fps;
        return InkWell(
          onTap: () => onChanged(fps),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.orange.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.orange : AppColors.border(context),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Radio<int>(
                  value: fps,
                  groupValue: value,
                  onChanged: onChanged,
                  activeColor: AppColors.orange,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text(
                  '$fps FPS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color:
                        selected ? AppColors.textDark(context) : AppColors.textGrey(context),
                  ),
                ),
                const Spacer(),
                if (fps == 60)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B6FF5).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Smooth',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B6FF5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _BitrateSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _BitrateSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '300 kbps',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey(context)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${value.round()} kbps',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orange,
                ),
              ),
            ),
            Text(
              '4000 kbps',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey(context)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.orange,
            inactiveTrackColor: AppColors.border(context),
            thumbColor: AppColors.orange,
            overlayColor: AppColors.orange.withValues(alpha: 0.15),
            trackHeight: 4,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: value,
            min: 300,
            max: 4000,
            divisions: 74,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ApplyButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
        label: const Text(
          'Apply Changes',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardWhite(context),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 16,
          color: AppColors.textDark(context),
        ),
      ),
    );
  }
}
