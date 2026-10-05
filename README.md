# TIME MANAGER - User APIs
 
This project provides REST APIs for managing users for the **TIME MANAGER** project.
 
## Reproducible Development

Install Docker Desktop with Docker Compose, then run the full development stack from the repository root:

```powershell
docker compose -f compose.dev.yaml up --build
```

Compose runs PostgreSQL, Phoenix, and Vite in containers. The backend installs Elixir dependencies from `mix.lock`, and the frontend runs `npm ci` from `package-lock.json`. Open `http://localhost:5173`; Vite proxies API requests to the backend container. The backend is also published at `http://localhost:4001`, and PostgreSQL is available to local tools such as pgAdmin at `localhost:5433`.

### After each change

Use the commands below in order depending on what changed:

```powershell
# 1) Start or restart the development stack
cd C:\Users\an804\Desktop\I-DEV-700-INT-7-1-timemanager-23
docker compose -f compose.dev.yaml up --build -d

# 2) If only a backend file changed, reload backend only
# this rebuilds the backend container without restarting the whole stack
docker compose -f compose.dev.yaml up -d --no-deps --build backend

# 3) If only a frontend file changed, reload frontend only
docker compose -f compose.dev.yaml up -d --no-deps --build frontend

# 4) If you changed Elixir code or DB logic, run the backend checks
# inside the running backend container
docker compose -f compose.dev.yaml exec backend mix compile
# Explicitly select test config so Ecto SQL Sandbox is enabled.
docker compose -f compose.dev.yaml exec -e MIX_ENV=test backend mix test

# 5) If you changed Vue code, verify the frontend build
cd theme2
npm run build
cd ..

# 6) If you want to verify the live app, hit the local endpoints
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:4001/"
Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:5173/api/users"

# 7) Stop the stack when finished
docker compose -f compose.dev.yaml down
```

### Local logs

To inspect the active development logs while the stack is running:

```powershell
# follow backend logs
docker compose -f compose.dev.yaml logs -f backend

# follow frontend logs
docker compose -f compose.dev.yaml logs -f frontend

# follow database logs
docker compose -f compose.dev.yaml logs -f db

# view the last 100 lines of a service
docker compose -f compose.dev.yaml logs --tail=100 backend
docker compose -f compose.dev.yaml logs --tail=100 frontend
```

Use these when you want to debug start-up failures, request errors, proxy issues, or database access problems. `-f` follows the logs live until you stop with `Ctrl+C`.

### Pre-push checks

Run these before pushing changes to `main`:

```powershell
docker compose -f compose.dev.yaml exec -e MIX_ENV=test backend mix test
docker compose -f compose.dev.yaml exec frontend npm run build
docker build -t time-manager-backend:preflight ./theme1
docker build -t time-manager-frontend:preflight ./theme2
```

The first two commands test the development containers. The last two build the same production Dockerfiles used for deployment. Stop the development stack with `docker compose -f compose.dev.yaml down`; this keeps its database volume. Avoid `down -v` unless you intend to delete that local database.

### Authentication setup

Authentication uses PBKDF2 password hashes, Joken-signed JWTs, an HttpOnly `theme1_auth` cookie, and an `X-CSRF-Token` request header. The JWT is never exposed to frontend JavaScript.

Add these values to the environment used by each deployment:

```env
AUTH_JWT_SECRET=your-strong-jwt-secret
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=your-strong-admin-password
```

`AUTH_JWT_SECRET` is required in production. `ADMIN_EMAIL` and `ADMIN_PASSWORD` are optional bootstrap values; when supplied, the seed script creates or promotes that account to administrator without printing the password. The production backend entrypoint runs Ecto migrations before starting Phoenix.

The public authentication endpoints are:

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

All user, clock, and working-time endpoints now require the JWT cookie and matching `X-CSRF-Token` header.

Password reset responses are generic to prevent email enumeration. Local development exposes a reset token for testing; production must connect the reset-token delivery to the configured mail provider before enabling public recovery.

The frontend and API are served from the same origin in production through Nginx, so no wildcard CORS policy is enabled. Phoenix adds `nosniff`, frame, referrer, permissions, and Content-Security-Policy headers at the endpoint boundary.

Role and team permissions are exposed through these protected endpoints:

```text
GET    /api/roles
GET    /api/teams
PUT    /api/admin/users/:userID/role
POST   /api/admin/teams
POST   /api/admin/teams/:teamID/members/:userID
DELETE /api/admin/teams/:teamID/members/:userID
POST   /api/workingtime/:id/correction-requests
GET    /api/reviews/correction-requests
PUT    /api/reviews/correction-requests/:id
```

Only administrators can change roles, create teams, or change team membership. Users may belong to multiple teams.
Employees can submit correction requests for their own working-time entries. Managers, HR/payroll, and administrators can review and approve or reject pending requests.

## Production

Travis builds and pushes the images on `main`, copies `compose.yaml` to the Oracle server, then runs `docker compose pull && docker compose up -d`. The server's `.env` must define `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, and `SECRET_KEY_BASE`. The development Compose file uses separate local-only database credentials and storage.
 
