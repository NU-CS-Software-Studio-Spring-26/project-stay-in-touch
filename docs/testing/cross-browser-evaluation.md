# Cross-Browser & Mobile UI Evaluation

Covers Milestone 4 requirements:

- **#25** — "UI should be evaluated on at least two different browsers (most recent
  version installable on your machine), both on desktop and mobile."
- **#12** — "App runs as a PWA (progressive web app) on a mobile platform."

There are two layers: an **automated** browser test that runs in CI/locally, and a
**manual** evaluation matrix the team fills in by hand (the part the rubric asks
for — a real human checking two browsers on desktop and mobile).

---

## 1. Automated browser coverage

The Cucumber suite (`features/`) is the automated UI layer:

| Layer | Driver | Browser engine | Where it runs |
|-------|--------|----------------|---------------|
| 21 scenarios | `rack_test` | none (Rack) | CI + local |
| 1 scenario tagged `@javascript` | `selenium` | **headless Chrome** | local (needs Chrome) |

The `@javascript` scenario (`features/people.feature` — "Searching then clearing
filters the contact list in place") drives the real Stimulus + Turbo-Frame live
search in a headless Chrome browser. CI runs `cucumber --tags "not @javascript"`
so the pipeline needs no browser binary and stays fast and reliable; run the
browser scenario locally where Chrome is installed.

```bash
bundle exec cucumber --tags "not @javascript"   # 21 scenarios, no browser (matches CI)
bundle exec cucumber --tags "@javascript"        # the headless-Chrome scenario only
bundle exec cucumber                             # everything (22 scenarios; needs Chrome)
```

> Automated headless Chrome is one engine only. It does **not** by itself satisfy
> "two browsers, desktop and mobile" — that is what the manual matrix below is for.

---

## 2. Manual cross-browser + mobile evaluation

### Browsers under test (most recent installable on macOS)

| # | Browser | Platform | How to test mobile |
|---|---------|----------|--------------------|
| 1 | **Google Chrome** (latest) | Desktop + Mobile | DevTools → Device Toolbar (⌘⇧M), or a real Android device |
| 2 | **Safari** (latest) | Desktop + Mobile | iOS Simulator (Xcode → Simulator → Safari), or a real iPhone |

> Pick the two most recent versions you can install. On macOS, Chrome + Safari are
> the natural pair (Chrome = Blink, Safari = WebKit — two genuinely different
> engines). Firefox (Gecko) is a fine third if you want extra coverage.

### How to point a browser at the app

- **Deployed (preferred for the demo):** the Heroku release —
  `https://stay-in-touch-cs396.herokuapp.com` (confirm the current URL in the
  README / Heroku dashboard).
- **Local:** `bin/rails server` → `http://localhost:3000`. For a phone on the same
  Wi-Fi, bind to your LAN IP: `bin/rails server -b 0.0.0.0` then browse to
  `http://<your-mac-ip>:3000` from the phone.

### Results matrix

Fill each cell with ✅ (works), ⚠️ (minor issue — note it), or ❌ (broken — note
it). Record the date and version of each browser at the top.

> Evaluated by: \_\_\_\_\_\_  Date: \_\_\_\_\_\_
> Chrome version: \_\_\_\_\_\_  Safari version: \_\_\_\_\_\_

| Screen / flow | Chrome desktop | Safari desktop | Chrome mobile | Safari iOS |
|---|---|---|---|---|
| Login / signup (split-panel layout) | | | | |
| Dashboard (greeting, stat cards, charts) | | | | |
| People index — table renders, avatars | | | | |
| People index — search, sort, tag/favorite filters | | | | |
| Person show — info card, timezone, AI reconnect | | | | |
| Log Event form — participant search, time selects | | | | |
| Events — month calendar grid + popovers | | | | |
| Sidebar nav (desktop) ↔ offcanvas drawer (mobile) | | | | |
| Flash notifications appear and dismiss | | | | |
| Forms reject bad input with visible errors | | | | |

Things to watch for per browser: layout/overflow differences, sticky sidebar vs.
offcanvas behavior at mobile widths, date/time input rendering (Safari renders
`datetime-local` differently from Chrome), Chartkick charts loading, and tap-target
size on mobile.

---

## 3. PWA-on-mobile verification (#12)

The PWA is configured in `app/views/pwa/manifest.json.erb`
(`display: standalone`, theme `#4F46E5`, 512×512 icon) and
`public/service-worker.js` (network-first fetch with an offline fallback). Verify
it installs and runs as an app:

### Desktop Chrome (quick sanity + audit)
1. Open the app in Chrome → DevTools (⌥⌘I) → **Application** tab.
2. **Manifest** pane: confirm name "Serendipity", the icon, `display: standalone`,
   and theme color load with no errors.
3. **Service Workers** pane: confirm the worker is **registered** and **activated**.
4. **Lighthouse** tab → run the audit with **"Progressive Web App"** checked →
   confirm the installability checks pass.
5. Click the **install icon** in the address bar → "Install Serendipity" → it opens
   in its own standalone window (no browser chrome).

### iPhone — Safari (the graded "runs as a PWA on mobile" check)
1. Open the deployed URL in iOS Safari.
2. Tap **Share** → **Add to Home Screen** → **Add**.
3. Launch it from the Home Screen → it opens **full-screen / standalone** (no
   Safari address bar or tabs) with the app icon and splash.

### Android — Chrome
1. Open the deployed URL in Chrome.
2. Menu (⋮) → **Install app** / **Add to Home Screen** → it installs as an app.

### Offline behavior
1. Install the app (desktop or mobile) and load a few pages so the service worker
   caches them.
2. Turn on Airplane Mode (or DevTools → Network → **Offline**).
3. Relaunch / navigate → cached pages still render; uncached navigations fall back
   to the offline page (`/offline`, served by the service worker).

> Record the device + OS used for the mobile install (e.g. "iPhone 15, iOS 18,
> Safari — installed and launched standalone ✅") so the evaluation is evidenced.
