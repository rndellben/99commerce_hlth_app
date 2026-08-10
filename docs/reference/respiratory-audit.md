The literature confirms exactly the concern I had. Here's my full review of the ectopic cleaning and quality gate as they stand today.

18:12:52 persisted resp=21.1 irregularity=7.7% ectopic=4.0% for today

18:12:52 → R-R series ready (125 intervals) — tap the R-R export button to copy for tuning

18:12:52 respiratory rate (RSA from R-R): 21.1 breaths/min

18:12:52 rhythm: R-R irregularity (CoV) = 7.7%, ectopic beats = 4.0%

18:12:52 quality gate: PASS

18:12:52 HRV freq: lf=21ms² hf=140ms² lf/hf=0.15

18:12:52 HRV: rmssd=30.1ms sdnn=19.3ms pnn50=10.9%

18:12:52 ectopic cleaning (HeartPy moving-median, window=9, ±30%): 125 → 120 (5 dropped)

18:12:52 HR: 94.3 bpm

18:12:52 cardiac: 127 peaks, 125 valid R-R intervals (300-2000ms, sub-sample refined)

18:12:52 using polarity: as-is

18:12:52 peaks: as-is=127, inverted=114

18:12:52 bandpassed (0.5-5Hz, trimmed ±2s): min=-220.9 max=101.3 std=35.41

18:12:52 resampled 2070 → 6750 samples @ 75Hz, dc=27073 removed

18:12:52 raw: min=26007 max=28187 mean=27073 std=565.0

18:12:52 green=0 blanks (poor contact): 1

18:12:52 ppg_count: 1957 received, 115 lost in transit (6% BLE loss), 2 dup

18:12:52 Analyze: counter-based timing — 1956 real samples across 2070 band-indices (6% interpolated) over 91.1s → fs_band ≈ 23 Hz

18:12:52 realtime HR: 103 bpm

18:12:52 realtime HR: 103 bpm

6:14

{

"captured_at": "2026-06-23T18:13:18.091566",

"hr_bpm": 94.3,

"fs_band_hz": 23,

"ble_loss_pct": 5.6,

"passed_quality_gate": true,

"ectopic_dropped": 5,

"rr_irregularity_pct": 7.7,

"ectopic_beat_pct": 4.0,

"rr_raw_ms": [622.8, 615.3, 661.1, 630.5, 632.7, 640.2, 648.1, 605.7, 640.7, 640.5, 631.8, 611.9, 623.2, 644.1, 632.8, 640.8, 646.3, 605.2, 625.0, 616.8, 651.9, 641.3, 626.3, 600.9, 642.4, 660.7, 632.8, 627.0, 616.6, 635.5, 630.9, 619.5, 632.7, 647.7, 621.2, 618.5, 599.1, 669.0, 626.4, 429.5, 840.6, 597.6, 651.0, 605.9, 640.2, 644.8, 604.2, 642.8, 583.6, 657.7, 629.5, 625.7, 1212.7, 635.1, 638.9, 609.7, 613.8, 638.3, 634.2, 906.9, 328.7, 640.4, 612.8, 602.8, 617.8, 649.9, 637.1, 627.6, 615.6, 648.4, 641.6, 639.5, 644.4, 579.0, 650.7, 638.8, 623.5, 607.5, 627.1, 667.2, 671.5, 594.7, 650.3, 648.2, 641.6, 632.7, 636.1, 668.8, 621.6, 644.6, 634.4, 621.1, 636.0, 615.1, 595.4, 651.9, 635.4, 638.9, 642.7, 636.2, 684.6, 633.7, 645.2, 657.5, 654.9, 624.8, 643.5, 624.8, 618.9, 669.6, 593.3, 657.8, 621.1, 632.1, 619.6, 644.7, 625.2, 604.8, 654.8, 611.2, 635.4, 643.7, 607.6, 629.6, 618.3],

"rr_cleaned_ms": [622.8, 615.3, 661.1, 630.5, 632.7, 640.2, 648.1, 605.7, 640.7, 640.5, 631.8, 611.9, 623.2, 644.1, 632.8, 640.8, 646.3, 605.2, 625.0, 616.8, 651.9, 641.3, 626.3, 600.9, 642.4, 660.7, 632.8, 627.0, 616.6, 635.5, 630.9, 619.5, 632.7, 647.7, 621.2, 618.5, 599.1, 669.0, 626.4, 597.6, 651.0, 605.9, 640.2, 644.8, 604.2, 642.8, 583.6, 657.7, 629.5, 625.7, 635.1, 638.9, 609.7, 613.8, 638.3, 634.2, 640.4, 612.8, 602.8, 617.8, 649.9, 637.1, 627.6, 615.6, 648.4, 641.6, 639.5, 644.4, 579.0, 650.7, 638.8, 623.5, 607.5, 627.1, 667.2, 671.5, 594.7, 650.3, 648.2, 641.6, 632.7, 636.1, 668.8, 621.6, 644.6, 634.4, 621.1, 636.0, 615.1, 595.4, 651.9, 635.4, 638.9, 642.7, 636.2, 684.6, 633.7, 645.2, 657.5, 654.9, 624.8, 643.5, 624.8, 618.9, 669.6, 593.3, 657.8, 621.1, 632.1, 619.6, 644.7, 625.2, 604.8, 654.8, 611.2, 635.4, 643.7, 607.6, 629.6, 618.3]

}
17:41:12 PPG capture: stopped — total packets=2242

