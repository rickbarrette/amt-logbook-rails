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
  column for the supervisor's ink signature next to the electronic one. CSV
  export too.
- **Reports**: progress toward 18 months (one rating) or 30 months (both,
  concurrently); equivalent months; calendar months; pace and projected date;
  hours per month; by category, ATA chapter, aircraft and type; ACS
  subject-area coverage; and per supervisor.
- **N-number lookup** from a local copy of the FAA Releasable Aircraft
  database. An admin uploads `ReleasableAircraft.zip` from the FAA. Owner
  names and addresses are not stored.
- **Accounts**: admins invite people. Authenticator-app 2FA, which supervisors
  and admins must use. Lockout after repeated failures.

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

Back up the `amt_storage` volume (the SQLite databases). Keep
`SECRET_KEY_BASE` safe: it seals signatures and encrypts authenticator
secrets.

## Development

```sh
bin/setup
bin/rails db:seed     # demo data: jane@example.com / sam@example.com / admin@example.com, password demo-password-123
bin/dev
bin/rails test && bin/rubocop && bin/brakeman
```

## License

Public domain ([Unlicense](LICENSE)).
