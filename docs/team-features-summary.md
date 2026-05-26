# Team Features Summary — Stay In Touch

## Joshua Yao

- **People index UI** — full table layout with color-hashed initials avatars, soft pill status badges (Overdue / Due Soon / On Track), sortable columns with Turbo Frame swaps, real-time search with debounce, tag filter chips, and favorites filter.
- **Overdue alerts** — highlighted panel at the top of the People index surfacing contacts past their catch-up deadline with direct "Log Event" links.
- **Person show page** — restructured into a card layout with contact info, streak/days-until-due stats, event history, timezone conversion (contact's local time + preferred hours converted to the user's timezone), and AI reconnect message in one view.
- **Events index UI** — per-medium color badges, medium filter bar, and a full monthly calendar grid view where events are placed on their actual days; hovering any event shows a popover with full title, people, medium, time, and notes snippet.
- **Log Event form UX** — participant search bar, person pre-fill when navigating from a contact, notes character counter, and 12-hour time select dropdowns for preferred hours.
- **Relationship health dashboard** — collapsible summary panel categorizing all contacts into Overdue / Slipping / On Track with stat cards (this month's catch-ups, streak, avg frequency, top contacts); catch-ups-per-month bar chart and by-medium pie chart (Chartkick + Groupdate); upcoming birthdays alert showing contacts with birthdays in the next 30 days; set as the app's default landing page.
- **AI reconnect messages** — integrated OpenRouter (Gemma 4) to generate a personalized reach-out suggestion on the Person show page, with one-click clipboard copy.
- **Contact import** — CSV and vCard (.vcf) upload flow with smart header normalization (Google Contacts and Apple Contacts formats), duplicate detection, and a results summary.
- **Birthday tracking** — birthday field on contacts with inline save on the show page; 🎂 indicator next to names on the People list for anyone with a birthday in the next 30 days; birthday badge on the show page counting down days.
- **Login & signup UI** — redesigned as a split-panel layout with brand panel on the left and form on the right.
- **PWA & mobile** — web manifest, service worker with offline cache, and offline fallback page; app is installable via "Add to Home Screen" on iOS and Android; custom app logo and icon.
- **Tags** — tags management page (rename, delete, person count), inline toggle-tag on People.
- **Pagination & seed data** — Pagy pagination (25/page) on People and Events; large seed dataset (10 users, 550 people, 1650 events) for load testing and demos.
- **Polish & quality** — About + Privacy Policy pages, footer links, server-side field length limits, name/title whitespace normalization, RuboCop CI job, custom 404/500 pages, `rescue_from RecordNotFound`.
- **Frontend modernization** — fixed sidebar nav (desktop) + offcanvas drawer (mobile) replacing top navbar; indigo-tinted page background bridging sidebar to content; dashboard greeting hero; icon-forward stat cards; card-row people table where each row floats as its own surface; frameless pill search bar and filter chips; on-theme pagination.

---

## Rohit Katakam

_(fill in your contributions here)_

---

## Tais Martinez

_(fill in your contributions here)_

---

## Matthew Khoriaty

_(fill in your contributions here)_
