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
