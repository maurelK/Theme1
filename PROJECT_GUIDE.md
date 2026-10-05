# Time Manager Project Guide

## 1. Project Overview

Time Manager is a full-stack time-management application with:

- A Phoenix and Elixir REST API
- A Vue and Vite frontend
- PostgreSQL persistence
- Docker Compose development and production environments
- Travis CI image build and Oracle VM deployment
- GitHub Actions synchronization from the source repository to the deployment mirror

The current authentication work is developed on:

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
- Swoosh for password-reset email delivery

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
|-- README.md                    Setup, API, authentication, and deployment notes
|-- PROJECT_GUIDE.md             This project handoff document
|-- compose.dev.yaml             Local Docker development stack
|-- compose.yaml                 Production Docker deployment stack
|-- caddyfile                    Deployment reverse-proxy configuration
|-- .travis.yml                  Travis image build and Oracle deployment pipeline
|-- .github/
|   `-- workflows/
|       `-- sync_on_theme1.yml   Mirrors source main to deployment repository
|-- theme1/
|   |-- mix.exs                  Backend dependencies and Mix aliases
|   |-- mix.lock                 Locked Elixir dependencies
|   |-- Dockerfile               Production backend image
|   |-- Dockerfile.dev           Development backend image
|   |-- entrypoint.sh            Production migration and Phoenix startup
|   |-- config/
|   |   |-- config.exs            Shared configuration
|   |   |-- dev.exs               Development database and environment config
|   |   |-- test.exs              Test database and SQL Sandbox config
|   |   |-- prod.exs               Production compile-time configuration
|   |   `-- runtime.exs            Runtime secrets and production configuration
|   |-- lib/
|   |   |-- theme1.ex             Application context module
|   |   |-- theme1/               Domain schemas and authentication context
|   |   |-- theme1_web.ex          Phoenix web definitions
|   |   |-- theme1_web/
|   |   |   |-- router.ex           Public, authenticated, reviewer, and admin routes
|   |   |   |-- endpoint.ex          Phoenix endpoint and security headers
|   |   |   |-- plugs/               JWT, role, and security-header plugs
|   |   |   |-- controllers/          Auth, role, team, admin, and user controllers
|   |   |   `-- working_time_controller.ex
|   |   `-- theme1_web/
|   |-- priv/
|   |   |-- repo/migrations/        Database schema migrations
|   |   |-- repo/seeds.exs          Runtime-driven administrator bootstrap
|   |   `-- static/                 Phoenix static assets
|   `-- test/                       ExUnit tests
|-- theme2/
|   |-- package.json               Frontend dependencies and scripts
|   |-- package-lock.json          Locked Node dependencies
|   |-- Dockerfile                 Production frontend image
|   |-- nginx.conf                 Production SPA and API reverse proxy
|   |-- vite.config.js              Development API proxy
|   |-- src/
|   |   |-- main.js                Vue application entry point
|   |   |-- App.vue                Router-controlled application shell
|   |   |-- router/index.js         Routes and authentication guard
|   |   |-- services/auth.js         Cookie, CSRF, login, reset, and API helper
|   |   |-- components/              Directory, time, clock, chart, and profile views
|   |   `-- views/                   Login, registration, recovery, and dashboards
|   `-- public/                     Public frontend assets
|-- user.json                      Example API request payload
|-- update-user.json               Example update payload
|-- workingtime.json               Example working-time payload
`-- update-user.json
```

Generated dependency directories such as `theme1/deps`, `theme1/_build`, and frontend build output are local build artifacts and are not part of the application design.

## 4. Backend Domain Model

### Users

Users contain:

- username
- unique email
- PBKDF2 password hash
- role association
- team memberships
- clocks
- working-time entries

Plaintext passwords are virtual fields only and are removed after hashing. Password hashes are never returned by API serializers.

### Roles

Roles are predefined records:

- `employee`
- `manager`
- `hr_payroll`
- `administrator`

There is no public role CRUD. Authenticated users may read the role catalog. Only administrators can promote or demote users.

### Teams

Teams use a many-to-many relationship:

```text
users <-> team_memberships <-> teams
```

A user can belong to multiple teams.

### Working time

Working-time entries contain:

- start datetime
- end datetime
- user ID

### Correction requests

Correction requests are separate records connected to a working-time entry. They contain:

- requester
- working-time entry
- reason
- pending/approved/rejected status
- reviewer
- reviewer response
- timestamps

## 5. Authentication Flow

### Registration

```text
Vue registration form
    |
    v
POST /api/auth/register
    |
    v
Password is PBKDF2-hashed
    |
    v
User receives the employee role
```

Public registration cannot assign privileged roles.

### Login

```text
POST /api/auth/login
    |
    v
