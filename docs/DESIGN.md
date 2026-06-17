---
name: Donatex
description: Self-hosted livestream donation app for a single streamer
colors:
  primary: "oklch(75% 0.14 165)" # Neon green/teal accent
  accent-orange: "oklch(75% 0.14 65)" # Neon orange/amber secondary accent
  neutral-bg: "oklch(13% 0.02 255)" # Deep slate background
  surface: "oklch(17% 0.025 255)" # Dark surface card
  surface-2: "oklch(20% 0.03 255)" # Medium dark surface container
  surface-3: "oklch(24% 0.035 255)" # Light dark surface container
  stroke: "oklch(32% 0.03 255)" # Medium border/stroke
  text: "oklch(96% 0.02 90)" # Bright cream text
  text-muted: "oklch(78% 0.02 90)" # Dimmed text
  success: "oklch(74% 0.14 160)" # Success green
  danger: "oklch(68% 0.2 25)" # Danger/error red
typography:
  display:
    fontFamily: "Donatex Display, system-ui, sans-serif"
    fontWeight: 600
    lineHeight: "100px"
  body:
    fontFamily: "ui-sans-serif, system-ui, -apple-system, sans-serif"
    fontSize: "14px"
    lineHeight: "1.5"
rounded:
  sm: "12px" # For sub-containers and inner blocks (rounded-2xl)
  md: "24px" # For inputs and preset labels (rounded-3xl)
  lg: "40px" # For main cards / sections (rounded-[2.5rem])
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.neutral-bg}"
    rounded: "{rounded.md}"
    padding: "16px 20px"
  button-primary-hover:
    backgroundColor: "oklch(78% 0.14 165)"
  card-donation:
    backgroundColor: "oklch(17% 0.025 255 / 45%)"
    rounded: "{rounded.lg}"
    padding: "24px 32px"
---

# Design System: Donatex

## 1. Overview

**Creative North Star: "The Neon Arcade Console"**

Donatex is styled with a high-energy, gamer-centric visual theme inspired by the retro-futurism of arcade cabinets and dark mode creator consoles. The interface is optimized to feel alive, responsive, and tactile. By combining deep slate backdrops with vibrant neon accents and responsive fluid typography, the design creates a feeling of presence and immediate feedback.

The layout prioritizes visual density and high contrast for stream legibility. Subtle glassmorphism and blurred ambient background circles are used to build depth, making the page feel like a physical, illuminated console.

This design system explicitly rejects flat SaaS-cream aesthetics, generic blue corporate dashboards, and unstyled form defaults.

**Key Characteristics:**
- Dark, high-contrast console theme
- Vivid neon-oklch accents (green/teal and orange/amber)
- Generous, rounded corner styles (40px/24px) for cards and inputs
- Kinetic state transitions (hover, active, loading) that feel instant

## 2. Colors

The color palette is built around deep, cold-tinted neutrals paired with glowing neon accents. All colors are specified in the OKLCH space to ensure consistent lightness, saturation, and vibrancy.

### Primary
- **Arcade Neon Green** (oklch(75% 0.14 165)): Used for primary interactive actions, successful state highlights, and confirmation indicators.

### Secondary
- **Solar Neon Orange** (oklch(75% 0.14 65)): Used for secondary accents, recommendations, and highlighting special options to create a visual hierarchy.

### Neutral
- **Deep Slate Void** (oklch(13% 0.02 255)): The primary background color of the application.
- **Console Surface** (oklch(17% 0.025 255)): Used for cards, containers, and primary content structures.
- **Stroke Border** (oklch(32% 0.03 255)): Used for structural dividers and card borders.
- **Cream Text** (oklch(96% 0.02 90)): Primary text color for high contrast and readability.
- **Muted Dust** (oklch(78% 0.02 90)): Subtitle, hint, and utility label text.

