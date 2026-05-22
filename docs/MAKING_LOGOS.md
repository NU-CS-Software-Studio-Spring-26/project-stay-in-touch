# Making new logos

How the Serendipity logo was designed, where the assets live, and how to
regenerate them if you change the artwork.

## Design walkthrough

The current logo (a teacup with a four-leaf clover sprouting from it, over the
"Serendipity" wordmark) was designed with Claude. The full conversation —
including the prompts, iterations, and reasoning behind the shapes and colors —
is here:

- https://claude.ai/share/e5aa7b86-b741-4ccd-8f93-e48691caa2fa

If you want a new logo, start a similar conversation: describe the brand feeling
("warm, serendipitous, a catch-up over coffee"), ask for an inline SVG, and
iterate on it. Keep the result as a hand-editable SVG (paths + a `<text>`
wordmark), not a flattened raster, so it can be re-themed later.

## Where the assets live

| File | What it is | Used by |
|---|---|---|
| `app/assets/images/serendipity-logo.svg` | Full lockup: cup + clover + "Serendipity" wordmark (portrait, `viewBox 0 0 320 380`) | Login / sign-up hero, marketing |
| `app/assets/images/serendipity-mark.svg` | Icon-only mark: cup + clover, **no** wordmark, transparent, tightly cropped square-ish | Navbar brand, small contexts |
| `public/icon.svg` | App icon: the mark centered on a white rounded tile (`viewBox 0 0 512 512`) | Favicon (`rel="icon"`), `apple-touch-icon` |
| `public/icon.png` | 1024×1024 raster of `public/icon.svg` | Favicon PNG fallback, PWA manifest (`app/views/pwa/manifest.json.erb`) |

The favicon / app-icon links are declared in
`app/views/layouts/application.html.erb` (`<head>`), and the navbar reference is
in `app/views/shared/_navbar.html.erb`.

## How the SVG is structured

`serendipity-logo.svg` is plain SVG with three art layers plus a wordmark, so
each piece can be edited independently:

- **Cup** — `translate(160 210)`: two `<path>`s (handle + body) filled cream
  `#fae4bd` with a near-black `#1a1a1a` outline, plus an `<ellipse>` rim.
- **Steam / stem** — `translate(160 146)`: a single brown `#6f4e37` curved stroke.
- **Clover** — `translate(160 146) scale(1 0.8)`: four heart-shaped petals
  (`rotate(45/135/225/315)`) alternating `#3b8e4e` / `#95d26e`, with a small
  brown center dot.
- **Wordmark** — a `<text>` element in the **Fraunces** serif (loaded via a
  Google-Fonts `@import` inside `<defs><style>`).

The icon-only `serendipity-mark.svg` is the same three art layers with the
`<text>` and font `@import` removed and a tight square `viewBox`. `public/icon.svg`
wraps those layers in one `translate … scale … translate` transform to center
them on a 512×512 white rounded tile. Dropping the wordmark for the icon matters:
text is illegible at favicon sizes, and the Google-Fonts `@import` does not load
when the SVG is rasterized.

## Regenerating `public/icon.png`

After editing `public/icon.svg`, regenerate the PNG. On macOS, QuickLook works
with no extra install:

```bash
tmpd=$(mktemp -d)
qlmanage -t -s 1024 -o "$tmpd" public/icon.svg
cp "$tmpd/icon.svg.png" public/icon.png
rm -rf "$tmpd"
```

Alternatives if you have a converter installed:

```bash
# librsvg  (brew install librsvg)
rsvg-convert -w 1024 -h 1024 public/icon.svg -o public/icon.png

# ImageMagick  (brew install imagemagick)
magick -background none -density 300 public/icon.svg -resize 1024x1024 public/icon.png
```

After regenerating, open the PNG to confirm the mark is centered and not clipped.
