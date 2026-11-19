# Running behind Authentik

`docker-compose.portainer.yml` puts Authentik forward auth in front of the
app, so nobody without an Authentik account reaches it. People then sign in to
the app itself (its own accounts, by invitation, with its own two-factor).
Everyone who uses the app, technicians and supervisors alike, therefore needs
an Authentik account too.

## Authentik

1. **Applications → Providers → Create → Proxy Provider**, *Forward auth
   (single application)* with external host `https://logbook.example.com`
   (or add the host to your existing domain-level provider).
2. Add the paths below to **Unauthenticated Paths** (single application), or
   as full-URL regexes (`^https://logbook\.example\.com/...`) for domain level.
   They let the installed app (PWA) load its icon, manifest, service worker and
   offline page, which browsers fetch without Authentik's cookie.
3. Create an application for the provider and add it to your outpost.

```
^/manifest(\.json)?$
^/service-worker(\.js)?$
^/offline$
^/(icon|favicon)\.(png|svg)$
^/assets/.+$
```

Optional, if you invite people who don't have an Authentik account (they still
can't use the app afterwards unless they get one, so usually leave this out):

```
^/invitations/[A-Za-z0-9]{32}$
```

## Single sign-on (OpenID Connect)

Separate from forward auth: the app's sign-in page can offer **Sign in with
Authentik**, so people don't need an app password.

1. In Authentik: **Providers → Create → OAuth2/OpenID Provider**, client type
   *Confidential*, redirect URI `https://logbook.example.com/auth/oidc/callback`,
   scopes `openid email profile`. Create an application for it.
2. In the stack's environment variables:

```
OIDC_ISSUER=https://auth.example.com/application/o/<application-slug>/
OIDC_CLIENT_ID=...
OIDC_CLIENT_SECRET=...
OIDC_PROVIDER_NAME=Authentik
# Optional:
OIDC_ADMIN_GROUP=amt-admins   # members are app admins; others lose admin at sign-in
PASSWORD_LOGIN=false          # once SSO works, hide email/password sign-in
```

Accounts still come from invitations: the invitee opens the link and chooses
**Continue with Authentik**. Existing users link from their profile (or are
linked automatically when Authentik marks their email verified). SSO sign-ins
skip the app's own authenticator code, so require MFA in Authentik's flow.
Supervisors can confirm signatures with a fresh Authentik sign-in.

## Traefik

The middleware named by `AUTHENTIK_MIDDLEWARE` (default `authentik@docker`) is
usually defined once on the Authentik container:

```yaml
- traefik.http.middlewares.authentik.forwardauth.address=http://authentik-server:9000/outpost.goauthentik.io/auth/traefik
- traefik.http.middlewares.authentik.forwardauth.trustForwardHeader=true
- traefik.http.middlewares.authentik.forwardauth.authResponseHeaders=X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name,X-authentik-uid
```

To run without Authentik, set `AUTHENTIK_MIDDLEWARE` to a no-op middleware or
delete that label.
