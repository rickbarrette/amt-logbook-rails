# AMT Logbook

A self-hosted logbook for aviation maintenance technicians earning the FAA
mechanic certificate through practical experience (14 CFR 65.77(b)). It's a
Rails app you can install on your phone (PWA).

- **Entries**: date, hours, airframe/powerplant/general, aircraft N-number,
  ATA chapter, ACS subject areas, description, work order and location.
- **Server-side timer**: clock in and out. The clock runs on the server, so you
  can close the app or switch devices and it keeps counting. Clocking out makes
  a draft entry.
- **Supervisor sign-off**: supervisors review entries and sign one or many at
  once with their password and authenticator code. Each signature records the
  signer, certificate, statement and time. It is sealed (HMAC) over a SHA-256
  of the entry, so a later change to either shows. Signers can only sign work
  their certificate covers (14 CFR 65.81). Entries can be returned with a note.
- **Printable logbook (PDF)**: cover with the technician's statement, a summary
  against 65.77, a statement page for each supervisor to sign (with a specimen
  signature), then every entry with page totals, totals brought forward, and a
  column for the supervisor's ink signature next to the electronic one.
- **Export and import**: CSV for spreadsheets, filtered by dates, category and
  status; a full export (JSON) of a technician's logbook, including
  e-signature records with their seals. Import a spreadsheet CSV (match its
  columns, preview, then import; a missing category or ATA chapter is
  suggested) or a full export. Imported entries arrive as drafts to check,
  then record or send for signature in one go; re-importing a file skips
  what's already there, and an import can be undone.
- **Reports**: progress toward 18 months (one rating) or 30 months (both,
  concurrently); equivalent months; calendar months; pace and projected date;
  hours per month; by category, ATA chapter, aircraft and type; ACS
  subject-area coverage; and per supervisor.
- **N-number lookup** from a local copy of the FAA Releasable Aircraft
  database. An admin uploads `ReleasableAircraft.zip` from the FAA. Owner
  names and addresses are not stored.
- **Accounts**: admins invite people. Authenticator-app 2FA, which supervisors
  and admins must use. Lockout after repeated failures.
- **Passkeys**: sign in with Face ID, Touch ID, Windows Hello, a phone or a
  security key, with nothing to type and nothing to phish. A passkey counts as
  both factors, works as the second step after a password, and confirms
  signatures and backups in place of the password and code.

## How experience is measured

14 CFR 65.77(b) requires **18 months** of practical experience for one rating,
or **30 months** performing the duties of both concurrently. The rule is
stated in months. FAA guidance measures those months against a full-time
(40-hour week) schedule, so the app reports *equivalent months* = qualifying
hours / 160, and also shows calendar months covered. General work counts
toward either rating. For both ratings, signed airframe *and* powerplant work
must be present. The hours-per-month figure, the ratings, and which
certificates can sign which work are in `config/faa/experience_rules.yml`. The
ACS subject areas are in `config/faa/acs_subject_areas.yml`.

The FAA inspector reviewing your Form 8610-2 makes the final determination.
This app helps you keep the records; it doesn't certify eligibility.

## Running it

```sh
cp .env.example .env      # set SECRET_KEY_BASE (bin/rails secret) and APP_HOST
APP_REVISION=$(git rev-parse --short HEAD) docker compose up -d --build
docker compose logs web | grep "Setup code"
```

Open the app and create the first admin with that setup code. Then:

1. **Admin → Users → Invite someone**, for technicians and supervisors. Without
   SMTP set, copy the invitation link and send it yourself.
2. On each technician, add the supervisors who may sign their entries.
3. Supervisors add their certificate (A&P, IA…) on their profile.
4. **Admin → Aircraft registry**: upload the FAA's `ReleasableAircraft.zip`.

For production behind Traefik (and Authentik), e.g. as a Portainer stack, use
`docker-compose.portainer.yml` with the published image
`barrettefab/amt-logbook-rails`; see [docs/authentik.md](docs/authentik.md).

Back up the `amt_storage` volume (the SQLite databases), or download a copy of
the main database from **Admin → Backup** (it asks for your password and
authenticator code; restore steps are on that page). Keep `SECRET_KEY_BASE`
safe: it seals signatures and encrypts authenticator secrets, and a restored
backup needs the same one.

## Running it on the internet

The app's own sign-in is built to face the internet, with or without
Authentik (or another forward-auth proxy) in front:

- **Two-factor for everyone**: Admin → Settings → Two-factor sign-in →
  Everyone. Admins and supervisors always need it. An authenticator app or a
  passkey both count.
- **Passkeys** are tied to the public address (`APP_URL` or `APP_HOST`):
  changing the hostname later means everyone adds their passkeys again.
- **One hostname**: set `APP_HOST` (or `APP_URL`). Requests for any other
  host are refused, so a forged `Host` header can't redirect anyone. Add
  others with `APP_EXTRA_HOSTS` (comma-separated).
- **Email** for password resets: `SMTP_ADDRESS`, `SMTP_PORT`,
  `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAIL_FROM`. Without it, an admin makes a
  reset link from the user's page (Admin → Users) and sends it by hand.
- **Behind Traefik without Authentik**: in `docker-compose.portainer.yml` set
  `TRAEFIK_MIDDLEWARES=amt-logbook-limits@docker` (caps request size at the
  proxy).

What's already in place: HTTPS only (HSTS), secure cookies, a strict
Content-Security-Policy, CSRF protection, rate limits on sign-in, password
reset, two-factor and signing, account lockout after 10 failed tries
(a password reset or an admin lifts it), sign-ins that end after 30 idle
days or 90 days at most, request bodies capped at 128 MB, passwords and codes
kept out of the logs, and invitation-only accounts. The first admin needs the
one-time setup code printed in the server log.

## Development

```sh
bin/setup
bin/rails db:seed     # demo data: jane@example.com / sam@example.com / admin@example.com, password demo-password-123
bin/dev
bin/rails test && bin/rubocop && bin/brakeman
```

## License

Public domain ([Unlicense](LICENSE)).
