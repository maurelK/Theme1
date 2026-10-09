# Time Manager Project Guide

## 1. Project Overview

Time Manager is a full-stack time-management application with:

- A Phoenix and Elixir REST API
- A Vue and Vite frontend
- PostgreSQL persistence
- Docker Compose development and production environments
- Travis CI image build and Oracle VM deployment
- GitHub Actions synchronization from the source repository to the deployment mirror

Current development branch:

```text
feature/authentication
```

No secrets should be stored in this document or committed to Git.

## 2. Technology Stack

### Backend

- Elixir 1.18 / OTP 28
- Phoenix 1.8
- Bandit HTTP server
- Ecto and PostgreSQL
- Joken for JWT signing and verification
- PBKDF2 for password hashing
- Swoosh for transactional email (invitations, password reset)
- Oban for background jobs (auto-close of stale clock sessions)

### Frontend

- Vue 3
- Vite
- Vue Router
- Chart.js and Vue Chart.js
- Node 22.18 Alpine in Docker

### Infrastructure

- Docker Compose
- PostgreSQL 16
- Docker Hub images
- Travis CI
- GitHub Actions repository mirroring
- Oracle Cloud VM
- Nginx frontend proxy

## 3. Repository Structure

```text
.
|-- .env.example                 Safe environment-variable template
|-- .gitignore                   Local files and secrets excluded from Git
|-- README.md                    Setup and deployment notes
|-- PROJECT_GUIDE.md             This document
|-- compose.dev.yaml             Local Docker development stack
|-- compose.yaml                 Production Docker deployment stack
|-- caddyfile                    Deployment reverse-proxy configuration
|-- .travis.yml                  Travis image build and Oracle deployment pipeline
|-- .github/
|   `-- workflows/
|       `-- sync_on_theme1.yml   Mirrors source main to deployment repository
|-- theme1/                      Backend (Elixir / Phoenix)
|   |-- mix.exs
|   |-- mix.lock
|   |-- Dockerfile, Dockerfile.dev, entrypoint.sh
|   |-- config/                  config.exs, dev.exs, test.exs, prod.exs, runtime.exs
|   |-- lib/
|   |   |-- theme1.ex
|   |   |-- theme1/
|   |   |   |-- auth.ex                    Authentication and invitation logic
|   |   |   |-- shifts.ex                  Effective shift resolution
|   |   |   |-- time_tracking.ex           Clock-in/out and overtime
|   |   |   |-- scope.ex                   Shared team-scope authorization
|   |   |   |-- user.ex, role.ex, team.ex, team_membership.ex
|   |   |   |-- workingtime.ex, clock.ex
|   |   |   |-- correction_request.ex
|   |   |   |-- invitation_token.ex, password_reset_token.ex
|   |   |   `-- workers/auto_close_clock_sessions.ex
|   |   |-- theme1_web/
|   |   |   |-- router.ex
|   |   |   |-- endpoint.ex
|   |   |   |-- plugs/
|   |   |   `-- controllers/
|   |   |       |-- auth_controller.ex
|   |   |       |-- user_controller.ex
|   |   |       |-- admin_controller.ex
|   |   |       |-- clock_controller.ex
|   |   |       |-- working_time_controller.ex
|   |   |       |-- correction_request_controller.ex
|   |   |       |-- role_controller.ex
|   |   |       `-- team_controller.ex
|   `-- priv/
|       |-- repo/migrations/
|       |-- repo/seeds.exs       Administrator bootstrap
|       `-- static/
|-- theme2/                      Frontend (Vue)
|   |-- package.json, package-lock.json
|   |-- Dockerfile, nginx.conf, vite.config.js
|   |-- src/
|   |   |-- main.js
|   |   |-- App.vue
|   |   |-- router/index.js
|   |   |-- services/auth.js
|   |   |-- styles/global.css
|   |   |-- components/
|   |   |   |-- AppLayout.vue, AppTopbar.vue, AppBottomNav.vue
|   |   |   |-- PasswordField.vue
|   |   |   |-- Clock.vue, ClockManager.vue
|   |   |   |-- WorkingTime.vue, WorkingTimes.vue
|   |   |   |-- ChartManager.vue, WorkingHours{Bar,Line,Pie}Chart.vue
|   |   |   |-- CorrectionRequestModal.vue
|   |   |   |-- ShiftEditorModal.vue, ShiftTargetPicker.vue
|   |   |   `-- User.vue, User.css
|   |   `-- views/
|   |       |-- DashboardView.vue
|   |       |-- LoginView.vue
|   |       |-- AcceptInviteView.vue
|   |       |-- ForgotPasswordView.vue
|   |       |-- ResetPasswordView.vue
|   |       `-- RegisterView.vue (deprecated; route redirects to /login)
|   `-- public/
|-- user.json, update-user.json, workingtime.json   Example payloads
```

Generated directories (`theme1/deps`, `theme1/_build`, frontend `dist`) are local artifacts and not part of the design.

## 4. Backend Domain Model

### Users

- `username`
- unique `email`
- PBKDF2 `password_hash` (nullable until the invitee accepts)
- `role` association
- `timezone_offset_minutes` (fixed UTC offset, e.g. `+120` CEST)
- `shift_start_minutes` / `shift_end_minutes` (minutes from local midnight, e.g. 540 = 09:00)
- team memberships
- clocks, working-time entries

Plaintext passwords are virtual fields only and removed after hashing. Password hashes are never returned by API serializers.

### Roles

Fixed records seeded by migration:

- `employee`
- `manager`
- `hr_payroll`
- `administrator`

There is no public role CRUD. Authenticated users can read the role catalog. Only administrators can promote or demote.

### Teams

Many-to-many via `team_memberships`:

```text
users <-> team_memberships <-> teams
```

A user can belong to multiple teams. Teams can carry `timezone_offset_minutes` and shift minutes used as a fallback for their members.

### Working time

A single row per session:

- `start` (required)
- `end` (nullable — an open clock session has no end yet)
- `user_id`
- `source` = `"clock"` | `"manual"`
- `overtime_minutes` (computed on close or manual save)
- `shift_end_at` (snapshot of the shift end used to compute overtime)
- `auto_closed` (true if closed by the Oban worker)
- `needs_review` (true if auto-closed and awaiting manager review)

### Shifts and overtime

- Shift priority (highest first): **user** → **team** → **global default**
- Global default is `09:00–17:00 UTC`, configurable via `config :theme1, :default_shift`
- When a user is in multiple teams with shifts, the team with the earliest start time wins
- Overtime is the overlap between `[shift_end_at, ∞)` and `[start, end)` — i.e. only actual time worked after shift end counts
- A forgotten clock-out is capped at 12 hours by the auto-close worker, marked `auto_closed = true` and `needs_review = true`

### Correction requests

Attached to a working-time entry:

- `requester_id`
- `working_time_id`
- `reason`
- `status` = `pending` | `approved` | `rejected`
- `reviewer_id`
- `response`
- `proposed_start` / `proposed_end` (what the requester is asking for, optional)

On approval, the proposed times are applied to the working-time record and overtime is recomputed — all inside one Ecto transaction.

## 5. Authentication Flow

### Sign-up policy

There is **no public registration**. New users join through an administrator-issued invitation only:

```text
Admin /directory
    |
    v
