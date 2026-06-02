import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/user.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';

/// Day-0 setup per hlth-onboarding-timeline.md §"Day 0: Setup".
///
/// Required: DOB, sex_at_birth.
/// Optional: height_cm, weight_kg, units, clock format, cycle tracking.
/// Mandatory disclaimer per hlth-regulatory-language-guide.md §"Required Disclaimers".
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _saving = false;

  // Form state
  DateTime? _dob;
  SexAtBirth? _sex;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _usesMetric = true;
  bool _uses24hClock = true;
  bool _cycleTrackingEnabled = false;
  DateTime? _lastPeriodStart;
  final _cycleLengthController = TextEditingController(text: '28');
  bool _disclaimerAccepted = false;

  @override
  void dispose() {
    _pageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _cycleLengthController.dispose();
    super.dispose();
  }

  // Pages: Welcome, Profile, (Cycle if female), Disclaimer
  int get _pageCount => _sex == SexAtBirth.female ? 4 : 3;

  // Disclaimer is the last page index regardless of female/not.
  int get _disclaimerIndex => _pageCount - 1;

  bool _canAdvanceFrom(int page) {
    if (page == 1) return _dob != null && _sex != null;
    if (page == 2 && _sex == SexAtBirth.female) {
      if (!_cycleTrackingEnabled) return true;
      return _lastPeriodStart != null;
    }
    if (page == _disclaimerIndex) return _disclaimerAccepted;
    return true;
  }

  Future<void> _next() async {
    if (!_canAdvanceFrom(_currentPage)) return;
    if (_currentPage < _pageCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _submit();
    }
  }

  Future<void> _submit() async {
    if (_dob == null || _sex == null) return;
    setState(() => _saving = true);
    try {
      final session = ref.read(activeSessionProvider);
      final userId = await session.ensureUser();

      final heightCm = _parseHeightCm();
      final weightKg = _parseWeightKg();

      await ref.read(userRepositoryProvider).upsertProfile(
            UserProfile(
              userId: userId,
              dateOfBirth: _dob,
              sexAtBirth: _sex!,
              heightCm: heightCm,
              weightKg: weightKg,
              usesMetric: _usesMetric,
              uses24hClock: _uses24hClock,
              cycleTrackingEnabled: _cycleTrackingEnabled,
              lastPeriodStartDate: _cycleTrackingEnabled ? _lastPeriodStart : null,
              typicalCycleLength: _cycleTrackingEnabled
                  ? int.tryParse(_cycleLengthController.text)
                  : null,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
      // Invalidate the profile guard so the router lets us in.
      ref.invalidate(userProfileProvider);
      if (mounted) context.go('/');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  double? _parseHeightCm() {
    final raw = double.tryParse(_heightController.text.trim());
    if (raw == null) return null;
    // Imperial input is inches; convert to cm.
    return _usesMetric ? raw : raw * 2.54;
  }

  double? _parseWeightKg() {
    final raw = double.tryParse(_weightController.text.trim());
    if (raw == null) return null;
    // Imperial input is lbs; convert to kg.
    return _usesMetric ? raw : raw * 0.45359237;
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _WelcomePage(),
      _ProfilePage(
        dob: _dob,
        sex: _sex,
        heightController: _heightController,
        weightController: _weightController,
        usesMetric: _usesMetric,
        uses24hClock: _uses24hClock,
        onPickDob: _pickDob,
        onSexChanged: (s) => setState(() => _sex = s),
        onUnitsChanged: (m) => setState(() => _usesMetric = m),
        onClockChanged: (h24) => setState(() => _uses24hClock = h24),
      ),
      if (_sex == SexAtBirth.female)
        _CyclePage(
          enabled: _cycleTrackingEnabled,
          lastPeriodStart: _lastPeriodStart,
          cycleLengthController: _cycleLengthController,
          onToggle: (v) => setState(() => _cycleTrackingEnabled = v),
          onPickLmp: _pickLmp,
        ),
      _DisclaimerPage(
        accepted: _disclaimerAccepted,
        onChanged: (v) => setState(() => _disclaimerAccepted = v),
      ),
    ];
    final canAdvance = _canAdvanceFrom(_currentPage);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                physics: const NeverScrollableScrollPhysics(),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pageCount, (i) {
                  return Container(
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? AppColors.primary
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving || !canAdvance ? null : _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_currentPage < _pageCount - 1
                          ? 'Next'
                          : 'Get Started'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 13, now.month, now.day),
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickLmp() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastPeriodStart ?? now.subtract(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
      helpText: 'Last period start',
    );
    if (picked != null) setState(() => _lastPeriodStart = picked);
  }
}

/// FutureProvider used by the router redirect: returns the current user's
/// profile (null if onboarding hasn't been completed).
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getProfile(ActiveSession.defaultUserId);
});

// ─────────────────────────────────────────────────────────────────────────
// Pages
// ─────────────────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'HLTH',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your wellness companion',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'A few details so your insights are tailored to you. Takes about a minute.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  final DateTime? dob;
  final SexAtBirth? sex;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final bool usesMetric;
  final bool uses24hClock;
  final VoidCallback onPickDob;
  final ValueChanged<SexAtBirth> onSexChanged;
  final ValueChanged<bool> onUnitsChanged;
  final ValueChanged<bool> onClockChanged;

  const _ProfilePage({
    required this.dob,
    required this.sex,
    required this.heightController,
    required this.weightController,
    required this.usesMetric,
    required this.uses24hClock,
    required this.onPickDob,
    required this.onSexChanged,
    required this.onUnitsChanged,
    required this.onClockChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About you', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            "Age and sex shape what counts as 'normal' for heart rate, HRV, "
            'and blood pressure norms — we need them to personalize.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          _Label('Date of birth *'),
          InkWell(
            onTap: onPickDob,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: dob == null ? AppColors.divider : AppColors.primary,
                ),
              ),
              child: Text(
                dob == null
                    ? 'Tap to select'
                    : '${dob!.year}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 20),

          _Label('Sex at birth *'),
          Row(
            children: [
              Expanded(
                child: _ChipButton(
                  label: 'Female',
                  selected: sex == SexAtBirth.female,
                  onTap: () => onSexChanged(SexAtBirth.female),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChipButton(
                  label: 'Male',
                  selected: sex == SexAtBirth.male,
                  onTap: () => onSexChanged(SexAtBirth.male),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _Label('Units'),
          Row(
            children: [
              Expanded(
                child: _ChipButton(
                  label: 'Metric (cm/kg)',
                  selected: usesMetric,
                  onTap: () => onUnitsChanged(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChipButton(
                  label: 'Imperial (in/lb)',
                  selected: !usesMetric,
                  onTap: () => onUnitsChanged(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Height (${usesMetric ? 'cm' : 'in'})'),
                    TextField(
                      controller: heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'Optional'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label('Weight (${usesMetric ? 'kg' : 'lb'})'),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'Optional'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _Label('Clock'),
          Row(
            children: [
              Expanded(
                child: _ChipButton(
                  label: '24-hour',
                  selected: uses24hClock,
                  onTap: () => onClockChanged(true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChipButton(
                  label: '12-hour',
                  selected: !uses24hClock,
                  onTap: () => onClockChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CyclePage extends StatelessWidget {
  final bool enabled;
  final DateTime? lastPeriodStart;
  final TextEditingController cycleLengthController;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickLmp;

  const _CyclePage({
    required this.enabled,
    required this.lastPeriodStart,
    required this.cycleLengthController,
    required this.onToggle,
    required this.onPickLmp,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cycle awareness',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Optional. Cycle phase affects resting HR, HRV, and sleep — '
            'tracking helps us avoid false signals.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            value: enabled,
            onChanged: onToggle,
            title: const Text('Enable cycle tracking'),
            contentPadding: EdgeInsets.zero,
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            _Label('Last period start date'),
            InkWell(
              onTap: onPickLmp,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: lastPeriodStart == null
                        ? AppColors.divider
                        : AppColors.primary,
                  ),
                ),
                child: Text(
                  lastPeriodStart == null
                      ? 'Tap to select'
                      : '${lastPeriodStart!.year}-${lastPeriodStart!.month.toString().padLeft(2, '0')}-${lastPeriodStart!.day.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _Label('Typical cycle length (days)'),
            TextField(
              controller: cycleLengthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '28'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DisclaimerPage extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const _DisclaimerPage({required this.accepted, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('One more thing',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(
              'HLTH is a wellness product. It is not a medical device and is '
              'not intended to diagnose, treat, cure, or prevent any disease. '
              'Always consult your healthcare provider for medical advice.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: accepted,
            onChanged: (v) => onChanged(v ?? false),
            title: const Text('I understand'),
            subtitle: const Text(
                'HLTH gives me wellness signals, not medical advice.'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
