# Widgetbook v4 Migration Audit

Migration date: 2026-06-09

Principle: migrate by product and design-system value, not historical parity.
Every migrated story must import a real widget from the app/design system and
cover meaningful scenarios. Old v3 playgrounds, hand-built page replicas, and
catalog-only demos are dropped or deferred unless they describe a current,
intentional DS surface.

## Migrated To v4

| Old v3 entry | v4 story | Decision rationale |
|---|---|---|
| `block_production_status_card_use_case.dart` | `block_production_status_card.stories.dart` | Real DS status surface used by node flows; scenarios cover pipeline health. |
| `bottom_nav_use_case.dart` | `bottom_nav.stories.dart` | Shared navigation primitive used by app shell/page demos; keep for viewport and badge states. |
| `burst_pulse_illustration_use_case.dart` | `burst_pulse_illustration.stories.dart` | Real outcome illustration used by wallet/result surfaces; keep animation states explicit. |
| `button_use_case.dart` | `button.stories.dart` | Core action primitive; v4 args/scenarios cover size, variant, icon, and loading states. |
| `dapp_card_use_case.dart` | `dapp_card.stories.dart` | Real dApps list card; keep enabled, disabled, stats, and long-copy states. |
| `dropdown_chain_use_case.dart` | `dropdown_chain.stories.dart` | Shared dropdown entrypoint for chain selection; keep selected/disabled/list states. |
| `dropdown_chip_use_case.dart` | `dropdown_chip.stories.dart` | Shared chip primitive; keep size and variant states. |
| `dropdown_sheet_use_case.dart` | `dropdown_sheet.stories.dart` | Real sheet composition for dropdown selection; keep option and selection states. |
| `empty_state_use_case.dart` | `empty_state.stories.dart` | Core empty-state primitive used by feature screens. |
| `epoch_performance_page_use_case.dart` | `epoch_performance_page.stories.dart` | Presentational DS page; useful for performance review states. |
| `full_page_error_state_use_case.dart` | `full_page_error_state.stories.dart` | Core error state used broadly; keep retry/minimal states. |
| `icon_badge_use_case.dart` | `icon_badge.stories.dart` | Shared M3 slot widget; keep semantic and inset states. |
| `info_row_use_case.dart` | `info_row.stories.dart` | Shared data-display row; keep value/copy/action variants. |
| `list_section_header_use_case.dart` | `list_section_header.stories.dart` | Small shared list primitive; keep as a stable composition part. |
| `sheet_layout_use_case.dart` | `sheet_layout.stories.dart` | Shared sheet composition primitive. |
| `shimmer_use_case.dart` | `shimmer_block.stories.dart`, `shimmer_card_skeleton.stories.dart`, `shimmer_list_tile.stories.dart` | Split the old mixed playground into stories for the actual shimmer widgets. |
| `slot_assignments_page_use_case.dart` | `slot_assignments_page.stories.dart` | Presentational DS page for block-production detail review. |
| `stale_registration_screen_use_case.dart` | `stale_registration_screen.stories.dart` | Retained as a named onboarding/error-state demo wrapper, not as a duplicate `FullPageErrorState` component. |
| `status_badge_use_case.dart` | `status_badge.stories.dart` | Shared semantic status primitive; keep success/error/warning/neutral scenarios. |
| `status_text_trailing_use_case.dart` | `status_text_trailing.stories.dart` | Shared trailing slot widget used in list compositions. |
| `tabs_use_case.dart` | `tabs.stories.dart` | Shared navigation/filter primitive; keep selection states. |
| `text_chevron_trailing_use_case.dart` | `text_chevron_trailing.stories.dart` | Shared list trailing slot widget. |
| `text_field_use_case.dart` | `text_field.stories.dart` | Retained because the DS currently exports and tests `DSTextField`; flag for future M3-wrapper review. |
| `top_app_bar_use_case.dart` | `top_app_bar.stories.dart` | Shared navigation surface; keep small/large/sliver setup states. |
| `zk_identity_flow_page_use_case.dart` | `zk_identity_flow_page.stories.dart` | Presentational DS page; keep step/status states. |
| `zk_identity_status_card_use_case.dart` | `zk_identity_status_card.stories.dart` | Real identity status card; keep optional-row states. |
| `zk_identity_step_illustration_use_case.dart` | `zk_identity_step_illustration.stories.dart` | Used by `ZkIdentityFlowPage`; keep as an internal visual component story. |

## Dropped Or Deferred

| Old v3 entry | Decision | Rationale |
|---|---|---|
| `color_catalog.dart` | Deferred | Foundation documentation should return as proper v4 docs/stories after DS source-of-truth cleanup; old markdown extraction was fragile. |
| `unified_theme_catalog.dart` | Deferred | Useful as documentation, but not a component story; rebuild later as a foundation docs surface. |
| `dapp_avatar_use_case.dart` | Deferred | `DappAvatar` has no current production or DS composition usage on `develop`, and `DappCard` does not compose it. |
| `list_tile_use_case.dart` | Dropped | It documented M3 `ListTile` composition, not a real DS widget. Keep this guidance in DS docs/playbooks instead of Widgetbook components. |
| `parallax_surface_layout_use_case.dart` | Deferred | The real widget uses a `Flow`-based parallax layer that currently segfaults Widgetbook v4 beta scenario capture in `flutter test`; keep root widget tests and revisit when v4 stabilizes. |
| `dapps_page_use_case.dart` | Deferred | Hand-built feature-page replica; keep `DappCard`/dropdown stories and revisit when a presentational page shell exists. |
| `settings_page_use_case.dart` | Deferred | Imports feature widgets and platform settings panels; not a presentation-only DS story. |
| `wallet_page_use_case.dart` | Deferred | Imports feature wallet delegates and manually recreates page states; migrate only after a presentational wallet surface exists. |
| `registration_errors_use_case.dart` | Deferred | Mixed form/error playground with hard-coded localization stand-ins; keep only the stale-screen wrapper for now. |
| `full_page_loading_state_use_case.dart` | Deferred | `FullPageLoadingState` is deprecated in the DS in favor of content-first shimmer states; keep the current shimmer stories and revisit only if a spinner page remains an intentional shipping pattern. |
| `widgetbook.dart` | Replaced | v3 manual tree replaced by generated v4 `components.g.dart` in the separate `/widgetbook` workspace. |

## Follow-Ups

- Revisit `DSTextField` against the M3-first rule; if it remains a DS wrapper,
  keep its v4 stories, otherwise remove the wrapper and story together.
- Restore foundation/theme documentation as v4 docs after deciding whether
  `DESIGN.md` or the existing split docs are the source of truth.
- Add page-level stories only for pure presentational screens; avoid feature
  widgets with providers, services, platform work, or FRB transitive imports.
