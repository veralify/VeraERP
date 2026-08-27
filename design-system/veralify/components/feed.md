# Feed

Referenced screens: `ConnectView`, `GroupDiscoveryView`, `GroupDetailView`, `PostComposerView`, `PostDetailView`, `MessagesView`, `/app/groups`, `/app/groups/[slug]`, `/coach/groups`, `/admin/reports`.

## Anatomy
- Post card: author, group context, media/progress/food attachment, body, actions, moderation affordance.
- Comment thread: nested comments, reply composer, loading more.
- Group card: goal, members, activity, live now, description.

## Variants
- `VeraPostCard`: standard community post.
- `VeraProgressPostCard`: transformation/progress photo with privacy badge.
- `VeraFoodPostCard`: meal card attachment with calories/macros.
- `VeraCommentThread`: post detail comments with report action.
- `VeraGroupCard`: discovery and my groups.

## States
Default: surfaces use `color.surface`. Hover: actionable affordances reveal without layout shift. Pressed: action row feedback. Disabled: posting blocked or permission removed with explanation. Loading: feed skeleton with avatar/media blocks. Error: retry post/comment load. Empty: `Join a group to see community activity` CTA. Moderation: reported/removed cards use `color.warning` or `color.danger` status copy.

## Token usage
Use `color.surface`, `color.elevated`, `color.border`, `color.fg`, `color.fg-muted`, `color.live.live-red` for live badges, `color.nutrition.*` for food attachments, `spacing.3-6`, `radii.lg/xl`, `elevation.shadow.sm`.

## Accessibility
Actions have labels (`Like post by Maya`, `Report comment`). Media includes alt text or marked decorative. Comment composer supports keyboard submit and escape cancel. Privacy/moderation state is exposed in visible text and accessibility value.