Verify email and password
    |
    v
Create random CSRF token
    |
    v
Create signed Joken JWT containing:
- user ID
- role
- CSRF token
- expiration
    |
    v
Set JWT in HttpOnly cookie
    |
    v
Return safe user profile and CSRF token
```

The frontend never reads the JWT. The JWT is stored in the `theme1_auth` HttpOnly cookie.

### Protected requests

For authenticated API calls:

1. Browser sends the HttpOnly cookie automatically.
2. Frontend sends `X-CSRF-Token`.
3. Phoenix verifies the JWT signature and expiration.
4. Phoenix loads the user and role.
5. Phoenix compares the request CSRF token with the JWT CSRF claim.
6. Role and ownership checks are applied.

### Logout

```text
POST /api/auth/logout
```

Logout requires the authenticated cookie and CSRF header, then clears the cookie and frontend session state.

### Password change

```text
POST /api/auth/password
```

The current password must be valid before a new PBKDF2 hash is stored.

### Forgot-password flow

```text
POST /api/auth/password-reset/request
    |
    v
Generic response regardless of account existence
    |
    v
Create hashed, expiring, single-use token
    |
    v
Send reset link through Swoosh SMTP in production
    |
    v
POST /api/auth/password-reset/confirm
```

Reset tokens:

- expire after one hour
- are stored as SHA-256 digests
- are invalidated after first use
- are not exposed in production responses
- may be returned for local development testing only

## 6. Authorization Model

### Employee

- Access own profile
- Access own clocks and working times
- Create correction requests for own records
- Change own password
- Cannot enumerate other users
- Cannot manage roles or teams

### Manager

- Access assigned team information
- Review correction requests
- View team snapshots
- Work with team-scoped records

### HR/Payroll

- Read approved report scopes
- Review time and payroll categories
- Review correction requests

### Administrator

- Access all users
- Promote and demote users
- Create teams
- Add and remove team members
- Manage system-level controls
- Review correction requests

## 7. Main API Routes

### Authentication

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/logout
GET  /api/auth/csrf
GET  /api/auth/session
POST /api/auth/password
POST /api/auth/password-reset/request
POST /api/auth/password-reset/confirm
```

### Users

```text
GET    /api/users
POST   /api/users
GET    /api/users/:userID
PUT    /api/users/:userID
DELETE /api/users/:userID
```

User access is filtered by role and ownership.

### Roles and teams

```text
GET    /api/roles
GET    /api/teams
PUT    /api/admin/users/:userID/role
POST   /api/admin/teams
POST   /api/admin/teams/:teamID/members/:userID
DELETE /api/admin/teams/:teamID/members/:userID
```

### Working time and correction review

```text
GET    /api/workingtime/:userID
POST   /api/workingtime/:userID
GET    /api/workingtime/:userID/:id
PUT    /api/workingtime/:id
DELETE /api/workingtime/:id
POST   /api/workingtime/:id/correction-requests
GET    /api/reviews/correction-requests
PUT    /api/reviews/correction-requests/:id
```

### Clocks

```text
GET  /api/clocks/:userID
POST /api/clocks/:userID
```

## 8. Frontend Routes and Views

```text
/                         Role-aware dashboard
/login                    Login form
/register                 Employee registration form
/forgot-password          Password-reset request form
/reset-password           Password-reset confirmation form
/directory                Existing user/profile directory
/workingTimes/:userID     Working-time history
/workingTime/:userID      Create working-time entry
/workingTime/:userID/:id  Edit working-time entry
/clock/:userID            Clock manager
/chartManager/:userID     Working-time charts
```

The router uses `beforeEach()` to:

- restore the cookie session
- redirect unauthenticated users to login
- prevent authenticated users from returning to guest pages
- protect direct/deep links

### Production sign-in and role selection

There is one shared sign-in page:

```text
https://your-public-domain.example/login
```

Users must not choose a role on the login form. The backend determines the role from the authenticated database record and the frontend displays the matching dashboard:

```text
employee       -> Employee dashboard
manager        -> Manager dashboard
hr_payroll     -> HR/payroll dashboard
administrator  -> Administrator dashboard
```

This prevents a user from claiming a privileged role through client-side input.

## 9. Local Development

From the repository root:

```powershell
docker compose -f compose.dev.yaml up --build -d
```

Services:

```text
Frontend: http://localhost:5173
Backend:  http://localhost:4001
Database: localhost:5433
```

View logs:

```powershell
docker compose -f compose.dev.yaml logs -f backend
docker compose -f compose.dev.yaml logs -f frontend
docker compose -f compose.dev.yaml logs -f db
```

After backend changes:

```powershell
docker compose -f compose.dev.yaml up -d --no-deps --build backend
docker compose -f compose.dev.yaml exec backend mix compile
```

