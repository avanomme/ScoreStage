# Design System

The DesignSystem package provides a cohesive visual language for the premium ScoreStage UI.

## Package: `DesignSystem`

### Color Tokens (`ASColors`)

#### Brand Colors
- `accentFallback`: Deep blue (`#1A73E8`) — primary accent

#### Semantic Text Colors
- `primaryText`, `secondaryText`, `tertiaryText`

#### Surface Colors
- `background`, `surfacePrimary`, `surfaceSecondary`
- Platform-conditional using `#if canImport(UIKit)` / `#if canImport(AppKit)`

#### Paper Themes
| Theme | Color |
|---|---|
| White | Pure white |
| Cream | `#FFF8E7` |
| Warm | `#F5E6D0` |
| Dark | `#1C1C1E` |

#### Annotation Palette
6 colors for markup: red, blue, green, orange, purple, black

### Typography (`ASTypography`)

| Token | Size | Weight |
|---|---|---|
| `display` | 34pt | Bold |
| `heading1` | 28pt | Bold |
| `heading2` | 22pt | Semibold |
| `heading3` | 18pt | Semibold |
| `body` | 16pt | Regular |
| `label` | 14pt | Medium |
| `labelSmall` | 12pt | Medium |
| `caption` | 13pt | Regular |
| `captionSmall` | 11pt | Regular |
| `mono` | 14pt | Monospaced |

### Spacing (`ASSpacing`)

| Token | Value |
|---|---|
| `xxs` | 2pt |
| `xs` | 4pt |
| `sm` | 8pt |
| `md` | 12pt |
| `lg` | 16pt |
| `xl` | 24pt |
| `xxl` | 32pt |
| `xxxl` | 48pt |
| `screenPadding` | 16pt |
| `cardPadding` | 16pt |
| `sectionSpacing` | 24pt |

### Corner Radii (`ASRadius`)

| Token | Value |
|---|---|
| `sm` | 6pt |
| `md` | 10pt |
| `lg` | 14pt |
| `card` | 16pt |
| `xl` | 20pt |

### Components

#### GlassCard
Glass morphism card using `.ultraThinMaterial` background with rounded corners and subtle shadow.

#### PremiumButton
Three styles:
- **Primary**: Filled accent color, full-width
- **Secondary**: Tinted background, compact
- **Ghost**: Transparent, text-only

Includes press animation (scale + opacity feedback).

#### EmptyStateView
Centered layout with:
- Animated SF Symbol icon (pulse effect)
- Title and message text
- Optional action button
- Fade-in entrance animation
