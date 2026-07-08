# rw_git branding

The mark is a commit graph read left to right (a main lane, a branch, a merge) whose final leg
breaks upward into a sparkline. The pink node is the insight `rw_git` extracts from history.

## Files

| File | Use |
|---|---|
| `logo.svg` / `logo-dark.svg` | Mark only, light / dark grounds |
| `lockup.svg` / `lockup-dark.svg` | Mark + wordmark, light / dark grounds |
| `logo.png` / `logo-dark.png` | 256×256 PNG fallback (transparent) |
| `lockup.png` / `lockup-dark.png` | 1240×320 PNG fallback (transparent) |

## Using in the GitHub README

GitHub strips inline `<svg>` from markdown. Reference the files as images instead.

Theme-aware (switches with the viewer's GitHub theme):

```html
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="branding/lockup-dark.png">
  <img src="branding/lockup.png" alt="rw_git" width="310">
</picture>
```

Plain markdown (light variant only):

```markdown
![rw_git](branding/lockup.png)
```

The SVG lockups use the viewer's system monospace font for the wordmark; the PNGs are
pre-rendered and identical everywhere, so prefer PNGs where exact reproduction matters
(GitHub README, pub.dev).

## Palette

| Name | Hex | Role |
|---|---|---|
| Graph slate | `#2E3D52` | Mark strokes/nodes on light |
| Graph slate (dark) | `#C3CFDF` | Mark strokes/nodes on dark |
| Signal pink | `#D6408F` | Insight node + underscore, light grounds |
| Signal pink (dark) | `#F272B6` | Insight node + underscore, dark grounds |
| Ink | `#1B2430` / `#E8EDF4` | Wordmark on light / dark |

Rules: the pink appears exactly twice per lockup in the insight node and the underscore.
Wordmark is always lowercase monospace, never letterspaced.