POST /api/users  (admin only; role restricted to employee | manager | hr_payroll)
    |
    v
User created without a password + invitation token stored + email sent
    |
    v
Invitee clicks /accept-invite?token=...
    |
    v
POST /api/auth/accept-invitation  (single-use, 24h expiry)
    |
    v
Password set; user can now log in
```

Promotion to `administrator` is a separate, deliberate action via the "Save role" control on the admin dashboard.

### Password rules

Enforced on every path that creates or changes a password (reset, change, accept-invite):

- minimum 10 characters, maximum 72
- at least one lowercase letter
- at least one uppercase letter
- at least one digit
- at least one symbol
- not in a small blocklist of common passwords

The frontend `PasswordField.vue` mirrors these rules with a live checklist and strength meter.

### Login

```text
POST /api/auth/login
    |
    v
Verify email + password
    |
    v
Create random CSRF token
    |
    v
Sign a Joken JWT containing user_id, role, csrf_token, exp (24h)
    |
    v
Set JWT as HttpOnly cookie "theme1_auth"
    |
    v
Return safe user profile + CSRF token
```

The frontend never reads the JWT.

### Protected requests

1. Browser sends the HttpOnly cookie automatically.
2. Frontend sends `X-CSRF-Token`.
3. Phoenix verifies JWT signature and expiration, loads the user and role.
4. Phoenix compares the request CSRF token with the JWT claim.
5. Role and ownership checks are applied.

GET requests also require the CSRF header in this codebase — the frontend always attaches it.

### Logout

`POST /api/auth/logout` — requires cookie + CSRF header, clears the cookie.

### Password change

`POST /api/auth/password` — current password must be valid before a new PBKDF2 hash is stored.

### Password reset (forgot password)

```text
POST /api/auth/password-reset/request
    |
    v