After frontend changes:

```powershell
docker compose -f compose.dev.yaml up -d --no-deps --build frontend
Set-Location theme2
npm run build
Set-Location ..
```

Run backend tests:

```powershell
docker exec -e MIX_ENV=test theme1-dev-backend-1 mix test
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

Important values:

```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=replace-with-a-strong-local-password
POSTGRES_DB=theme1_dev
SECRET_KEY_BASE=replace-with-a-generated-secret
AUTH_JWT_SECRET=replace-with-a-strong-jwt-secret
```

### Production Oracle VM

The production VM must provide:

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

These values must remain on the VM or in the deployment secret store. They must not be committed to Git or baked into Docker images.

### How to create or obtain production values

`SECRET_KEY_BASE` is a Phoenix secret. Generate it from the backend project:

```bash
cd ~/Theme1
docker compose run --rm backend mix phx.gen.secret
```

Use the output as `SECRET_KEY_BASE`.

`AUTH_JWT_SECRET` must be a different long random secret. Generate one with:

```bash
openssl rand -base64 48
```

`POSTGRES_PASSWORD` should also be generated with a password manager or:

```bash
openssl rand -base64 32
```

`POSTGRES_USER` and `POSTGRES_DB` are deployment choices, for example:

```env
POSTGRES_USER=theme1
POSTGRES_DB=theme1_prod
```

`PUBLIC_APP_URL` is the public frontend address used in password-reset links. For the current IP-only deployment:

```env
PUBLIC_APP_URL=http://145.241.169.233:8080
```

If `PUBLIC_APP_URL` is omitted, the backend falls back to `http://PHX_HOST:8080`. The application will start, but explicitly setting the variable is recommended. Change it if the frontend port or public access path changes.

`MAILER_FROM` is a verified sender address supplied by your email provider. It is not generated:

```env
MAILER_FROM=no-reply@your-verified-mail-domain.example
```

`SMTP_RELAY` is the SMTP hostname supplied by the provider, such as `smtp.sendgrid.net` or another provider-specific relay.

`SMTP_PORT` and `SMTP_SSL` normally use:

```env
SMTP_PORT=587
SMTP_SSL=true
```

`SMTP_USERNAME` comes from the provider. Some providers use a literal username such as `apikey`; others use a service account or email address.

`SMTP_PASSWORD` is the provider-generated SMTP credential, API key, or app password. It is not necessarily the normal account password. Create it in the provider dashboard and store it only on the VM or in a secret manager.

Example IP-only production configuration:

```env
POSTGRES_USER=theme1
POSTGRES_PASSWORD=replace-with-generated-db-password
POSTGRES_DB=theme1_prod
SECRET_KEY_BASE=replace-with-mix-phx-gen-secret-output
AUTH_JWT_SECRET=replace-with-separate-random-jwt-secret
PUBLIC_APP_URL=http://145.241.169.233:8080
MAILER_FROM=no-reply@verified-sender.example
SMTP_RELAY=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=provider-smtp-username
SMTP_PASSWORD=provider-generated-smtp-secret
SMTP_SSL=true
```

## 11. Security and CORS

The frontend and API use the same origin in production through Nginx:

```text
Browser -> Nginx frontend -> /api -> Phoenix backend
```

Therefore:

- no wildcard CORS policy is enabled
- the JWT cookie remains same-origin
- CSRF is enforced with the request header
- security headers are added by Phoenix
- production cookies use `Secure`
- production must run behind HTTPS

If the frontend and API are separated onto different origins later, add an explicit allowlist rather than `*` and review cookie `SameSite` behavior.

## 12. Docker Deployment Images

Production images are defined by:

```text
theme1/Dockerfile
theme2/Dockerfile
```

The backend production entrypoint runs:

```bash
mix ecto.migrate
mix phx.server
```

Images are published as:

```text
maurelk/time-manager-backend:latest
maurelk/time-manager-frontend:latest
```

## 13. CI/CD and Oracle Deployment

### Source-to-mirror flow

`.github/workflows/sync_on_theme1.yml` runs when `main` receives a push and mirrors it to:

```text
git@github.com:maurelK/Theme1.git
```

The source repository remains the source of truth.

### Travis flow

`.travis.yml` runs on `main` only.

Stage 1:

1. Start Docker Buildx.
2. Login to Docker Hub using Travis variables.
3. Build multi-platform backend image.
4. Push backend image.
5. Build multi-platform frontend image.
6. Push frontend image.

Stage 2:

1. Decode `ORACLE_SSH_KEY_B64`.
2. Scan and register the Oracle host key.
3. Copy `compose.yaml` to `~/Theme1/compose.yaml`.
4. SSH to Oracle.
5. Run `docker compose pull`.
6. Run `docker compose up -d`.

