# Accessibility

**Status:** Draft baseline
**Owner:** Web and game-UI maintainers

The browser launcher and game canvas have different accessibility constraints.
Meeting launcher requirements does not make canvas gameplay accessible; record
known gaps and avoid overstating conformance.

## Requirements

### Launcher and browser shell

- All import, server, identity, start, fullscreen, diagnostics, and ROM-change
  actions must be reachable by keyboard in a logical order.
- Use native controls and explicit labels. Give status, validation, connection,
  and import errors programmatic text; do not rely on color or console output.
- Keep a visible focus indicator and move focus intentionally after dialogs or
  fatal errors. Do not trap focus.
- Maintain readable contrast for text, controls, focus, and error states. Color
  must not be the only signal.
- Respect zoom/reflow and text scaling without clipping critical controls.

### Game and canvas

- Document keyboard/gamepad/touch mappings outside the canvas and provide a way
  to discover them without playing.
- Offer pause/mute and avoid unexpected audio. Respect reduced-motion preference
  for shell effects and provide a non-animated alternative for essential game
  information where feasible.
- Touch targets should be at least 44 by 44 CSS pixels with separation and must
  not require precise multi-touch for essential actions.
- Do not intercept browser/system shortcuts unnecessarily. Fullscreen must be
  optional and escapable.
- For status communicated only by pixels, sound, or animation, log the gap and
  propose an equivalent textual/semantic channel before calling the journey
  accessible.

## Verification

For every visible change:

1. Complete the launcher using only Tab, Shift+Tab, Enter, Space, arrow keys as
   applicable, and Escape.
2. Inspect accessible names, roles, states, error associations, focus order, and
   focus visibility with browser accessibility tools.
3. Test at 200% zoom, narrow mobile width, reduced motion, high contrast/forced
   colors where supported, and without audio.
4. Run an automated accessibility scanner on non-canvas UI and resolve critical
   findings. Automated success cannot validate canvas gameplay.
5. Check one current desktop screen reader/browser pair and current iOS Safari
   and Android Chrome touch behavior for milestone evidence.

Record browser/OS/device, assistive technology, date, path tested, results, and
open blockers. The charter's M1 target requires keyboard operation, accessible
control names, visible focus, and no critical automated findings.