Generic response regardless of whether the account exists
    |
    v
Store SHA-256 digest of a single-use token (1h expiry)
    |
    v
Send link via Swoosh
    |
    v
POST /api/auth/password-reset/confirm
```

### Session bootstrap

`GET /api/auth/csrf` returns:

- `{csrf_token: "<token>"}` when a valid session cookie is present
- `{csrf_token: null}` for anonymous visitors (200, not 401)

This lets the frontend bootstrap without spurious console errors on public pages.

## 6. Authorization Model

### Global permission matrix

| Capability | employee | manager | hr_payroll | administrator |
|---|---|---|---|---|
| View own profile | ✅ | ✅ | ✅ | ✅ |
| View other users | ❌ | team only | ✅ | ✅ |
| Edit own profile | ✅ | ✅ | ✅ | ✅ |
| Clock in / out (self) | ✅ | ✅ | ✅ | ✅ |
| Clock in / out (others) | ❌ | team only | ✅ | ✅ |
| View own working times | ✅ | ✅ | ✅ | ✅ |
| View others' working times | ❌ | team only | ✅ | ✅ |
| Create manual WT | ❌ | team + self | ✅ | ✅ |
| Edit / delete WT | ❌ | team + self | ✅ | ✅ |
| Request correction | own WT | ❌ | ❌ | ❌ |
| Review correction requests | ❌ | team only | ✅ | ✅ |
| Invite new users | ❌ | ❌ | ❌ | ✅ |
| Promote / demote users | ❌ | ❌ | ❌ | ✅ |
| Create teams | ❌ | ❌ | ❌ | ✅ |
| Add / remove team members | ❌ | ❌ | ❌ | ✅ |
| Configure user shift | ❌ | ❌ | ❌ | ✅ |
| Configure team shift | ❌ | ❌ | ❌ | ✅ |

### Employee

- Access own profile, clocks, working times
- Clock in / out for themselves
- Submit correction requests on own records
- Change own password
- Cannot enumerate other users
- Cannot create, edit, or delete working-time records directly
- Cannot manage roles, teams, or shifts

### Manager

- Clock in / out for themselves
- Manage working times and clock for team members and themselves
- Review correction requests from their team
- View team snapshots
- **Cannot** manage users, roles, teams, shifts, or review requests outside their team

### HR / Payroll

- Read working times and clock data across the org
- Create and edit working-time records
- Review correction requests
- Oversee payroll categories
- Cannot manage users, roles, teams, or shifts

### Administrator

- Full access: users, roles, teams, shifts
- Invite new users (role restricted to employee / manager / hr_payroll)
- Promote / demote via the "Save role" control
- Configure user and team shifts
- Review all correction requests

## 7. Main API Routes

### Authentication

```text
POST /api/auth/login
POST /api/auth/logout
GET  /api/auth/csrf
GET  /api/auth/session
POST /api/auth/password
POST /api/auth/password-reset/request
POST /api/auth/password-reset/confirm
POST /api/auth/accept-invitation
```

Public registration (`POST /api/auth/register`) has been removed.

### Users

```text
GET    /api/users
POST   /api/users                 (admin only; sends an invitation)
GET    /api/users/:userID
PUT    /api/users/:userID
DELETE /api/users/:userID
```

### Roles and teams

```text
GET    /api/roles
GET    /api/teams
PUT    /api/admin/users/:userID/role
GET    /api/admin/users/:userID/shift
PUT    /api/admin/users/:userID/shift
POST   /api/admin/teams
POST   /api/admin/teams/:teamID/members/:userID
DELETE /api/admin/teams/:teamID/members/:userID
GET    /api/admin/teams/:teamID/shift
PUT    /api/admin/teams/:teamID/shift
```

### Working time and correction review

```text
GET    /api/workingtime/:userID
POST   /api/workingtime/:userID           (manager+, scope-checked)
GET    /api/workingtime/:userID/:id
PUT    /api/workingtime/:id               (manager+, scope-checked)
DELETE /api/workingtime/:id               (manager+, scope-checked)
POST   /api/workingtime/:id/correction-requests
GET    /api/reviews/correction-requests   (scoped by role)
PUT    /api/reviews/correction-requests/:id
```

### Clocks

```text
POST /api/clocks/:userID/in
POST /api/clocks/:userID/out
GET  /api/clocks/:userID/status
```

## 8. Frontend Routes and Views

```text
/                         Role-aware dashboard
/login                    Login form
/accept-invite            Set password after invitation
/forgot-password          Password-reset request
/reset-password           Password-reset confirmation
/directory                Profile (employee) or directory (manager/hr/admin)
/workingTimes/:userID     Working-time history
/workingTime/:userID      Create working-time entry (manager+)
/workingTime/:userID/:id  Edit working-time entry (manager+)
/clock/:userID            Clock manager
/chartManager/:userID     Working-time charts
/register                 Redirects to /login (registration is closed)
```

The router's `beforeEach()`:

- restores the cookie session
- redirects unauthenticated users to `/login`
- prevents authenticated users from returning to guest-only pages
- protects direct/deep links

### Role-aware navigation

- Top bar label for `/`: **Overview** for employee/manager/hr_payroll, **Workspace** for administrator
- Top bar label for `/directory`: **Profile** for employees, **Directory** for others
- Bottom nav (mobile) mirrors the same labels plus **Sign out**

### Employee profile path

Employees hitting `/directory` see their own profile only — no search, no user list, no invite panel, no manual entry, no edit/delete actions.

### Mobile layout

- Bottom tab bar replaces the desktop inline nav below 900px
- Tab strip inside a workspace scrolls horizontally on narrow screens
- Dashboard/Charts tab is hidden below 900px

## 9. Local Development

```powershell
docker compose -f compose.dev.yaml up --build -d
```

Services:

```text
Frontend: http://localhost:5173
Backend:  http://localhost:4001
Database: localhost:5433
Dev mailbox: http://localhost:4001/dev/mailbox
```

Logs:

```powershell
docker compose -f compose.dev.yaml logs -f backend
docker compose -f compose.dev.yaml logs -f frontend
docker compose -f compose.dev.yaml logs -f db
```

After backend changes:

```powershell
docker compose -f compose.dev.yaml exec backend mix compile --warnings-as-errors
```

Config changes require a restart:

```powershell
docker compose -f compose.dev.yaml restart backend
```

After frontend changes: Vite HMR reloads automatically.

Run backend tests:

```powershell
docker compose -f compose.dev.yaml exec -e MIX_ENV=test backend mix test
```

Stop without deleting the database:

```powershell
docker compose -f compose.dev.yaml down
```

Reset the local database intentionally:

```powershell
docker compose -f compose.dev.yaml down -v
docker compose -f compose.dev.yaml up --build -d
```

## 10. Environment Variables

### Local development

Use `.env.example` as the safe template. Never commit `.env`.

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=replace-with-a-strong-local-password
POSTGRES_DB=theme1_dev
SECRET_KEY_BASE=replace-with-a-generated-secret
AUTH_JWT_SECRET=replace-with-a-strong-jwt-secret
PUBLIC_APP_URL=http://localhost:5173
MAILER_FROM=no-reply@timemanager.local
```

