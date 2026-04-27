# Database Schema

Authoritative source: [`db/schema.rb`](../db/schema.rb). This document is a
human-readable mirror — regenerate by re-running the analysis if you alter
migrations.

## Tables & Attributes

### `users`
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `email` | string | not null, unique | |
| `password_digest` | string | not null | |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

### `sessions`
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `user_id` | integer | not null | **FK → users.id** |
| `ip_address` | string | nullable | |
| `user_agent` | string | nullable | |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

### `people`
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `user_id` | integer | not null | **FK → users.id** |
| `name` | string | not null | |
| `email` | string | not null, unique per `user_id` | |
| `timezone` | string | not null, default `"America/Chicago"` | |
| `preferred_start_hour` | integer | not null, default 9 | |
| `preferred_end_hour` | integer | not null, default 21 | |
| `frequency_weeks` | decimal(5,2) | not null, default 4.0 | |
| `notes` | text | nullable | |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

### `events`
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `user_id` | integer | not null | **FK → users.id** |
| `occurred_at` | datetime | not null, indexed | |
| `medium` | string | not null (`call`/`coffee`/`text`/`video`/`in_person`/`other`) | |
| `title` | string | nullable | |
| `notes` | text | nullable | |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

### `event_participants`  *(join table)*
| Column | Type | Constraints | Key |
|---|---|---|---|
| `id` | integer | not null, auto | **PK** |
| `person_id` | integer | not null | **FK → people.id** |
| `event_id` | integer | not null | **FK → events.id** |
| `created_at` | datetime | not null | |
| `updated_at` | datetime | not null | |

Composite unique index on `(person_id, event_id)`.

---

## ER Diagram (cardinality)

```
                       ┌─────────────────────┐
                       │       users         │
                       │─────────────────────│
                       │ PK  id              │
                       │     email (unique)  │
                       │     password_digest │
                       └─────────┬───────────┘
                                 │ 1
                ┌────────────────┼────────────────┐
                │ M              │ M              │ M
                ▼                ▼                ▼
      ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
      │   sessions   │   │    people    │   │    events    │
      │──────────────│   │──────────────│   │──────────────│
      │ PK  id       │   │ PK  id       │   │ PK  id       │
      │ FK  user_id  │   │ FK  user_id  │   │ FK  user_id  │
      │     ip_addr. │   │     name     │   │     occurred │
      │     ua       │   │     email    │   │     medium   │
      └──────────────┘   │     tz       │   │     title    │
                         │     pref_hrs │   │     notes    │
                         │     freq_wks │   └──────┬───────┘
                         │     notes    │          │
                         └──────┬───────┘          │
                                │ 1                │ 1
                                │ M                │ M
                                ▼                  ▼
                         ┌─────────────────────────────┐
                         │     event_participants      │
                         │  (join table, many-to-many) │
                         │─────────────────────────────│
                         │ PK  id                      │
                         │ FK  person_id               │
                         │ FK  event_id                │
                         │  unique(person_id,event_id) │
                         └─────────────────────────────┘
```

## Relationships (cardinality summary)

| Parent | Child | Cardinality | Notes |
|---|---|---|---|
| `users` | `sessions` | **one-to-many** | `dependent: :destroy` |
| `users` | `people` | **one-to-many** | `dependent: :destroy` |
| `users` | `events` | **one-to-many** | `dependent: :destroy` |
| `people` | `event_participants` | **one-to-many** | `dependent: :destroy` |
| `events` | `event_participants` | **one-to-many** | `dependent: :destroy` |
| `people` ↔ `events` | (via `event_participants`) | **many-to-many** | enforced unique on the pair |

Notable rules:

- Each user's `people.email` is unique within their own scope (not globally).
- Every `event` must have ≥1 participant (model-level validation).
- `preferred_start_hour ≤ preferred_end_hour` (model-level validation).