Required Travis variables:

```text
DOCKER_USERNAME
DOCKER_PASSWORD
ORACLE_SSH_KEY_B64
ORACLE_HOST
ORACLE_USER
```

Required Oracle environment variables are listed in the production section above.

### Production frontend access

With the current [compose.yaml](compose.yaml), the frontend is published on port `8080`:

```text
http://145.241.169.233:8080/login
```

The frontend Nginx container proxies `/api` to the backend service internally. Users should access the frontend URL rather than calling Phoenix directly. The backend is currently published on port `4000`; restrict that port with the Oracle firewall or bind it behind the reverse proxy before a public release.

For the current IP-only deployment, use:

```env
PUBLIC_APP_URL=http://145.241.169.233:8080
```

If `PUBLIC_APP_URL` is omitted, the backend falls back to `http://PHX_HOST:8080`. It will not prevent startup, but an explicit value is recommended because password-reset emails must link to the real public frontend. A future HTTPS domain should replace this value.

### Bootstrap the first administrator

SSH into the Oracle VM after the production containers are running:

```bash
ssh ORACLE_USER@ORACLE_HOST
cd ~/Theme1
docker compose exec \
    -e ADMIN_EMAIL=admin@example.com \
    -e ADMIN_PASSWORD='use-a-strong-production-password' \
    backend mix run priv/repo/seeds.exs
```

The seed is idempotent. It creates the account if it does not exist or promotes the existing account to `administrator`. Do not put the real password in Git, shell history, or this document.

### Configure manager, HR/payroll, and administrator access

1. Open the production frontend login page.
2. Sign in with the bootstrapped administrator account.
3. Open the administrator dashboard.
4. Select a user in the administrator controls.
5. Select one of the predefined roles:
     - `manager`
     - `hr_payroll`
     - `administrator`
6. Save the role.

The user then signs out and signs in again. The backend returns the new role during login/session restoration, and the frontend opens the corresponding dashboard automatically.

Administrator responsibilities:

- promote and demote users
- create teams
- manage team memberships
- review correction requests
- manage system-level access

Manager responsibilities:

- review assigned team records
- inspect correction requests
- monitor team snapshots and exceptions
- work only within the manager’s assigned team scope

HR/payroll responsibilities:

- review approved time records
- review time and payroll categories
- access reporting scopes allowed by policy
- review correction requests

Employee responsibilities:

- manage their own working time
- view their own records
- submit correction requests
- change their own password

There are no separate “sign in as manager” or “sign in as administrator” buttons. Role selection is always performed by the backend after credential verification.

## 14. Release Preparation Checklist

Before committing:

- [ ] Remove temporary local validation users, teams, and correction records.
- [ ] Confirm `.env` is ignored and no secrets are staged.
- [ ] Confirm Oracle has `AUTH_JWT_SECRET`.
- [ ] Confirm Oracle has SMTP configuration.
- [ ] Confirm `PUBLIC_APP_URL` points to the public frontend URL (`http://145.241.169.233:8080` until HTTPS/domain are configured).
- [ ] Confirm production reset emails can be delivered.
- [ ] Confirm database backups exist.
- [ ] Confirm rollback image/version procedure.
- [ ] Run backend tests.
- [ ] Run backend strict compilation.
- [ ] Run frontend build.
- [ ] Validate Docker Compose files.
- [ ] Review `git diff` and `git diff --check`.

Commands:

```powershell
docker exec -e MIX_ENV=test theme1-dev-backend-1 mix test
docker compose -f compose.dev.yaml exec backend mix compile --warnings-as-errors
Set-Location theme2
npm run build
Set-Location ..
docker compose -f compose.dev.yaml config -q
docker compose config -q
git diff --check
```

## 15. Remaining Work

The core authentication and role-management implementation is complete. Remaining product and hardening work includes:

- persistent audit-log records for every role/team/review action
- stronger manager team-scope filtering on review requests
- applying approved corrections to working-time values
- full HR/payroll report generation and export
- login rate limiting and account abuse protection
- JWT revocation/rotation strategy
- security-header and production HTTPS verification on Oracle
- broader browser/end-to-end coverage
- final visual polish against every Figma dashboard frame

These items should be completed or explicitly accepted as follow-up scope before production release, depending on the release requirements.

## 16. Current Validation Status

Validated locally:

- login and registration
- HttpOnly JWT cookie flow
- CSRF-protected requests
- logout
- password change
- password reset
- role promotion/demotion
- team creation and membership lifecycle
- correction request submission
- correction review
- employee ownership filtering
- security headers
- frontend production build
- backend compilation
- backend tests
- Docker Compose configuration

Current branch:

```text
feature/authentication
```