`.env` is loaded into the backend container via `env_file` in `compose.dev.yaml`.

### Production Oracle VM

Required values on the VM:

```env
POSTGRES_USER=...
POSTGRES_PASSWORD=...
POSTGRES_DB=...
SECRET_KEY_BASE=...
AUTH_JWT_SECRET=...
PUBLIC_APP_URL=http://145.241.169.233:8080
MAILER_FROM=no-reply@your-public-domain.example
SMTP_RELAY=...
SMTP_PORT=587
SMTP_USERNAME=...
SMTP_PASSWORD=...
SMTP_SSL=true
```

Optionally:

```env
COOKIE_SECURE=true
```

Set `COOKIE_SECURE=true` **only** once HTTPS is live. With plain HTTP, leaving it unset (so cookies are non-secure) is required for login and invite acceptance to work.

### How to create production values

`SECRET_KEY_BASE`:

```bash
cd ~/Theme1
docker compose run --rm backend mix phx.gen.secret
```

`AUTH_JWT_SECRET` (must differ from `SECRET_KEY_BASE`):

```bash
openssl rand -base64 48
```

`POSTGRES_PASSWORD`:

```bash
openssl rand -base64 32
```

`SMTP_PASSWORD` is the provider-generated SMTP credential (for Gmail, a 16-character App Password without spaces).

