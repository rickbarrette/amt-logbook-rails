# What's new

## 2026.11.4

### Changes
- **Fill in an entry while the clock runs**: clocking in opens a draft entry. Write it up any time (from the timer, the dashboard, or the green "Clocked in" bar); clocking out sets its hours. "Clock in & fill in" opens it straight away.
- **Import entries** (Entries → Import): a spreadsheet saved as CSV (match its columns, check a preview, then import) or a full export from AMT Logbook. Entries arrive as drafts to check, then record or send them for signature in one go. A missing category or ATA chapter is suggested, rows already in your logbook are skipped, and an import can be undone.
- **Full export** (Export page): your whole logbook as one file, including the electronic signature records, to keep as a backup or import on another server.
- **Export filters**: choose dates, a category, and which entries (signed, awaiting signature, or everything) for the PDF and CSV.
- **Better suggestions**: about 640 maintenance terms across every ATA chapter, more accurate chapters and ACS areas (for example 100-hour inspections are ATA 05, mixture cables 76), and a hint when one entry covers two unrelated jobs.
- The "Print" link is now **Export**.

### Fixes
- Dropdowns, text boxes and buttons are the same height, so the clock-in and filter rows line up (most visible in Safari). Dropdowns follow dark mode.

### For administrators
- **Admin → Backup**: download a copy of the whole database after confirming your password and authenticator code (or a fresh single sign-on). Restore steps are on that page; a restore needs the same `SECRET_KEY_BASE`.

## 2026.11.3

### Changes
- **Formatting in entries**: the description has a formatting bar (bold, italic, heading, bulleted and numbered lists, part numbers, links) and a Preview tab. Lists continue when you press Enter. Entries show formatted, and the printed logbook and CSV get clean text with bullets.
- **"… and add another"** on new entries: saves the entry (records it, or sends it to be signed) and opens a new one with the same date, aircraft, location, work order and supervisor.
- **Suggested category, ATA chapter and ACS areas**, from what you type in the description and from your past entries. Tap **Use** to fill them in; nothing changes on its own.
- **Airport database** (OurAirports, the same data SAM uses). It downloads on first start and can be updated from Admin → Airports.
- **Suggestions from your history**: the location field offers places you've worked first, then airports by code, name or town. The N-number field offers aircraft you've worked on first, then FAA registry matches. A new entry starts with your last location.

## 2026.11.2

### Fixes
- The entry form showed the category, description, ATA, location and ACS fields twice, and the empty second copy replaced what was typed in the first.

## 2026.11.1

### Changes
- **About page** (link at the bottom of every page): version, build, uptime and these release notes. Admins also see configuration, storage, background jobs and components.
- **Ink-only signatures** (Admin → Settings). Technicians type their supervisor's name and certificate on each entry and record it. Supervisors sign the printed logbook by hand, and recorded entries count toward the requirement.
- **Single sign-on (OpenID Connect)**, for example with Authentik. Sign in, accept an invitation, or link your account from the profile page. Supervisors can confirm a signature with a fresh single sign-on instead of their password and code.
- **Install the app** from Profile → App on this device.
- Aircraft added before the FAA registry was imported now get their details from the registry: after each import, when they're used again, or with **Update from FAA registry** on the aircraft or Admin → Aircraft registry page.

### For administrators
- Single sign-on settings: `OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`, `OIDC_PROVIDER_NAME`, and optionally `OIDC_ADMIN_GROUP` and `PASSWORD_LOGIN=false`. See docs/authentik.md.
- The web app manifest is now requested with credentials, so it loads behind forward auth. The icons, service worker and offline page still need to be on Authentik's unauthenticated paths.

## 2026.11.0

### Changes
- Logbook entries with category, aircraft, ATA chapter and ACS subject areas.
- Server-side clock-in/out timer that keeps running with the app closed.
- Supervisor sign-off with password and authenticator code. Signatures are sealed. Entries can be returned with a note.
- Printable PDF logbook with supervisor statement pages and ink-signature columns, and a CSV export.
- Progress toward 14 CFR 65.77(b), with statistics and charts.
- N-number lookup from the FAA Releasable Aircraft database.
- Invitation-only accounts, 2FA (required for supervisors and admins), and an installable PWA.
- Docker image and a Portainer/Traefik/Authentik stack file (docker-compose.portainer.yml).
