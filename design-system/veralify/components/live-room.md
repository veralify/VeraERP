# Live Room

Referenced screens: `LiveDiscoveryView`, `LiveRoomPreJoinView`, `LiveRoomView`, `LiveRoomHostView`, `ConnectView`, `/app/live`.

## Anatomy
- Room card: LIVE badge, host, title, participants, group/goal, start state.
- Prejoin panel: camera preview, mic/camera toggles, join CTA.
- Speaker grid: video/audio tiles, active speaker ring, participant labels.
- Control dock: mute, camera, speaker, participants, chat, leave.
- Moderation sheet: invite speaker, mute participant, remove participant, end room.

## Variants
- `VeraLiveBadge`: pulsing red label using `color.live.live-red`.
- `VeraRoomCard`: discovery/upcoming/recommended sections.
- `VeraSpeakerTile`: camera on/off, speaking, muted, host, requested-to-speak.
- `VeraRequestToSpeakButton`: raised hand affordance with queue state.
- `VeraModerationSheet`: host-only controls.

## States
Default: stable controls and participant count. Hover: web controls reveal labels. Pressed: immediate visual feedback. Disabled: permissions missing, camera unavailable, host-only action unavailable. Loading: Agora join spinner and preview placeholder. Error: token/camera/mic failure with retry. Live: badge uses `elevation.shadow.glow-live`; speaking uses `color.live.speaking-glow` ring.

## Token usage
Use `color.live.live-red`, `color.live.speaking-glow`, `color.danger`, `color.glass`, `color.overlay`, `color.fg`, `color.fg-muted`, `radii.lg/xl/pill`, `spacing.2-6`, `zIndex.overlay/modal`, `motion.duration.fast/base`.

## Accessibility
Controls announce state (`Mic muted`, `Camera on`). Request-to-speak announces queue status. Host moderation actions require confirmation for destructive actions. Captions/chat must remain reachable while controls are visible. Hit targets: 44px/44pt.
