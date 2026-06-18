import 'package:flutter/material.dart';

import 'package:hlth_app/ui/theme/app_colors.dart';

/// Static "Privacy & Data" surface. Accessible from the sign-up consent
/// link AND from Settings → Privacy & Data so users can revisit it.
///
/// V1.0 content is intentionally minimal: principles + data flows. A
/// versioned consent ledger (and the corresponding policy-text revision
/// hashes) lands in V1.1+ before public launch.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Privacy & Data'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Section(
                title: 'What we store',
                body:
                    'Your account email, profile (date of birth, sex, height, '
                    'weight if you share them), the band(s) you pair, and the '
                    'daily summaries we compute from your band readings '
                    '(resting heart rate, sleep summary, activity totals).',
              ),
              const _Section(
                title: 'Where we store it',
                body:
                    'All health data is stored in a Supabase database hosted '
                    'in Frankfurt, Germany (EU). Raw heart-rate and PPG sensor '
                    'data stays on your phone — only daily summaries leave the '
                    'device. We never sell your data and never share it with '
                    'advertisers.',
              ),
              const _Section(
                title: 'Who can see it',
                body:
                    'Only you. Row-level security on every table means even '
                    'we, as the operator, cannot read your records via the '
                    'normal app path. Internal support access requires a '
                    'logged service-role action that you can request a record '
                    'of at any time.',
              ),
              const _Section(
                title: 'Your rights',
                body:
                    'You can export your data, correct it, or delete your '
                    'account at any time. Deleting your account removes every '
                    'row tied to your user ID across all our systems. Export '
                    'and delete will be available in-app in the next release.',
              ),
              const SizedBox(height: 24),
              const _DisclaimerCard(),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete my account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Account deletion will land in the next release. '
                        'Email pool@99commerce.com to remove your account now.',
                      ),
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'HLTH is a wellness app, not a medical device. It does not '
              'diagnose, treat, or prevent any condition. Always consult '
              'a qualified healthcare provider for medical advice.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
