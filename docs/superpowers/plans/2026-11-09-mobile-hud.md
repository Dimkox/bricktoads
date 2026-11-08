# Compact mobile gameplay HUD

User approved direct implementation; no additional design approval is required. Preserve the desktop HUD and native IAS gameplay controls.

1. Keep mobile personal health/returns and a short objective in edge-anchored44px cards inside the existing CoreUISafeInsets. Reflow to two rows on narrow portrait screens; keep tablets compact.
2. Standard buttons open one nonmodal details panel. Reuse the full original party, exact health/returns/status, objective and boss details; include a44px collapse control and scrolling when space is limited.
3. Reset expansion on run/body/view changes, retain it across ordinary snapshots, and keep movement/Jump/Attack active. All mobile gameplay buttons, including short-window Jump, have targets of at least44px.
4. Compile the changed client and run existing MovementInput contracts. Root verifies actual device-emulator layouts, expansion and gameplay, rebuilds/syncs Studio and records the evidence.

References checked2026-11-09: [Roblox HUD safe areas](https://create.roblox.com/docs/tutorials/use-case-tutorials/ui/create-hud-meters), [Apple handheld game interfaces](https://developer.apple.com/videos/play/meet-with-apple/243/), [Android layout basics, updated2026-10-22](https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-basics). Use consistent edge anchors and readable text instead of shrinking the complete desktop interface.
