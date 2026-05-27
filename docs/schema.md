# Database Schema

Authoritative source: [`db/schema.rb`](../db/schema.rb) (schema version
`2026_05_26_034622`). This document is a human-readable mirror — regenerate it
if you add migrations. Constraints marked *(model)* are enforced in the Active
Record model rather than the database.

## Tables & Attributes

### `users`
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `email` | string | not null, unique (case-insensitive), email format *(model)* | |
| `password_digest` | string | not null (`has_secure_password`) | |
| `reset_token` | string | nullable, indexed | |
| `reset_token_expires_at` | datetime | nullable | |
| `timezone` | string | not null, default `"America/Chicago"`, IANA *(model)* | |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

Passwords must be >10 chars with an upper, lower, digit, and special character *(model)*. On create, a user is seeded the default tags `Work`, `Family`, `Friends`.

### `sessions`
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `user_id` | integer | not null, indexed | **FK → users.id** |
| `expires_at` | datetime | nullable, indexed | |
| `ip_address` | string | nullable | |
| `user_agent` | string | nullable | |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

Session lifetime is 30 days; a session is `expired?` when `expires_at` is nil or in the past.

### `people`
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `user_id` | integer | not null, indexed | **FK → users.id** |
| `name` | string | not null, ≤255 chars *(model)* | |
| `email` | string | not null, unique per `user_id` (case-insensitive), email format *(model)* | |
| `timezone` | string | not null, default `"America/Chicago"`, IANA *(model)* | |
| `preferred_start_hour` | integer | not null, default 9, range 0–23 *(model)* | |
| `preferred_end_hour` | integer | not null, default 21, range 0–23 *(model)* | |
| `frequency_weeks` | decimal(5,2) | not null, default 4.0, in `(0, 520]` *(model)* | |
| `notes` | text | nullable, ≤5000 chars *(model)* | |
| `favorite` | boolean | not null, default false; indexed with `user_id` | |
| `birthday` | date | nullable | |
| `snoozed_until` | date | nullable | |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

Model rule: `preferred_start_hour ≤ preferred_end_hour`. A person is `snoozed?` while `snoozed_until` is today or later.

### `events`
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `user_id` | integer | not null, indexed | **FK → users.id** |
| `occurred_at` | datetime | not null, indexed | |
| `medium` | string | not null, one of `call`/`coffee`/`text`/`video`/`in_person`/`other` *(model)* | |
| `duration_minutes` | integer | not null, default 60 | |
| `title` | string | nullable, ≤255 chars *(model)*; falls back to `medium` for display | |
| `notes` | text | nullable, ≤5000 chars *(model)* | |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

Model rule: every event must have ≥1 participant.

### `event_participants`  *(join: people ↔ events)*
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `person_id` | integer | not null, indexed | **FK → people.id** |
| `event_id` | integer | not null, indexed | **FK → events.id** |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

Composite unique index on `(person_id, event_id)`.

### `google_credentials`
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `user_id` | integer | not null, unique index | **FK → users.id** |
| `access_token` | string | not null | |
| `refresh_token` | string | not null | |
| `expires_at` | datetime | not null | |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

One row per user (`has_one`). Stores Google Calendar OAuth tokens; `expired?` when `expires_at` has passed.

### `tags`
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `user_id` | integer | not null, indexed | **FK → users.id** |
| `name` | string | required, ≤50 chars, unique per `user_id` (case-insensitive) *(model)* | |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

Composite unique index on `(user_id, name)`. New users start with `Work`, `Family`, `Friends`.

### `person_tags`  *(join: people ↔ tags)*
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `person_id` | integer | not null, indexed | **FK → people.id** |
| `tag_id` | integer | not null, indexed | **FK → tags.id** |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

Composite unique index on `(person_id, tag_id)`.

---

## ER Diagram (cardinality)

```
                          ┌──────────────────────────┐
                          │           users          │
                          │──────────────────────────│
                          │ PK  id                    │
                          │     email (unique)        │
                          │     password_digest       │
                          │     reset_token           │
                          │     timezone              │
                          └──┬────┬────┬────┬─────┬───┘
            1                │ 1  │ 1  │ 1  │ 1   │ 1
       ┌─────────────────────┘    │    │    │     └──────────────┐
       │ M                  ┌──────┘    │    └──────┐ M           │ 1
       ▼                    │ M         │ M         ▼             ▼
┌──────────────┐           ▼           ▼      ┌──────────┐ ┌────────────────────┐
│   sessions   │   ┌──────────────┐ ┌────────┐│   tags   │ │ google_credentials │
│──────────────│   │    people    │ │ events ││──────────│ │────────────────────│
│ PK id        │   │──────────────│ │────────││ PK id    │ │ PK id              │
│ FK user_id   │   │ PK id        │ │ PK id  ││ FK user  │ │ FK user_id (unique)│
│    expires_at│   │ FK user_id   │ │ FK user││    name  │ │    access_token    │
│    ip/ua     │   │    name      │ │ occured│└────┬─────┘ │    refresh_token   │
└──────────────┘   │    email     │ │ medium │     │ M     │    expires_at      │
                   │    favorite  │ │ durat. │     │       └────────────────────┘
                   │    birthday  │ │ title  │     │
                   │    snoozed   │ └───┬────┘     │
                   └──┬────────┬──┘     │ M        │
                    M │        │ M      │          │
                      │        ▼        ▼          ▼
                      │   ┌─────────────────┐ ┌──────────────────┐
                      │   │ event_participants│ │   person_tags    │
                      │   │ (M:M people↔events)│ │ (M:M people↔tags)│
                      │   │──────────────────│ │──────────────────│
                      │   │ PK id            │ │ PK id            │
                      └──▶│ FK person_id     │ │ FK person_id ◀───┘
                          │ FK event_id      │ │ FK tag_id        │
                          │ uniq(person,evt) │ │ uniq(person,tag) │
                          └──────────────────┘ └──────────────────┘
```

## Relationships (cardinality summary)

| Parent | Child | Cardinality | Notes |
|---|---|---|---|
| `users` | `sessions` | **one-to-many** | `dependent: :destroy` |
| `users` | `people` | **one-to-many** | `dependent: :destroy` |
| `users` | `events` | **one-to-many** | `dependent: :destroy` |
| `users` | `tags` | **one-to-many** | `dependent: :destroy` |
| `users` | `google_credentials` | **one-to-one** | `has_one`, `dependent: :destroy` |
| `people` | `event_participants` | **one-to-many** | `dependent: :destroy` |
| `events` | `event_participants` | **one-to-many** | `dependent: :destroy` |
| `people` ↔ `events` | (via `event_participants`) | **many-to-many** | unique on the pair |
| `people` | `person_tags` | **one-to-many** | `dependent: :destroy` |
| `tags` | `person_tags` | **one-to-many** | `dependent: :destroy` |
| `people` ↔ `tags` | (via `person_tags`) | **many-to-many** | unique on the pair |

Notable rules:

- Each user's `people.email` and `tags.name` are unique within that user's scope, not globally.
- Every `event` must have ≥1 participant *(model validation)*.
- `preferred_start_hour ≤ preferred_end_hour` *(model validation)*.
- A `person` is matched to a registered `user` by case-insensitive email (no FK) to check calendar availability and tailor invites.