## User API Flow
 
The User component supports the following CRUD operations:
 
```
Create User
    |
    v
POST /api/users
    |
    v
User is stored in the database
    |
    v
Find User by Email
    |
    v
GET /api/users?email=...
    |
    v
User is selected
    |
    +------------------+
    |                  |
    v                  v
Update User        Delete User
    |                  |
    v                  v
PUT /api/users/:id  DELETE /api/users/:id
```
 
## Important User Flow
 
The user's email is unique in the database.
 
The frontend allows the user to enter an email to find the user:
 
```
GET /api/users?email=ahmed@example.com
```
 
Once the user is found, the returned user's `id` is used for updating or deleting that user.
 
For example:
 
**Find:**
```
GET /api/users?email=ahmed@example.com
```
 
⬇
 
**User:**
```json
{
  "id": 1,
  "username": "ahmed",
  "email": "ahmed@example.com"
}
```
 
⬇
 
**Update:**
```
PUT /api/users/1
```
 
or
 
**Delete:**
```
DELETE /api/users/1
```
 
Because email is unique, an email should identify only one user.
 
## User APIs
 
### 1. Get All Users
 
`GET /api/users`
 
```bash
curl.exe http://localhost:4000/api/users
```
 
You can also filter by email and/or username:
 
```bash
curl.exe "http://localhost:4000/api/users?email=ahmed@example.com&username=ahmed"
```
 
### 2. Get User by ID
 
`GET /api/users/:userID`
 
```bash
curl.exe http://localhost:4000/api/users/1
```
 
If the user does not exist, the API returns:
 
```
HTTP/1.1 404 Not Found
```
 
### 3. Create User
 
`POST /api/users`
 
Create a `user.json` file:
 
```json
{
  "username": "ahmed",
  "email": "ahmed@example.com"
}
```
 
Then run:
 
```bash
curl.exe -X POST "http://localhost:4000/api/users" -H "Content-Type: application/json" --data-binary "@user.json"
```
 
A successful creation returns:
 
```
HTTP/1.1 201 Created
```
 
The email must be unique. If the email already exists, the API returns:
 
```
HTTP/1.1 422 Unprocessable Content
```
 
with an error such as:
 
```json
{
  "errors": {
    "email": [
      "has already been taken"
    ]
  }
}
```
 
### 4. Update User
 
`PUT /api/users/:userID`
 
Create an `update-user.json` file:
 
```json
{
  "username": "ahmed_updated",
  "email": "ahmed.new@example.com"
}
```
 
Then run:
 
```bash
curl.exe -X PUT "http://localhost:4000/api/users/1" -H "Content-Type: application/json" --data-binary "@update-user.json"
```
 
The user ID comes from the user found through the email search.
 
For example:
 
```
GET /api/users?email=ahmed@example.com
        ↓
User ID = 1
        ↓
PUT /api/users/1
```
 
The email must remain unique when updating the user.
 
### 5. Delete User
 
`DELETE /api/users/:userID`
 
```bash
curl.exe -i -X DELETE "http://localhost:4000/api/users/1"
```
 
A successful delete returns:
 
```
HTTP/1.1 204 No Content
```
 
If the user does not exist:
 
```
HTTP/1.1 404 Not Found
```
 
## User Fields
 
| Field    | Type   | Required | Description             |
|----------|--------|----------|--------------------------|
| username | string | Yes      | User's username          |
| email    | string | Yes      | User's unique email address |
 
The email must have a valid format such as:
 
```
ahmed@example.com
```
 
The email address is also unique in the database.
 
## Database Migrations
 
The project uses Ecto migrations to create and update the database structure.
 
Before running the server, run:
 
```bash
mix ecto.migrate
```
 
To check the migration status:
 
```bash
mix ecto.migrations
```
 
If another team member has added new migrations and you have pulled those changes, run:
 
```bash
mix ecto.migrate
```
 
again.
 
> **Important for the team:** Do not skip migrations after pulling backend changes. The application may not work correctly if your local database is missing the latest migrations.
 
## Run the Server
 
From the project directory:
 
```bash
mix phx.server
```
 
The API will be available at:
 
```
http://localhost:4000
```
 
## Typical Development Flow
 
For a new team member:
 
1. Clone the repository
2. Checkout the `dev` branch
3. Install dependencies
4. Run database migrations
5. Start Phoenix server
6. Run/test the required APIs
7. Make changes
8. Commit changes
9. Push to `dev`
## After Pulling New Backend Changes
 
Always check whether there are new migrations:
 
```bash
git pull
mix ecto.migrate
```
 
Then start the server:
 
```bash
mix phx.server
```
 
## One Important Change I Made
 
I specifically added this part:
 
```
GET /api/users?email=...
        ↓
Find the unique user
        ↓
Get user's ID
        ↓
PUT /api/users/:id
or
DELETE /api/users/:id
```