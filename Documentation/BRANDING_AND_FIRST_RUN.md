# Branding and First Run

The installed application display name is `After Effects`. The Xcode target and internal engine module may retain the `Vertex` name where changing it would create unnecessary migration work, but no user-facing surface should present Vertex as the product name after Phase 2.

The application icon and startup logo are generated from the exact image supplied by the repository owner on 2026-08-05. The lossless PNG bytes are stored as base64 text in `App/Resources/AppIconSource.base64`. `Tools/generate_app_assets.sh` decodes that source and creates the required iPhone, iPad, App Store marketing, and launch-logo PNG sizes before XcodeGen runs. Generated PNG files are build products and are not treated as a second editable source.

The SwiftUI startup surface displays the supplied logo, the name `After Effects`, the attribution `Made by Maze`, and a progress indicator while the Phase 2 core catalog is initialized. The minimum visible duration prevents a single-frame flash. This startup surface does not claim that media or editor engines have loaded because those engines do not exist yet.

The Telegram promotion points only to `https://t.me/aemotionios`. The application stores `afterEffects.didPresentTelegramPromotion.v1` in `UserDefaults` through `@AppStorage`. The value is consumed before the sheet is presented, so the promotion does not reappear after dismissal, opening Telegram, backgrounding, or a later launch. Removing the app clears the installation storage and permits the first-run promotion to appear after a reinstall.

The promotion offers two explicit choices: open Telegram or continue without joining. It is dismissible, does not block the application, does not collect analytics, and does not alter editor functionality. `Made by Maze` appears on the startup surface, main milestone screen, and promotion surface.
