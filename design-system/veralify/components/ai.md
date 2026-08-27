# AI

Referenced screens: `AIInsightCard`, `TargetSetupScreen`, `FoodAnalysisView`, `AISettingsView`, `/app/ai`, `/admin/ai`, spec §62 food confidence display.

## Anatomy
- Chat bubble: role, content, optional sources/actions.
- Streaming indicator: animated dots or shimmer.
- Confidence badge: percentage/range plus provenance label.
- Food-scan overlay: detected food bounding region, portion, calories/macros, confirm/edit/retake actions.

## Variants
- `VeraAIBubbleUser`: user prompts, right aligned.
- `VeraAIBubbleAssistant`: assistant responses, left aligned, `color.accent` edge.
- `VeraStreamingIndicator`: live generation state.
- `VeraConfidenceBadge`: high/medium/low confidence display; low requires review prompt.
- `VeraFoodScanOverlay`: camera/image analysis annotation.
- `VeraCoachInsightBadge`: coach-facing AI summary marker.

## States
Default: assistant surfaces use `color.surface` with accent rail. Hover: copy/source controls visible on web. Pressed: copy/share feedback. Disabled: AI unavailable due to entitlement or privacy setting. Loading/streaming: `color.live.speaking-glow` subtle pulse, respects reduced motion. Error: model/tool failure with retry and no fabricated nutrition values. Low confidence: `color.warning`; unsafe/blocked: `color.danger`.

## Token usage
Use `color.accent`, `color.info`, `color.warning`, `color.danger`, `color.surface`, `color.elevated`, `color.fg`, `color.fg-muted`, `color.nutrition.*`, `typography.body/caption/mono-numeric`, `spacing.3-5`, `radii.lg/xl`, `motion.duration.base/slow`.

## Accessibility
Streaming updates use polite live regions. Confidence is visible text (`Confidence 72%, verify portion`) and not color-only. Food overlay controls remain reachable without relying on image recognition. AI settings explain privacy toggles with labels and hints.