## 11. Security and CORS

Production: browser → Nginx frontend → `/api` → Phoenix backend, same origin.

Therefore:

- no wildcard CORS policy
- the JWT cookie stays same-origin
- CSRF is enforced with the request header
- security headers are added by Phoenix
- production cookies use `Secure` **only when `COOKIE_SECURE=true`** (see §10)

If the frontend and API are separated later, add an explicit allowlist rather than `*`.

### Known issues to address before public release

- Backend currently published on Oracle at port `4000` — restrict or bind behind the proxy
- Production HTTPS not yet enabled
- JWT revocation / rotation strategy not implemented
- Login rate limiting not implemented
- `mint` dependency has open CVE advisories (transitive; bump when patched)

## 12. Docker Deployment Images

Production images are defined by:

```text
theme1/Dockerfile
theme2/Dockerfile
```

Backend entrypoint runs `mix ecto.migrate` then `mix phx.server`.

Published as:

```text
maurelk/time-manager-backend:latest
maurelk/time-manager-frontend:latest
```

## 13. CI/CD and Oracle Deployment

### Source-to-mirror flow

`.github/workflows/sync_on_theme1.yml` mirrors `main` to:

```text
git@github.com:maurelK/Theme1.git
```

The source repository remains the source of truth.

### Travis flow

`.travis.yml` runs on `main` only.

Stage 1: build and push backend and frontend images to Docker Hub.

Stage 2:

1. Decode `ORACLE_SSH_KEY_B64`.
2. Register the Oracle host key.
3. Copy `compose.yaml` to `~/Theme1/compose.yaml`.
4. SSH to Oracle.
5. `docker compose pull && docker compose up -d`.

Required Travis variables:

```text
DOCKER_USERNAME
DOCKER_PASSWORD
ORACLE_SSH_KEY_B64
ORACLE_HOST
ORACLE_USER
```

### Production frontend access

```text
http://145.241.169.233:8080/login
```

The frontend Nginx container proxies `/api` internally to the backend.

### Bootstrap the first administrator

```bash
ssh ORACLE_USER@ORACLE_HOST
cd ~/Theme1
docker compose exec \
    -e ADMIN_EMAIL=admin@example.com \
    -e ADMIN_PASSWORD='use-a-strong-production-password' \
    backend mix run priv/repo/seeds.exs
```

