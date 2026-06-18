// HLTH Edge Function — Premium Health Insights
//
// Validates JWT, checks premium subscription, queries daily_metrics
// and baselines, then returns a stub insight payload.
//
// Real ML/statistical logic is a separate workstream. This establishes
// the Edge Function infrastructure and auth/entitlement gating.
//
// Deploy: supabase functions deploy health-insights
// Test:   supabase functions serve, then curl with Authorization header

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. Validate JWT
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: { headers: { Authorization: authHeader } },
      }
    );

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Check premium subscription
    const { data: sub } = await supabase
      .from("subscriptions")
      .select("tier, is_active, expires_at")
      .eq("user_id", user.id)
      .eq("is_active", true)
      .order("started_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!sub || sub.tier !== "premium") {
      return new Response(
        JSON.stringify({ error: "Premium subscription required" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Check expiration
    if (sub.expires_at && new Date(sub.expires_at) < new Date()) {
      return new Response(
        JSON.stringify({ error: "Subscription expired" }),
        {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 3. Fetch recent daily_metrics for analysis
    const { data: metrics } = await supabase
      .from("daily_metrics")
      .select("*")
      .eq("user_id", user.id)
      .order("local_date", { ascending: false })
      .limit(30);

    // 4. Fetch baselines
    const { data: baselines } = await supabase
      .from("baselines")
      .select("*")
      .eq("user_id", user.id)
      .order("computed_for_date", { ascending: false })
      .limit(20);

    // 5. Generate stub insights
    // TODO: Replace with real ML/statistical analysis in a future workstream.
    const insights = {
      generated_at: new Date().toISOString(),
      days_analyzed: metrics?.length ?? 0,
      baselines_count: baselines?.length ?? 0,
      insights: [
        {
          type: "trend",
          metric: "resting_hr",
          title: "Resting Heart Rate Trend",
          summary:
            "Your resting heart rate data is being analyzed. Check back once more data is available.",
          confidence: 0.0,
        },
        {
          type: "correlation",
          metrics: ["sleep_efficiency", "recovery_score"],
          title: "Sleep & Recovery",
          summary:
            "Cross-metric correlation analysis will be available after 14 days of data.",
          confidence: 0.0,
        },
      ],
    };

    return new Response(JSON.stringify(insights), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