### Named Rules
**The Neon Rarity Rule.** Neon accents are restricted to primary interactive elements and active states. Inactive or passive surfaces must remain dark and neutral to prevent visual clutter and maintain high on-stream readability.
**The Tinted Neutral Rule.** Every neutral shade is tinted toward the blue-grey brand hue (chroma 0.02–0.035). Pure black or pure white are strictly forbidden.

## 3. Typography

The type system pairs a stylized custom display font with system-ui sans-serif fallbacks for optimal readability on mobile screens and stream overlays.

**Display Font:** "Donatex Display" (with sans-serif fallback)
**Body Font:** System-ui stack (ui-sans-serif, system-ui, -apple-system)

**Character:** Bold, modern, and tech-forward. Headers have tight tracking and high-contrast weights, while body prose stays clean and highly readable.

### Hierarchy
- **Display** (600, 64px, 100px): Used for large on-stream overlay texts and major hero headings.
- **Headline** (600, 32px to 40px, 1.2): Used for primary page titles and callouts.
- **Title** (600, 18px to 24px, 1.3): Used for card titles and section legends.
- **Body** (400, 14px to 16px, 1.5): Used for descriptions, messages, and general content. Maximum line length is capped at 65ch for readability.
- **Label** (600, 12px, tracking-[0.24em], uppercase): Used for inputs, categories, and utility annotations.

### Named Rules
**The Title Contrast Rule.** Display and title headings must use a bold weight (600) and negative tracking to contrast sharply with the clean, airy system-ui body copy.

## 4. Elevation

Donatex relies on tonal layering and ambient glow effects rather than physical drop shadows. Depth is created by placing lighter surfaces on top of darker backgrounds, augmented by color-mixed borders.

### Shadow Vocabulary
- **Neon Ambient Glow** (`0 0 40px rgba(0, 0, 0, 0.6)`): Ambient shadow behind container blocks to isolate them from backgrounds.
- **Glassmorphism Backdrop** (`backdrop-filter: blur(12px)`): Used on key floating card panels to maintain text legibility above ambient background glow circles.

### Named Rules
**The Flat Console Rule.** All cards and inputs sit flat on the grid. Depth is defined by stroke contrast and background tint changes, not by physical offset shadows.

## 5. Components

Components are styled to match the arcade console aesthetic, using consistent corner radii and clear interactive states.

### Buttons
- **Shape:** Rounded-3xl (24px)
- **Primary:** Neon Green background (`bg-accent`), deep neutral text (`text-background`), and a matching accent glow ring.
- **Hover / Focus:** Lighter green state (`hover:bg-accent/92`), scaling up to `scale-[1.01]` for instant visual feedback.

### Preset Cards
- **Shape:** Rounded-3xl (24px)
- **Default State:** Border in `border-stroke/60`, background in `bg-background/14`.
- **Selected State:** Border in `border-accent/50`, background in `bg-linear-to-br from-accent/16 to-accent-2/12` with a subtle `scale-[1.02]` pop.

### Inputs / Fields
- **Shape:** Rounded-2xl (12px to 24px)
- **Default:** Background in `bg-surface/60`, border in `border-stroke/70`.
- **Focus:** Border in `focus:border-accent/60` and a neon halo glow in `focus:ring-accent/10`.

### Navigation
- **Default:** Minimalistic navigation headers using uppercase labels with tracking-[0.2em].

## 6. Do's and Don'ts

### Do:
- **Do** use OKLCH colors for all new styling declarations.
- **Do** ensure all form controls have hover, focus-visible, and active state transitions.
- **Do** constrain custom display fonts to headers, labels, and overlays.
- **Do** use the synced canvas confetti burst for all overlay success confirmations.

### Don't:
- **Don't** use standard side-stripe borders (e.g., `border-left-4`) as a colored highlight on alert cards.
- **Don't** use gradient text under any circumstances.
- **Don't** use modals as a first resort; keep checkout and confirmation flows inline.
- **Don't** introduce generic un-tinted neutrals (e.g., `#fafafa` or `#121212`).
- **Don't** use decorative animations that do not correspond to a status transition or user feedback trigger.