The seed is idempotent.

### Grant elevated roles

1. Sign in as the bootstrapped administrator.
2. Open the administrator dashboard.
3. Under "Administrator controls", select a user and a role.
4. Save — the user signs out and back in to pick up the new role.

There are no per-role sign-in buttons; role is always derived server-side.

## 14. Testing Guide

### 14.1 Prerequisites

- Local stack up: `docker compose -f compose.dev.yaml up -d`
- Backend compiled clean: `docker compose -f compose.dev.yaml exec backend mix compile --warnings-as-errors`
- One admin: seed it if missing
- For scope tests, run the scope seed (see §14.6)

```powershell
docker compose -f compose.dev.yaml run --rm -e ADMIN_EMAIL=admin@example.com -e ADMIN_PASSWORD='ChangeMe-Str0ng!' -e PHX_SERVER=false backend mix run priv/repo/seeds.exs
```

### 14.2 Test roles and accounts

| Role | How to create | Example |
|---|---|---|
| administrator | Seeded | `admin@example.com` / `ChangeMe-Str0ng!` |
| manager | Admin invites from `/directory` | `manager@example.com` |
| hr_payroll | Admin invites | `hr@example.com` |
| employee | Admin invites | `employee@example.com` |

Invited users set their password via the dev mailbox link: **http://localhost:4001/dev/mailbox**.

### 14.3 Authentication tests

| # | Step | Expected |
|---|---|---|
| A1 | Visit `/register` | Redirects to `/login` |
| A2 | `POST /api/auth/register` with any body | `404` |
| A3 | Log in with wrong password | `401`, "Invalid email or password" |
| A4 | Log in with correct credentials | Redirects to role-appropriate dashboard |
| A5 | Refresh the page | Session restored, still on the same page |
| A6 | Attempt a protected API without CSRF header | `401` |
| A7 | Sign out | Cookie cleared, redirected to `/login` |
| A8 | Change password → log out → log back in with new password | Works |

### 14.4 Invitation flow tests

| # | Step | Expected |
|---|---|---|
| B1 | As admin, open `/directory` → "Invite someone" | Form with name, email, role (employee/manager/hr_payroll only) |
| B2 | Submit invite with role `administrator` via curl | `403` "This role cannot be assigned at invite time" |
| B3 | Submit a valid invite | Green "Invite sent to…" message |
| B4 | Open http://localhost:4001/dev/mailbox | Email from `no-reply@timemanager.local`, subject "You're invited to Time Manager" |
| B5 | Open the invite link | `/accept-invite` with prefilled token and password field showing the rule checklist |
| B6 | Try a weak password | Checklist shows unmet rules |
| B7 | Submit a strong password | Redirected to `/login` |
| B8 | Log in as the invited user | Dashboard matches the role they were invited with |
| B9 | Reuse the same invite link | `422` "Invalid or expired invitation token" |
| B10 | Check `invitation_tokens` table | `used_at` is set |

### 14.5 Password rules tests

| # | Step | Expected |
|---|---|---|
| C1 | Register a user with password `short` | `422` with all unmet rules |
| C2 | Password `MySecret!234` | Accepted |
| C3 | Password `password` | Rejected by blocklist |
| C4 | Password exactly 72 chars | Accepted |
| C5 | Password 73+ chars | Rejected |

### 14.6 Clock and overtime tests

Prepare test data:

1. As admin, invite a manager (`manager1@example.com`), an employee (`emp1@example.com`), and another employee (`emp2@example.com`).
2. Create a team "Team A".
3. Add the manager and `emp1` to Team A. Leave `emp2` out.
4. Optionally set a team shift on Team A via the dashboard: 08:00–16:00 UTC.
5. Optionally set a personal shift on `emp1` via the dashboard: 09:00–17:00 UTC+01:00.

