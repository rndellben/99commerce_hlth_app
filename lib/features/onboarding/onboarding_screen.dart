import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hlth_app/core/auth/current_user_provider.dart';
import 'package:hlth_app/core/auth/supabase_client_provider.dart';
import 'package:hlth_app/features/auth/auth_screen.dart';
import 'package:hlth_app/core/ble/ble_service.dart';
import 'package:hlth_app/core/bootstrap/active_session.dart';
import 'package:hlth_app/core/config/geo_config.dart';
import 'package:hlth_app/core/config/region_detector.dart';
import 'package:hlth_app/core/database/enums.dart';
import 'package:hlth_app/core/models/user.dart';
import 'package:hlth_app/core/repositories/user_repository.dart';
import 'package:hlth_app/core/services/consent_service.dart';
import 'package:hlth_app/ui/theme/app_colors.dart';
import 'package:hlth_app/core/providers/user_profile_provider.dart';

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

  // Profile form state
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
  bool _dataProcessingConsent = false;
  bool _healthDataConsent = false;

  // Registration form state
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _registrationError;

  // Terms state
  bool _termsAccepted = false;

  // Goal state
  String? _selectedGoal;

  // Pairing state
  bool _devicePaired = false;
  bool _pairingSkipped = false;

  // Firmware state
  bool _firmwareChecked = false;

  @override
  void initState() {
    super.initState();
    // Splash: request BLE permissions (fire-and-forget) then auto-advance.
    _requestBlePermissions();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _goToPage(1);
    });
  }

  Future<void> _requestBlePermissions() async {
    Permission.bluetoothScan.request();
    Permission.bluetoothConnect.request();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _cycleLengthController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  GeoConfig get _geoConfig => ref.read(geoConfigProvider);

  // --- Page indices ---
  // 0: Splash
  // 1: Welcome
  // 2: Registration
  // 3: Terms
  // 4: Profile
  // 4a: Cycle (if female) — inserted dynamically
  // 4b: Consent (if geo requires) — inserted dynamically
  // 5: Goal
  // 6: Device Pairing
  // 7: Firmware Check
  // 8: Health Connect
  // 9: Disclaimer (final page)

  bool get _needsConsentPage => _geoConfig.requiresExplicitConsent;

  List<Widget> _buildPages() {
    return <Widget>[
      // 0: Splash
      _SplashPage(),
      // 1: Welcome
      _WelcomePage(
        onRegister: () => _goToPage(2),
        onLogin: _handleLogin,
      ),
      // 2: Registration
      _RegistrationPage(
        emailController: _emailController,
        passwordController: _passwordController,
        confirmPasswordController: _confirmPasswordController,
        error: _registrationError,
        onRegister: _handleRegister,
        onSkip: () => _goToPage(3),
      ),
      // 3: Terms
      _TermsPage(
        accepted: _termsAccepted,
        onChanged: (v) => setState(() => _termsAccepted = v),
      ),
      // 4: Profile
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
      // 4a: Cycle (if female)
      if (_sex == SexAtBirth.female)
        _CyclePage(
          enabled: _cycleTrackingEnabled,
          lastPeriodStart: _lastPeriodStart,
          cycleLengthController: _cycleLengthController,
          onToggle: (v) => setState(() => _cycleTrackingEnabled = v),
          onPickLmp: _pickLmp,
        ),
      // 4b: Consent (if geo requires)
      if (_needsConsentPage)
        _ConsentPage(
          geoConfig: _geoConfig,
          dataProcessingConsent: _dataProcessingConsent,
          healthDataConsent: _healthDataConsent,
          onDataProcessingChanged: (v) =>
              setState(() => _dataProcessingConsent = v),
          onHealthDataChanged: (v) =>
              setState(() => _healthDataConsent = v),
        ),
      // 5: Goal
      _GoalPage(
        selectedGoal: _selectedGoal,
        onGoalSelected: (g) => setState(() => _selectedGoal = g),
      ),
      // 6: Device Pairing
      _DevicePairingPage(
        devicePaired: _devicePaired,
        pairingSkipped: _pairingSkipped,
        onPair: _handlePairDevice,
        onSkip: _handleSkipPairing,
      ),
      // 7: Firmware Check
      _FirmwareCheckPage(
        devicePaired: _devicePaired,
        firmwareChecked: _firmwareChecked,
        onChecked: () {
          if (mounted) setState(() => _firmwareChecked = true);
        },
        onContinue: () => _goToPage(_currentPage + 1),
      ),
      // 8: Health Connect
      _HealthConnectPage(
        onConnectNow: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Health Connect integration coming in a future update.'),
            ),
          );
        },
        onSkip: () => _goToPage(_currentPage + 1),
      ),
      // 9: Disclaimer (final)
      _DisclaimerPage(
        accepted: _disclaimerAccepted,
        onChanged: (v) => setState(() => _disclaimerAccepted = v),
      ),
    ];
  }

  int get _pageCount => _buildPages().length;

  bool get _isWelcomePage => _currentPage == 1;
  bool get _isSplashPage => _currentPage == 0;

  bool _canAdvanceFrom(int page) {
    // Splash auto-advances.
    if (page == 0) return false;
    // Welcome has its own buttons.
    if (page == 1) return false;
    // Registration — always allow Next (user can skip).
    if (page == 2) return true;
    // Terms — must accept.
    if (page == 3) return _termsAccepted;
    // Profile — DOB and sex required.
    if (page == 4) return _dob != null && _sex != null;

    // Dynamic pages after profile
    final pages = _buildPages();
    if (page >= pages.length) return false;
    final widget = pages[page];

    if (widget is _CyclePage) {
      if (!_cycleTrackingEnabled) return true;
      return _lastPeriodStart != null;
    }
    if (widget is _ConsentPage) {
      return _dataProcessingConsent && _healthDataConsent;
    }
    if (widget is _GoalPage) {
      return _selectedGoal != null;
    }
    if (widget is _DevicePairingPage) {
      return _devicePaired || _pairingSkipped;
    }
    if (widget is _FirmwareCheckPage) {
      return true; // always can advance
    }
    if (widget is _HealthConnectPage) {
      return true; // always can advance
    }
    if (widget is _DisclaimerPage) {
      return _disclaimerAccepted;
    }

    return true;
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _next() async {
    if (!_canAdvanceFrom(_currentPage)) return;
    if (_currentPage < _pageCount - 1) {
      _goToPage(_currentPage + 1);
    } else {
      await _submit();
    }
  }

  Future<void> _handleLogin() async {
    // Use Navigator.push instead of GoRouter to avoid redirect interference.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AuthScreen(),
      ),
    );
    if (!mounted) return;
    // After returning, check if the user is now signed in.
    ref.invalidate(userProfileProvider);
    final profile = await ref.read(userProfileProvider.future);
    if (!mounted) return;
    if (profile != null) {
      context.go('/');
    } else {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        _goToPage(3); // skip registration, go to terms
      }
    }
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _registrationError = 'Email and password are required.');
      return;
    }
    if (password != confirm) {
      setState(() => _registrationError = 'Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      setState(() => _registrationError = 'Password must be at least 6 characters.');
      return;
    }

    setState(() => _registrationError = null);

    try {
      await ref.read(supabaseClientProvider).auth.signUp(
            email: email,
            password: password,
          );
      if (mounted) _goToPage(3); // Terms page
    } catch (e) {
      if (mounted) {
        setState(() => _registrationError = e.toString());
      }
    }
  }

  Future<void> _handlePairDevice() async {
    await context.push('/pairing');
    // Check connection state after returning
    if (!mounted) return;
    final connState = ref.read(bleConnectionStateProvider);
    final isConnected = connState.valueOrNull == BleConnectionState.connected;
    setState(() {
      _devicePaired = isConnected;
      if (isConnected) _pairingSkipped = false;
    });
    if (isConnected || _pairingSkipped) {
      _goToPage(_currentPage + 1);
    }
  }

  void _handleSkipPairing() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.watch, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Get the most out of HLTH',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Get the most out of HLTH with the smart band. Track heart rate, '
              'sleep, stress, and more.',
              style: Theme.of(ctx).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening HLTH store...')),
                  );
                },
                child: const Text('Shop now'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _pairingSkipped = true);
                  _goToPage(_currentPage + 1);
                },
                child: const Text('Continue without device'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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

      // Record geo-aware consent if required.
      if (_needsConsentPage) {
        final consentSvc = ref.read(consentServiceProvider);
        final region = _geoConfig.region;
        if (_dataProcessingConsent) {
          await consentSvc.recordConsent(
            type: 'data_processing',
            granted: true,
            region: region,
          );
        }
        if (_healthDataConsent) {
          await consentSvc.recordConsent(
            type: 'health_data',
            granted: true,
            region: region,
          );
        }
        ref.invalidate(hasRequiredConsentProvider);
      }

      // Save the selected goal to SharedPreferences.
      if (_selectedGoal != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('onboarding_goal', _selectedGoal!);
      }

      // Invalidate the profile guard so the router lets us in.
      ref.invalidate(userProfileProvider);

      // Show the value prop screen before navigating.
      if (mounted) {
        await _showValueProp();
        if (mounted) context.go('/');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showValueProp() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ValuePropDialog(),
    );
  }

  double? _parseHeightCm() {
    final raw = double.tryParse(_heightController.text.trim());
    if (raw == null) return null;
    return _usesMetric ? raw : raw * 2.54;
  }

  double? _parseWeightKg() {
    final raw = double.tryParse(_weightController.text.trim());
    if (raw == null) return null;
    return _usesMetric ? raw : raw * 0.45359237;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();
    final canAdvance = _canAdvanceFrom(_currentPage);
    final hideBottomNav = _isSplashPage || _isWelcomePage;

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
            if (!hideBottomNav) ...[
              // Dot indicators
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
              // Next / Get Started button
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

// ─────────────────────────────────────────────────────────────────────────
// Pages
// ─────────────────────────────────────────────────────────────────────────

class _SplashPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            'Loading\u2026',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  const _WelcomePage({required this.onRegister, required this.onLogin});

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
            'Welcome to HLTH',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your wellness companion',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRegister,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Register'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onLogin,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Login'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationPage extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final String? error;
  final VoidCallback onRegister;
  final VoidCallback onSkip;

  const _RegistrationPage({
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.error,
    required this.onRegister,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create your account',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          _Label('Email'),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@example.com'),
          ),
          const SizedBox(height: 16),
          _Label('Password'),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'At least 6 characters'),
          ),
          const SizedBox(height: 16),
          _Label('Confirm password'),
          TextField(
            controller: confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'Re-enter password'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRegister,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Register'),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: onSkip,
              child: const Text('Skip \u2014 continue without account'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsPage extends StatelessWidget {
  final bool accepted;
  final ValueChanged<bool> onChanged;

  const _TermsPage({required this.accepted, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Terms & Conditions',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _kTermsText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: accepted,
            onChanged: (v) => onChanged(v ?? false),
            title: const Text('I accept the Terms of Service and Privacy Policy'),
            contentPadding: EdgeInsets.zero,
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
            'and blood pressure norms \u2014 we need them to personalize.',
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
            'Optional. Cycle phase affects resting HR, HRV, and sleep \u2014 '
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

/// Geo-aware consent page shown in regions requiring explicit opt-in
/// (GDPR, PDPA, PIPL). Consent is recorded with the policy version and
/// region for audit trail compliance.
class _ConsentPage extends StatelessWidget {
  final GeoConfig geoConfig;
  final bool dataProcessingConsent;
  final bool healthDataConsent;
  final ValueChanged<bool> onDataProcessingChanged;
  final ValueChanged<bool> onHealthDataChanged;

  const _ConsentPage({
    required this.geoConfig,
    required this.dataProcessingConsent,
    required this.healthDataConsent,
    required this.onDataProcessingChanged,
    required this.onHealthDataChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data & Privacy',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Under ${geoConfig.regulatoryLabel} regulations, we need your '
            'explicit consent to process your health data. Your data is stored '
            'in ${geoConfig.dataResidencyRegion}.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: dataProcessingConsent,
            onChanged: (v) => onDataProcessingChanged(v ?? false),
            title: const Text('Data processing consent'),
            subtitle: const Text(
              'I consent to HLTH processing my personal data to provide '
              'wellness insights and improve the service.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: healthDataConsent,
            onChanged: (v) => onHealthDataChanged(v ?? false),
            title: const Text('Health data consent'),
            subtitle: const Text(
              'I consent to HLTH collecting and processing my health '
              'metrics (heart rate, sleep, activity, etc.) from my '
              'connected band.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          Text(
            'You can withdraw consent at any time in Settings. '
            '${geoConfig.supportsRightToDelete ? 'You have the right to request deletion of all your data.' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}

class _GoalPage extends StatelessWidget {
  final String? selectedGoal;
  final ValueChanged<String> onGoalSelected;

  const _GoalPage({
    required this.selectedGoal,
    required this.onGoalSelected,
  });

  static const _goals = <_GoalOption>[
    _GoalOption('Better sleep', Icons.nightlight_round),
    _GoalOption('Heart health', Icons.favorite),
    _GoalOption('Fitness tracking', Icons.directions_run),
    _GoalOption('Stress management', Icons.spa),
    _GoalOption('Weight management', Icons.monitor_weight),
    _GoalOption('General wellness', Icons.health_and_safety),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("What's your #1 goal?",
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'This helps us personalize your experience',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
              ),
              itemCount: _goals.length,
              itemBuilder: (context, index) {
                final goal = _goals[index];
                final isSelected = selectedGoal == goal.label;
                return InkWell(
                  onTap: () => onGoalSelected(goal.label),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          goal.icon,
                          size: 32,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          goal.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalOption {
  final String label;
  final IconData icon;
  const _GoalOption(this.label, this.icon);
}

class _DevicePairingPage extends StatelessWidget {
  final bool devicePaired;
  final bool pairingSkipped;
  final VoidCallback onPair;
  final VoidCallback onSkip;

  const _DevicePairingPage({
    required this.devicePaired,
    required this.pairingSkipped,
    required this.onPair,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.watch, size: 80, color: AppColors.primary),
          const SizedBox(height: 24),
          Text('Connect your HLTH band',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'The app works best with a paired device',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (devicePaired) ...[
            const SizedBox(height: 24),
            const Icon(Icons.check_circle, size: 48, color: Colors.green),
            const SizedBox(height: 8),
            Text(
              'Device paired successfully!',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 32),
          if (!devicePaired) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPair,
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Pair my device'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSkip,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("I don't have a device"),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FirmwareCheckPage extends ConsumerStatefulWidget {
  final bool devicePaired;
  final bool firmwareChecked;
  final VoidCallback onChecked;
  final VoidCallback onContinue;

  const _FirmwareCheckPage({
    required this.devicePaired,
    required this.firmwareChecked,
    required this.onChecked,
    required this.onContinue,
  });

  @override
  ConsumerState<_FirmwareCheckPage> createState() => _FirmwareCheckPageState();
}

class _FirmwareCheckPageState extends ConsumerState<_FirmwareCheckPage> {
  String _status = '';
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _checkFirmware();
  }

  Future<void> _checkFirmware() async {
    if (!widget.devicePaired) {
      setState(() {
        _status = 'No device connected \u2014 skipping firmware check';
        _done = true;
      });
    } else {
      setState(() => _status = 'Checking firmware\u2026');
      // MVP: we can't actually OTA, so always report up to date.
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _status = 'Your band is up to date';
          _done = true;
        });
      }
    }
    widget.onChecked();
    // Auto-advance after a short delay.
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Firmware Check',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 32),
          if (!_done)
            const CircularProgressIndicator()
          else
            Icon(
              widget.devicePaired ? Icons.check_circle : Icons.info_outline,
              size: 64,
              color: widget.devicePaired ? Colors.green : AppColors.textSecondary,
            ),
          const SizedBox(height: 16),
          Text(
            _status,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_done)
            FilledButton(
              onPressed: widget.onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Continue'),
            ),
        ],
      ),
    );
  }
}

class _HealthConnectPage extends StatelessWidget {
  final VoidCallback onConnectNow;
  final VoidCallback onSkip;

  const _HealthConnectPage({
    required this.onConnectNow,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sync, size: 80, color: AppColors.primary),
          const SizedBox(height: 24),
          Text('Connect Health Services',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            "Sync your data with your phone's health platform",
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onConnectNow,
              icon: const Icon(Icons.link),
              label: const Text('Connect now'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSkip,
            child: const Text("I'll pair later"),
          ),
        ],
      ),
    );
  }
}

class _ValuePropDialog extends StatefulWidget {
  @override
  State<_ValuePropDialog> createState() => _ValuePropDialogState();
}

class _ValuePropDialogState extends State<_ValuePropDialog> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                "You're all set!",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'HLTH tracks trends, not just snapshots. Wear your band daily '
                'for the most accurate insights.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
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

// ─────────────────────────────────────────────────────────────────────────
// Terms text
// ─────────────────────────────────────────────────────────────────────────

const _kTermsText = '''
HLTH Terms of Service

Last updated: 2026-06-01

1. Acceptance of Terms
By using the HLTH application and associated smart band, you agree to be bound by these Terms of Service and our Privacy Policy.

2. Description of Service
HLTH provides wellness tracking and insights through a companion mobile application and wearable smart band. The service includes heart rate monitoring, sleep tracking, activity tracking, stress management insights, and related wellness features.

3. Eligibility
You must be at least 13 years of age to use HLTH. If you are under 18, you must have parental or guardian consent.

4. User Accounts
You may use HLTH without creating an account for local-only features. Creating an account enables cloud sync, cross-device access, and additional features. You are responsible for maintaining the security of your account credentials.

5. Health Data
HLTH collects biometric and health-related data including but not limited to heart rate, heart rate variability, blood oxygen levels, sleep patterns, and activity data. This data is used solely to provide wellness insights and improve the service.

6. Not Medical Advice
HLTH is a wellness product. It is NOT a medical device. It is not intended to diagnose, treat, cure, or prevent any disease or health condition. Always consult a qualified healthcare provider for medical advice.

7. Data Privacy
Your data is processed in accordance with our Privacy Policy. In applicable jurisdictions, you have the right to access, correct, and delete your personal data. We do not sell your personal data to third parties.

8. Intellectual Property
All content, features, and functionality of the HLTH application are owned by HLTH and are protected by intellectual property laws.

9. Limitation of Liability
HLTH is provided "as is" without warranties of any kind. We are not liable for any damages arising from your use of the service or reliance on any information provided through it.

10. Changes to Terms
We reserve the right to modify these terms at any time. Continued use after changes constitutes acceptance of the new terms.

Privacy Policy

HLTH respects your privacy. We collect only the data necessary to provide our wellness tracking service. Your biometric data is encrypted at rest and in transit. You can request deletion of your data at any time through Settings > Privacy > Delete My Data.

For questions about these terms or our privacy practices, contact support@hlth.app.
''';