17:41:11 realtime HR: 105 bpm

17:41:11 PPG packet (1 samples): {timestamp_ms: 1782207671164, ppg_count: 70, green: 28028, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:11 PPG packet (1 samples): {timestamp_ms: 1782207671159, ppg_count: 69, green: 28091, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:11 PPG packet (1 samples): {timestamp_ms: 1782207671156, ppg_count: 68, green: 28086, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:11 PPG packet (1 samples): {timestamp_ms: 1782207671067, ppg_count: 67, green: 28072, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:11 PPG packet (1 samples): {timestamp_ms: 1782207671046, ppg_count: 66, green: 28057, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:11 PPG packet (1 samples): {timestamp_ms: 1782207671042, ppg_count: 65, green: 28043, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670936, ppg_count: 64, green: 28033, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670932, ppg_count: 63, green: 28031, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670930, ppg_count: 62, green: 28043, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670820, ppg_count: 61, green: 28035, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670819, ppg_count: 60, green: 28059, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670816, ppg_count: 59, green: 28077, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670710, ppg_count: 58, green: 28117, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670707, ppg_count: 57, green: 28190, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670703, ppg_count: 56, green: 28276, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670590, ppg_count: 55, green: 28344, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670482, ppg_count: 54, green: 28360, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670479, ppg_count: 53, green: 28355, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670375, ppg_count: 52, green: 28347, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670372, ppg_count: 51, green: 28360, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670368, ppg_count: 50, green: 28380, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670264, ppg_count: 49, green: 28401, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670260, ppg_count: 48, green: 28446, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670256, ppg_count: 47, green: 28472, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670156, ppg_count: 46, green: 28504, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670156, ppg_count: 45, green: 28543, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670156, ppg_count: 44, green: 28593, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670080, ppg_count: 43, green: 28682, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670080, ppg_count: 42, green: 28782, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207670079, ppg_count: 41, green: 28861, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207669945, ppg_count: 40, green: 28881, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:10 PPG packet (1 samples): {timestamp_ms: 1782207669944, ppg_count: 39, green: 28859, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669916, ppg_count: 38, green: 28851, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669814, ppg_count: 37, green: 28862, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669811, ppg_count: 36, green: 28862, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669806, ppg_count: 35, green: 28874, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669804, ppg_count: 34, green: 28902, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669699, ppg_count: 33, green: 28927, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669693, ppg_count: 32, green: 28952, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669603, ppg_count: 31, green: 28991, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669583, ppg_count: 30, green: 29055, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669580, ppg_count: 29, green: 29143, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669474, ppg_count: 28, green: 29227, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669470, ppg_count: 27, green: 29293, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669466, ppg_count: 26, green: 29307, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669360, ppg_count: 25, green: 29308, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669356, ppg_count: 24, green: 29303, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669354, ppg_count: 23, green: 29297, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669249, ppg_count: 22, green: 29307, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669245, ppg_count: 21, green: 29316, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669243, ppg_count: 20, green: 29321, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669167, ppg_count: 19, green: 29324, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669134, ppg_count: 18, green: 29325, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669130, ppg_count: 17, green: 29342, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669038, ppg_count: 16, green: 29377, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669037, ppg_count: 15, green: 29427, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:09 PPG packet (1 samples): {timestamp_ms: 1782207669015, ppg_count: 14, green: 29482, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668911, ppg_count: 13, green: 29521, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668907, ppg_count: 12, green: 29509, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668904, ppg_count: 11, green: 29492, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668708, ppg_count: 10, green: 29489, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668708, ppg_count: 9, green: 29472, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668708, ppg_count: 8, green: 29451, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668685, ppg_count: 7, green: 29451, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668681, ppg_count: 6, green: 29445, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668678, ppg_count: 5, green: 29426, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668462, ppg_count: 4, green: 29412, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668459, ppg_count: 3, green: 29413, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668455, ppg_count: 2, green: 29416, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668351, ppg_count: 1, green: 29452, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668347, ppg_count: 0, green: 29474, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668343, ppg_count: 255, green: 29480, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668265, ppg_count: 254, green: 29454, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668233, ppg_count: 253, green: 29421, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668229, ppg_count: 252, green: 29407, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668139, ppg_count: 251, green: 29391, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668139, ppg_count: 250, green: 29372, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668116, ppg_count: 249, green: 29355, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668012, ppg_count: 248, green: 29340, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668009, ppg_count: 247, green: 29313, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:08 PPG packet (1 samples): {timestamp_ms: 1782207668005, ppg_count: 246, green: 29299, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667901, ppg_count: 245, green: 29270, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667896, ppg_count: 244, green: 29278, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667893, ppg_count: 243, green: 29288, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667786, ppg_count: 242, green: 29320, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667782, ppg_count: 241, green: 29333, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667779, ppg_count: 240, green: 29304, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667691, ppg_count: 239, green: 29273, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667691, ppg_count: 238, green: 29226, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667667, ppg_count: 237, green: 29193, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667560, ppg_count: 236, green: 29168, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667557, ppg_count: 235, green: 29144, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667555, ppg_count: 234, green: 29124, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667451, ppg_count: 233, green: 29111, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667447, ppg_count: 232, green: 29099, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667442, ppg_count: 231, green: 29079, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667336, ppg_count: 230, green: 29075, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667332, ppg_count: 229, green: 29083, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667329, ppg_count: 228, green: 29105, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667243, ppg_count: 227, green: 29148, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667242, ppg_count: 226, green: 29160, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667218, ppg_count: 225, green: 29130, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667110, ppg_count: 224, green: 29095, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667106, ppg_count: 223, green: 29052, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:07 PPG packet (1 samples): {timestamp_ms: 1782207667103, ppg_count: 222, green: 29021, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666885, ppg_count: 221, green: 28995, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666882, ppg_count: 220, green: 28969, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666878, ppg_count: 219, green: 28945, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666791, ppg_count: 218, green: 28934, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666791, ppg_count: 217, green: 28912, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666767, ppg_count: 216, green: 28899, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666663, ppg_count: 215, green: 28916, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666659, ppg_count: 214, green: 28944, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666656, ppg_count: 213, green: 28975, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666547, ppg_count: 212, green: 28999, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666544, ppg_count: 211, green: 28987, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666543, ppg_count: 210, green: 28949, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666482, ppg_count: 209, green: 28911, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666436, ppg_count: 208, green: 28885, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666432, ppg_count: 207, green: 28857, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666342, ppg_count: 206, green: 28836, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666342, ppg_count: 205, green: 28815, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666318, ppg_count: 204, green: 28795, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666212, ppg_count: 203, green: 28785, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666210, ppg_count: 202, green: 28768, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666205, ppg_count: 201, green: 28765, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666100, ppg_count: 200, green: 28790, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666100, ppg_count: 199, green: 28809, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666099, ppg_count: 198, green: 28828, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:06 PPG packet (1 samples): {timestamp_ms: 1782207666034, ppg_count: 197, green: 28828, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665986, ppg_count: 196, green: 28790, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665981, ppg_count: 195, green: 28749, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665892, ppg_count: 194, green: 28728, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665870, ppg_count: 193, green: 28695, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665868, ppg_count: 192, green: 28670, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665763, ppg_count: 191, green: 28663, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665759, ppg_count: 190, green: 28647, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665755, ppg_count: 189, green: 28624, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665650, ppg_count: 188, green: 28616, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665645, ppg_count: 187, green: 28619, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665642, ppg_count: 186, green: 28627, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665538, ppg_count: 185, green: 28659, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665536, ppg_count: 184, green: 28671, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665531, ppg_count: 183, green: 28664, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665442, ppg_count: 182, green: 28611, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665421, ppg_count: 181, green: 28572, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665418, ppg_count: 180, green: 28542, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665314, ppg_count: 179, green: 28504, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665309, ppg_count: 178, green: 28487, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665305, ppg_count: 177, green: 28483, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665089, ppg_count: 176, green: 28451, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665084, ppg_count: 175, green: 28435, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665080, ppg_count: 174, green: 28427, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:05 PPG packet (1 samples): {timestamp_ms: 1782207665006, ppg_count: 173, green: 28419, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664972, ppg_count: 172, green: 28447, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664968, ppg_count: 171, green: 28492, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664880, ppg_count: 170, green: 28527, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664880, ppg_count: 169, green: 28522, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664853, ppg_count: 168, green: 28484, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664750, ppg_count: 167, green: 28466, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664746, ppg_count: 166, green: 28434, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664743, ppg_count: 165, green: 28421, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664639, ppg_count: 164, green: 28402, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664634, ppg_count: 163, green: 28401, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664630, ppg_count: 162, green: 28407, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664524, ppg_count: 161, green: 28414, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664520, ppg_count: 160, green: 28412, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664516, ppg_count: 159, green: 28438, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664428, ppg_count: 158, green: 28470, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664428, ppg_count: 157, green: 28522, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664404, ppg_count: 156, green: 28561, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664295, ppg_count: 155, green: 28566, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664293, ppg_count: 154, green: 28550, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664290, ppg_count: 153, green: 28514, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664190, ppg_count: 152, green: 28507, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664186, ppg_count: 151, green: 28495, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664181, ppg_count: 150, green: 28488, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664073, ppg_count: 149, green: 28478, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664070, ppg_count: 148, green: 28483, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:04 PPG packet (1 samples): {timestamp_ms: 1782207664066, ppg_count: 147, green: 28491, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663978, ppg_count: 146, green: 28485, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663957, ppg_count: 145, green: 28516, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663954, ppg_count: 144, green: 28553, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663846, ppg_count: 143, green: 28600, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663844, ppg_count: 142, green: 28641, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663842, ppg_count: 141, green: 28620, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663741, ppg_count: 140, green: 28597, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663736, ppg_count: 139, green: 28575, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663732, ppg_count: 138, green: 28565, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663624, ppg_count: 137, green: 28545, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663620, ppg_count: 136, green: 28537, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663616, ppg_count: 135, green: 28540, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663529, ppg_count: 134, green: 28538, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663507, ppg_count: 133, green: 28539, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663503, ppg_count: 132, green: 28536, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663287, ppg_count: 131, green: 28569, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663283, ppg_count: 130, green: 28609, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}

17:41:03 PPG packet (1 samples): {timestamp_ms: 1782207663280, ppg_count: 129, green: 28644, red: 0, infrared: 0, heart: 0, rri: 0, hrv: 0, accel_x: -121, accel_y: 40, accel_z: 207}
## The big one: you're deleting beats, and deletion corrupts HRV

This is the most important issue, and it's well-documented. Your current pass drops the offending interval from the series, and the cleaned series feeds RMSSD/SDNN/pNN50 directly. That's "deletion" correction, and the HRV literature is consistent that deletion is the wrong move for time-domain HRV.

Here's the mechanism. Suppose you have beats at intervals `… 800, 810, [1600], 790, 805 …` where the 1600 is a missed beat (two beats merged). If you delete the 1600, the series becomes `… 800, 810, 790, 805 …` — the gap vanishes, but now you've created a false adjacency: the 810 and the 790 were never actually consecutive beats. RMSSD is the root-mean-square of successive differences, so it's hypersensitive to exactly this. You've stitched two non-adjacent beats together and told RMSSD they're neighbors.

The studies are blunt about it:

- The Giles et al. exercise-HRV comparison found deletion "can have a significant effect on HRV parameters" and recommends interpolation methods instead ([University of Derby / Giles 2016](https://repository.derby.ac.uk/download/f4f1cfe5fe5dc1450d38fa0de9b6f2af14d93599bcd262571e7eb85288c92cc8/1008534/Giles_2016_Heart_Rate_Variability_during_Exercise_A_Comparison_of_Artefact_Correction_Methods_accepted_manuscript.pdf)).
- Kubios, the reference HRV toolkit, corrects artifacts by cubic-spline interpolation over the corrected beat, not deletion ([Kubios HRV preprocessing](https://www.kubios.com/blog/preprocessing-of-hrv-data/)).
- A short-term HRV artifact study found threshold-based cubic interpolation outperforms the median filter for HRV-metric accuracy ([Lipponen/Tarvainen-style comparison, PMC7664660](https://pmc.ncbi.nlm.nih.gov/articles/PMC7664660/)).

So ironically: deletion is part of why you saw "RMSSD exceeding SDNN" in the first place. The moving-median correctly identifies the bad beat, but deleting it can inject a fresh successive-difference spike that inflates RMSSD relative to SDNN. The detector is fine; the correction step is the problem.

## The fix (computational, no product change)

Replace, don't delete. When a beat fails the median test, mark it and replace it via interpolation rather than removing it:

- For HRV time-domain metrics: cubic-spline (or even linear, for short gaps) interpolation of the flagged interval from its clean neighbors. This preserves the time axis and the true adjacency of surrounding beats. This is the Kubios-standard approach.
- Critically, track an "interpolated" flag per beat. Any RMSSD/pNN50 successive-difference pair that touches an interpolated beat should be excluded from that specific statistic — you interpolate to keep the timeline intact, but you don't let a synthetic value masquerade as a real successive difference.

This single change is likely to resolve the RMSSD>SDNN artifact more cleanly than the current deletion does.

## Second problem: ±30% fixed tolerance is the wrong shape

A fixed ±30% band around a local median has two failure modes:

1. It's too loose at low HR and too tight at high HR. HRV scales with cycle length. At 50 bpm (1200 ms), ±30% is ±360 ms — that's a huge swing that real ectopy can hide inside. At 100 bpm (600 ms), ±30% is ±180 ms — tight enough to start flagging legitimate RSA swings, especially during the very respiratory modulation you're trying to measure. So the same threshold over- and under-corrects depending on HR.
2. It's symmetric, but the two error types aren't. A missed beat makes an interval ~2× too long (+100%); a false/extra peak makes one ~0.5× too short (−50%); a true PVC is short-then-compensatory-long. A symmetric ±30% doesn't map onto any of these cleanly.

## The fix

Move to the Lipponen–Tarvainen adaptive threshold (this is what Kubios actually uses): the acceptance band is derived from the local distribution of successive differences (a running estimate of the dRR quantile), so it auto-scales with the subject's HR and HRV instead of using a fixed percentage. It also distinguishes ectopic/missed/extra/long-short patterns rather than a single symmetric gate. It's a modest amount of code and it's the field standard. Reference implementation logic is in [Lipponen & Tarvainen 2019 / Kubios](https://pmc.ncbi.nlm.nih.gov/articles/PMC7664660/).

If you want to keep it lightweight short-term, at minimum make the tolerance a function of the local median (scale the allowed deviation with cycle length) rather than a flat 30%.

## Third problem — and your engineer already half-flagged it: gaps are being miscounted as ectopy

His caveat is exactly right and it's important: with 8–12% BLE loss, a missed-beat data gap looks identical to a real long interval, so the moving-median drops it and inflates the ectopic fraction. But there's a downstream consequence he didn't connect: that same inflated ectopic fraction feeds the irregular-heartbeat alert. So BLE packet loss can directly trigger a false "irregular heartbeat" wellness nudge. For a notification that's deliberately worded to avoid diagnosis claims, a transport bug masquerading as arrhythmia is a real credibility risk.

## The fix

Separate "gap" from "ectopic" before the cleaning pass. You already have the BLE counter information to do this:

- If an interval coincides with a known dropped-packet region → label it gap, exclude it from both HRV and the ectopic fraction. It is missing data, not an abnormal beat.
- Only intervals that fail the median test without an underlying packet gap → label ectopic, count toward the fraction.

This makes the ectopic % honest and stops BLE loss from firing the arrhythmia alert. It's the same real-vs-synthetic distinction we built into the respiratory mask — the ectopic fraction should be computed on real beats only.

## On the moving-median vs Malik choice — agree, with a caveat

His reasoning for median-of-9 over the Malik 0.8–1.2× rule is correct: Malik cascades because each beat is compared to its (possibly corrupted) neighbor. Moving-median against a local context window is more robust. Good call. The one caveat: median-of-9 with edge clamping means the first and last ~4 beats are judged against a lopsided window. On a 90 s capture that's a meaningful fraction of the series. Either accept slightly weaker cleaning at the edges (fine) or note that edge beats get a smaller effective window — just don't treat edge corrections with the same confidence as center ones.

## Quality gate — one structural gap remains

The three checks (beat coverage ≥60%, HR cross-check ±30%, ectopic ≤20%) are reasonable, but combined with the above, two things stand out:

1. The ectopic-≤20% gate is being fed an inflated ectopic number on lossy captures. Fix the gap-vs-ectopic separation first, or this gate rejects good captures for having "too much ectopy" that's really just packet loss.
2. Still no interpolation-fraction / real-sample-density check. Same point as before — a capture can pass all three checks while being heavily reconstructed. Once you separate gaps from ectopics, fold the gap fraction into the gate explicitly: reject (for HRV purposes) if real-beat density is too low, independent of how many beats were flagged ectopic.

## Priority order

1. Replace deletion with interpolation + interpolated-beat flagging — fixes the RMSSD>SDNN artifact properly and is the highest-impact, lowest-risk change.
2. Separate gaps from ectopics using BLE counter data — stops false arrhythmia alerts and makes both the ectopic fraction and the quality gate honest.
3. Adaptive (Lipponen–Tarvainen) threshold instead of fixed ±30% — field-standard, removes the HR-dependent over/under-correction.
4. Add real-beat-density to the quality gate — closes the "passes the gate but mostly synthetic" hole.

One note on sequencing for your real-time diagnosis: items 2 and 4 share the same prerequisite as the respiratory work — propagating the BLE real/gap mask to interval level. If you build that mask once, respiratory (Lomb-Scargle), the ectopic fraction, and the quality gate all consume it. That's the single highest-leverage plumbing change across everything we've discussed.

Several important things jump out from the raw stream that change the picture. Let me give you the findings first, then the adaptive-threshold sketch they inform.

## What the raw packet stream reveals

1. The band does NOT send R-R or HRV — every packet has `rri: 0, hrv: 0`. You're deriving R-R yourself from peak-detecting the `green` PPG channel. That's fine, but it means the ectopic cleaner is operating on your own peak-detector's output, so a "false ectopic" can originate in your peak detection, not just the signal. Worth keeping in mind: garbage R-R in → the cleaner can only do so much.
2. You have a usable timestamp per sample (`timestamp_ms`) and a wrapping `ppg_count` (0–255). This is the gold you need. The `ppg_count` lets you detect dropped packets exactly (a jump in the counter = lost samples), and `timestamp_ms` lets you place beats on a true time axis. So the real/gap mask I keep recommending is fully derivable from data you already have — you don't need anything new from the band.
3. The samples arrive in bursts, not uniformly. Inter-sample deltas alternate between ~1–5 ms and ~90–110 ms. That's BLE batching, not a clean 28 Hz stream. This matters: any cleaning or HRV step that assumes uniform sampling is working against the data. Use the timestamps, not the sample index, to compute intervals.
4. This particular capture is motion-free but at elevated HR. Accel is pinned at (−121, 40, 207) for the entire window — essentially static, no motion artifact. Yet `realtime HR: 105 bpm`. So this is a resting-but-elevated or post-exertion capture, not a motion-corrupted one. That's a useful test case: high HR, low motion.
5. Point #4 exposes a real bug in your current `_movingMedian`. At 105 bpm the R-R is ~570 ms. Your ±30% tolerance allows ±171 ms — that's enormous at this HR and will wave through genuine ectopics. Meanwhile the same ±30% at 50 bpm (1200 ms) allows ±360 ms. The fixed percentage is the problem I flagged, and your own capture at 105 bpm is where it's weakest.

## A bug in the current code worth fixing regardless

Your `_movingMedian` builds the comparison window from `rr.sublist(lo, hi)` — which includes the beat being tested. When an ectopic is present, it contaminates its own median. With a window of 9 and one bad beat, it's minor, but the correct form excludes the center sample from its own median (leave-one-out). Small change, removes a self-masking bias where a large ectopic pulls its own median toward itself and escapes the threshold.

Also: both your cleaners return only the kept values with no record of what was dropped or where. That's what forces deletion semantics downstream and breaks the time axis for RMSSD. The new design fixes this by returning labels + a corrected series.

## The adaptive threshold — sketch grounded in your code

This is the Lipponen–Tarvainen approach, the method Kubios uses ([Kubios HRV preprocessing](https://www.kubios.com/blog/preprocessing-of-hrv-data/), [Lipponen & Tarvainen artifact correction](https://pmc.ncbi.nlm.nih.gov/articles/PMC7664660/)). The core idea: instead of a fixed ±30%, derive the acceptance band from the local spread of the R-R series itself, so it auto-scales with HR and the person's own variability.

5:46

One thing that would sharpen the tuning either way: can your engineer export the actual derived R-R array (the ~117-interval series), not the raw PPG packets? The cleaner operates on R-R, so a few real R-R series — ideally this 105 bpm capture plus a clean resting one — let me set `alpha` and `window` against your real data instead of defaults. The raw packets are great for building the gap mask, but the R-R series is what I'd validate the cleaner on.

Shared `ectopic_adaptive.dart` — pure Dart, drops into your existing ectopic-cleaning file, no new device data needed. Here's what it does and how it reproduced on your real 125-beat / 94 bpm capture.

## Two fixes in one file

## 1. `refinePeakTimesSubSample()` — the RMSSD > SDNN fix (the big one)

Your R-R timing is quantized to the ~23 Hz PPG grid (~43.5 ms/sample). At ~636 ms R-R that rounding alternates sign beat-to-beat, which inflates RMSSD (successive differences) while leaving SDNN (overall spread) modest. That is exactly your 30.1 > 19.3.

I proved it's quantization, not ectopy, two ways:

- On a synthetic clean RSA signal: nearest-sample @23 Hz gives RMSSD 32 > SDNN 24 (the bug); parabolic refinement restores RMSSD 17 < SDNN 18 (physiologic).
- On your real capture, on artifact-free stretches only, RMSSD still beats SDNN (30.0 > 19.2 across clean beats) — confirming it's a timing fingerprint, not arrhythmia.

The function does 3-point parabolic interpolation on the band-passed PPG to recover sub-sample peak _times_, called BEFORE you difference peaks into R-R.

## 2. `cleanAdaptive()` — adaptive ectopic cleaner (Lipponen–Tarvainen / Kubios-style)

Replaces the fixed ±30% with `alpha · quartileDeviation(dRR)` over a local 45-beat window (alpha=5.2), so the accept band auto-scales with HR and variability. It **corrects by interpolation, never deletes** (deletion creates false adjacencies that re-inflate RMSSD), **labels every beat** (normal/ectopic/missed/extra/gap), and **separates packet-loss gaps from real ectopy** using your `ppg_count` counter.

## Reproduced on your capture

- Flagged exactly the real artifacts: idx 39–41 ectopic couplet, idx 52 missed beat (~2x), idx 59–61 extra/split — with correct labels.
- With a gap mask on idx 52: ectopic = 5.6%, gap = 0.8% — so BLE loss can no longer trip the irregular-heartbeat alert.
- HRV on clean pairs only: RMSSD 30.3, SDNN 19.2, pNN50 10.6 over 113 pairs (matches your engineer's numbers, confirming the port is faithful before the timing fix is wired in).

Add `adaptive` to your `EctopicCleaningPolicy { none, malik, movingMedian, adaptive }` and route PPG captures to it.

Two things to flag for your on-device test, per the [Kubios preprocessing guidance](https://www.kubios.com/blog/preprocessing-of-hrv-data/) and the [Lipponen–Tarvainen method](https://pmc.ncbi.nlm.nih.gov/articles/PMC7664660/):

- alpha/window are tuned to this 94 bpm capture — re-check on a resting <60 bpm capture; if it over-flags RSA swings, raise alpha toward 6.
- If the zigzag survives `refinePeakTimesSubSample`, the detector is picking inconsistent fiducials beat-to-beat — switch detection to the first-derivative (upslope) max, or cubic-upsample the band to ~250 Hz before detection.

Once you compile and run it on-device, send me the new rr_raw vs rr_cleaned plus RMSSD/SDNN and I'll confirm the timing fix actually flipped RMSSD < SDNN on real data.

6:24

[](https://t90182496433.p.clickup-attachments.com/t90182496433/90a63072-13c4-4f99-a61e-4e747b384e92/ectopic_adaptive.dart)

  

6:24

[](https://t90182496433.p.clickup-attachments.com/t90182496433/b2f292fe-92f0-45c2-897b-dcd21b5fb076/INTEGRATION.md)

  

6:25

Shared [`INTEGRATION.md`](http://integration.md/). It pulls the wire-up out of the code comments into a standalone guide with five sections:

1. **Full pipeline call sequence** — the copy-paste Dart block from `bandPassGreen` through to consuming `hrv`.
2. **One-line order**: `detectPeaks → refinePeakTimesSubSample → rrFromRefinedPeaks → buildGapMaskFromPpgCount → cleanAdaptive → hrvFromCleaned`.
3. **Who reads what** table — the critical "don't cross these wires" rule: alert reads `ectopicFraction` (gap-free), quality gate reads `gapFraction`, HRV from `hrv.*`.
4. **`buildGapMaskFromPpgCount`** — the one helper you still own, with a full reference implementation that handles the 0–255 counter wrap. (If you can't get `ppg_count` at the R-R stage, just omit `validMask:` — it still works, you only lose the gap/ectopy split.)
5. **Routing through your** **`EctopicCleaningPolicy`** **enum** — adds `adaptive` while keeping the others for comparison, and notes why you should return the full `EctopicResult` (so labels reach `hrvFromCleaned`).

The only piece you implement on your side is `buildGapMaskFromPpgCount`, since it depends on how `ppg_count` is aligned to your peak indices — everything else is in `ectopic_adaptive.dart` ready to call.