| # | Actor | Action | Expected |
|---|---|---|---|
| D1 | emp1 | Open `/directory` → Clock Manager tab | Shows "Not clocked in" and the effective shift line |
| D2 | emp1 | Click Clock In | Status flips to "Clocked in since HH:MM", button becomes Clock Out |
| D3 | emp1 | Click Clock Out | Status flips back; a working-time record is created with `source: "clock"` |
| D4 | emp1 | Open Working Times | The new record appears with its duration and any overtime |
| D5 | manager1 | Open Team A → select emp1 → Clock Manager | Can clock emp1 in/out |
| D6 | manager1 | Select emp2 → Clock Manager | emp2 is not in Team A, so scope applies: the manager gets `403` on clock actions |
| D7 | administrator | Select any user → Clock Manager | Works |
| D8 | emp1 | POST /api/workingtime/... (create) via curl | `403` "Employees cannot modify working times directly" |

Overtime verification: create a WT record for `emp1` with `start` before shift end and `end` after shift end (using the DB seed script pattern) and confirm `overtime_minutes` on the resulting record equals the difference.

Auto-close: insert a WT with `start = now - 13h` and `end = nil`, then run the worker manually:

```powershell
docker compose -f compose.dev.yaml exec backend mix run -e "Theme1.Workers.AutoCloseClockSessions.perform(%Oban.Job{})"
```

Expect the record to have `auto_closed: true`, `needs_review: true`, and a capped 12h duration.

### 14.7 Shift configuration tests

| # | Actor | Action | Expected |
|---|---|---|---|
| E1 | admin | Dashboard → "Configure a user's shift" | Opens the target picker |
| E2 | admin | Search "emp1", select | Opens the shift editor |
| E3 | admin | Set 09:00–17:00, UTC+01:00, Save | Green "Shift saved." |
| E4 | any | As emp1, open Clock Manager | Shift line shows `09:00–17:00 (UTC+01:00) · user` |
| E5 | admin | Clear emp1's shift | Shift line shows the team shift or `default` |
| E6 | admin | Set team shift 08:00–16:00 UTC | Any member without a personal shift shows `08:00–16:00 (UTC) · team` |
| E7 | manager/hr | Attempt to open shift editor via direct API `PUT /api/admin/users/:id/shift` | `403` |

### 14.8 Correction request tests

| # | Actor | Action | Expected |
|---|---|---|---|
| F1 | emp1 | Working Times tab → "Request correction" on own record | Modal opens with current start/end, reason textarea, optional proposed start/end |
| F2 | emp1 | Submit with reason only | `201`, green "Correction request submitted." |
| F3 | emp1 | Submit with reason + proposed times | `201` |
| F4 | manager1 | Dashboard → correction list | Request from emp1 visible (team scope) |
| F5 | manager1 | Approve | The underlying working-time record's start/end update to the proposed values; overtime recomputed; request marked approved |
| F6 | manager1 | Reject another request | Status becomes `rejected`, working-time unchanged |
| F7 | manager1 | Submit a correction request | "Request correction" button is not shown to managers |
| F8 | manager1 | Try to review a request from a non-team user via direct API | `404` (leak prevention) |
| F9 | admin | Review | Works on all requests |

### 14.9 Scope enforcement tests

| # | Actor | Action | Expected |
|---|---|---|---|
| G1 | manager (Team A) | Create WT for team member | `201` |
| G2 | manager (Team A) | Create WT for a non-member | `403` "You cannot create records for this user" |
| G3 | manager (Team A) | Create WT for themselves | `201` |
| G4 | manager (Team A) | Update a non-member's WT (valid id) | `404` |
| G5 | manager (Team A) | Delete a non-member's WT | `404` |
| G6 | manager (Team A) | Update own WT | `200` |
| G7 | hr_payroll | Create WT for anyone | `201` |
| G8 | administrator | Create WT for anyone | `201` |
| G9 | employee | Create, update, delete via direct API | `403` |

### 14.10 Role-aware UI tests

