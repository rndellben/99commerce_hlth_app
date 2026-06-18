import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hlth_app/core/auth/supabase_client_provider.dart';
import 'package:hlth_app/core/services/supabase_connection_monitor.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Insight returned by the health-insights Edge Function.
class HealthInsight {
  const HealthInsight({
    required this.type,
    required this.title,
    required this.summary,
    required this.confidence,
    this.metric,
    this.metrics,
  });

  final String type; // 'trend', 'correlation', 'alert'
  final String title;
  final String summary;
  final double confidence; // 0.0 – 1.0
  final String? metric;
  final List<String>? metrics;

  factory HealthInsight.fromJson(Map<String, dynamic> json) => HealthInsight(
        type: json['type'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        metric: json['metric'] as String?,
        metrics: (json['metrics'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
      );
}

/// Result from the health-insights Edge Function.
class InsightsResult {
  const InsightsResult({
    required this.generatedAt,
    required this.daysAnalyzed,
    required this.insights,
  });

  final DateTime generatedAt;
  final int daysAnalyzed;
  final List<HealthInsight> insights;
}

/// Client for the health-insights Supabase Edge Function.
///
/// Gated behind `featureGate.aiInsights` — callers must check the gate
/// before invoking. The Edge Function itself also validates the
/// subscription server-side (defense in depth).
class ServerInsightsService {
  ServerInsightsService(this._client);

  final SupabaseClient _client;

  /// Fetch AI-powered health insights. Throws on auth or subscription errors.
  Future<InsightsResult> fetchInsights() async {
    return SupabaseConnectionMonitor.withRetry(() async {
      final response = await _client.functions.invoke(
        'health-insights',
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final body = response.data;
        final error = body is Map ? body['error'] : 'Unknown error';
        throw Exception('Insights API error (${ response.status}): $error');
      }

      final data = response.data as Map<String, dynamic>;
      return InsightsResult(
        generatedAt: DateTime.parse(data['generated_at'] as String),
        daysAnalyzed: data['days_analyzed'] as int,
        insights: (data['insights'] as List<dynamic>)
            .map((e) => HealthInsight.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    });
  }
}

final serverInsightsServiceProvider = Provider<ServerInsightsService>((ref) {
  return ServerInsightsService(ref.watch(supabaseClientProvider));
});
