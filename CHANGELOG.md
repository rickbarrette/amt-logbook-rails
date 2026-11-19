# What's new

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