| # | Actor | Observe | Expected |
|---|---|---|---|
| H1 | employee | Top nav | Overview + Profile only |
| H2 | employee | Directory page | Own profile only; no search; no invite panel; no Create entry; no Edit/Delete |
| H3 | employee | Working Times | Can request corrections; no create/edit/delete actions |
| H4 | manager | Top nav | Overview + Directory |
| H5 | manager | Directory page | Search, recent accounts, working time controls, no invite panel |
| H6 | hr_payroll | Top nav | Overview + Directory |
| H7 | administrator | Top nav | Workspace + Directory; invite panel visible |
| H8 | any | Resize to mobile (< 900px) | Bottom tab bar appears; Dashboard tab hidden inside the workspace |
| H9 | any | Tab strip at mobile width | Single horizontal-scrolling row |

### 14.11 Backend test suite

```powershell
docker compose -f compose.dev.yaml exec -e MIX_ENV=test backend mix test
```

Expected: all tests pass. Currently covers auth (password rules, reset tokens single-use) and integration smoke tests.

### 14.12 Strict compilation and frontend build

```powershell
docker compose -f compose.dev.yaml exec backend mix compile --warnings-as-errors
docker compose -f compose.dev.yaml exec backend mix format --check-formatted
Set-Location theme2
npm run build
Set-Location ..
```

All three must succeed with no warnings.

## 15. Release Preparation Checklist

- [ ] Remove local test users, teams, correction records, and stale clock sessions.
- [ ] Confirm `.env` is ignored and no secrets are staged.
- [ ] Confirm Oracle has `AUTH_JWT_SECRET` set to a value different from `SECRET_KEY_BASE`.
- [ ] Confirm Oracle has full SMTP configuration (`SMTP_RELAY`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_SSL`, `MAILER_FROM`).
- [ ] Confirm `SMTP_PASSWORD` has no whitespace (App Passwords are 16 chars without spaces).
- [ ] Confirm `PUBLIC_APP_URL` points to the public frontend (`http://145.241.169.233:8080`).
- [ ] Confirm `COOKIE_SECURE` is unset while on HTTP, or `true` once HTTPS is live.
- [ ] Confirm database backups exist.
- [ ] Confirm rollback image/version procedure.
- [ ] Restrict or proxy the exposed backend port (currently `4000` on the VM).
- [ ] Run backend tests, strict compile, and frontend build.

Commands:

```powershell
docker compose -f compose.dev.yaml exec -e MIX_ENV=test backend mix test
docker compose -f compose.dev.yaml exec backend mix compile --warnings-as-errors
Set-Location theme2
npm run build
Set-Location ..
docker compose -f compose.dev.yaml config -q
docker compose config -q
git diff --check
```

## 16. Remaining Work

- Persistent audit log for every role / team / shift / review action
- Login rate limiting and account abuse protection
- JWT revocation / rotation strategy
- HTTPS on Oracle with `COOKIE_SECURE=true` and HSTS
- Restrict or hide the exposed backend port behind the reverse proxy
- Payroll report generation and export
- Bump `mint` to a patched version (transitive dep with open CVE advisories)
- Broader browser / E2E coverage (Playwright or similar)
- Visual polish against Figma frames
- Richer admin UI: replace the interim target pickers with a unified admin console

## 17. Current Validation Status

Validated locally:

- Login and session bootstrap (including `/api/auth/csrf` returning `null` for anonymous visitors)
- Invitation flow end-to-end (invite → mailbox → accept → login)
- Password rules enforced on register / reset / change / accept-invite
- Clock in / clock out with shift-aware overtime
- Auto-close worker (Oban cron, 15-min interval)
- Correction requests with proposed times, applied on approval in one transaction
- Shift configuration for users and teams via admin dashboard
- Manager team-scope enforcement on create, update, delete, and review
- Employee lockout from manual create/update/delete
- Role-aware UI (labels, tabs, buttons) for all four roles
- Mobile layout: bottom tab bar, horizontal-scrolling tab strip, hidden Dashboard tab below 900px
- Backend tests passing, strict compile clean, frontend build clean

Current branch:

```text
feature/authentication
```
