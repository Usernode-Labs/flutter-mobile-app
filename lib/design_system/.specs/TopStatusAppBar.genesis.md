# TopStatusAppBar — Genesis

## Inspiration

- **Source**: Figma and product brief
- **Large Figma URL**: https://www.figma.com/design/Eu4jn5o8finpZ28IAGPyru/Testnet-App?node-id=3964-1802
- **Compact Figma URL**: https://www.figma.com/design/Eu4jn5o8finpZ28IAGPyru/Testnet-App?node-id=3964-1852
- **Node icon URL**: https://www.figma.com/design/Eu4jn5o8finpZ28IAGPyru/Testnet-App?node-id=3964-6154

## Design Decisions

### Native App Bar First

- **What Figma showed**: A large app bar with pill-shaped tonal profile/node actions and a compact centered app bar with tonal icon buttons.
- **What we implemented**: `TopStatusAppBar.large` uses a pinned sliver delegate that mirrors Flutter Material 3 large app-bar geometry; `TopStatusAppBar.compact` delegates to `SliverAppBar`.
- **Why**: The app needs native M3 safe-area, title, pinning, and scroll rhythm, but Flutter's `SliverAppBar.large` action slots do not expose a collapse fraction for morphing product-specific pill actions into icon buttons.

### Specialized Component, Not Generic TopAppBar Replacement

- **What Figma showed**: Chrome with explicit profile and node-status semantics.
- **What we implemented**: A separate `TopStatusAppBar` instead of changing generic `TopAppBar`.
- **Why**: `TopAppBar` remains generic navigation chrome. Profile and node status are Usernode product semantics and deserve a named component.

### Large Uses Pill Buttons, Compact Uses Icon Buttons

- **What Figma showed**: Large variant uses tonal buttons with labels; compact variant uses tonal icon buttons.
- **What we implemented**: Large uses 40dp tonal pill visuals with 20dp icons and labels, then continuously collapses to 40dp icon-button visuals with 24dp icons. Compact uses the collapsed icon-button treatment.
- **Why**: This maps to M3's 40dp button/icon-button visual rhythm while preserving the repo's 48dp minimum interactive target.

### Side Gutters

- **What Figma showed**: Actions breathe away from the app-bar edges.
- **What we implemented**: Profile and node visual containers sit 16dp from the side edges in expanded and collapsed states.
- **Why**: The previous 4dp edge padding made the chrome feel dense and detached from the mobile screen keyline.

### Collapsed Surface

- **What Figma showed**: The compact app bar reads as top chrome on a clean surface.
- **What we implemented**: The large app bar starts transparent over the page and fades in `ColorScheme.surfaceContainerLowest` as it collapses.
- **Why**: Expanded status affordances should feel integrated with the page, while the scrolled compact bar should regain native M3 app-bar surface separation and match the bottom navigation bar's white chrome surface.

### Bottom Divider

- **What Figma showed**: The compact app bar sits over scroll content and benefits from a clear edge.
- **What we implemented**: The collapsed/compact app bar paints an `AppBorders` bottom border over `ColorScheme.onSurface`; the large variant fades that border in with scroll progress.
- **Why**: The DS uses borders instead of elevation for separation, and the divider distinguishes white app-bar chrome from white cards below without adding shadow.

### Node Icons

- **What Figma showed**: `check_circle` for synced. The provided node-state frame (`3964:6154`) is empty in the Figma API.
- **What we implemented**: Node Status page parity: `check` for synced, `hourglass_empty` for connecting/syncing, and `close` for offline.
- **Why**: The app bar, root status pills, compact node icon, and Node Status hero should use one shared visual language so status can be scanned without translating between surfaces.

### Semantic State Surfaces

- **What Figma showed**: State icons should read as a compact status affordance, not just standalone colored glyphs.
- **What we implemented**: Synced uses `AppSemanticColors.success.colorContainer` / `onColorContainer`; connecting and syncing use `AppSemanticColors.warning.colorContainer` / `onColorContainer`; offline uses `ColorScheme.errorContainer` / `onErrorContainer`.
- **Why**: These semantic surfaces match the Node Status hero and the compact live `NodeStatusIcon`, including the normal synced state's green success surface.

## Token Mapping

| Figma Value | Design System / M3 Mapping | Notes |
|-------------|----------------------------|-------|
| 64px collapsed toolbar | Flutter M3 large app-bar default | Native large-bar collapse geometry |
| 152px expanded app bar | Flutter M3 large app-bar default | Native large-bar expanded geometry |
| 40px action visual | `AppSizing.iconContainerSmall` / `buttonHeightSmall` | M3 button/icon-button visual rhythm |
| 48px action tap target | `AppSizing.iconContainerRegular` | Preserves accessibility |
| 16px action side gutter | `AppSpacing.space16` | Aligns with mobile screen keyline |
| 24px compact/collapsed icon | `AppSizing.iconRegular` | Exact DS token |
| 20px expanded button icon | `AppSizing.iconSmall` | Figma large pill icon size |
| 16px horizontal pill padding | `AppSpacing.space16` | Exact DS token |
| 8px icon-label gap | `AppSpacing.space8` | Exact DS token |
| Collapsed top surface | `ColorScheme.surfaceContainerLowest` | Fades in with scroll progress; matches BottomNav |
| Bottom divider | `AppBorders.width` / `AppBorders.opacity` | Fades in with collapsed surface |
| Tonal button fill | M3 `FilledButton.tonal` / `IconButton.filledTonal` | Uses theme defaults |
| Synced node surface | `AppSemanticColors.success.colorContainer` / `onColorContainer` | Matches Node Status hero |
| Connecting/syncing node surface | `AppSemanticColors.warning.colorContainer` / `onColorContainer` | Matches Node Status hero |
| Offline node surface | `ColorScheme.errorContainer` / `onErrorContainer` | Matches Node Status hero |
| Synced icon | `Symbols.check_sharp` | Node Status hero parity |
| Connecting/syncing icon | `Symbols.hourglass_empty_sharp` | Node Status hero parity |
| Offline icon | `Symbols.close_sharp` | Node Status hero parity |

## Quality Notes

- Presentation-only: all state is passed through constructor parameters.
- No providers, services, FRB types, or async logic.
- Feature screens own navigation and pass callbacks.
