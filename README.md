# QSL Card Creator

A small web app that creates printable **QSL cards** for amateur radio contacts.
Fill in the contact data by hand, or let your APRS system open the page already
filled in through URL parameters, then print the card or download it as a PNG.

The card in this repository is the QSL card of **PP5PK** (Mafra, Santa Catarina,
Brazil), but it is easy to adapt to any callsign (see [Customizing](#customizing)).

![Example QSL card](docs/example-card.jpg)

## Features

- Single-sided card, **140 × 90 mm**, with a translucent QSO data panel.
- Contact fields: call, date (UTC), time (UTC), frequency/band and mode.
- **APRS auto-fill**: open the page with the contact data in the URL.
- **Print** straight from the browser (or save as PDF), sized exactly 140 × 90 mm.
- **Download PNG** at print-friendly resolution.
- The last contact is remembered in the browser (`localStorage`).
- Works in Chrome, Opera and Firefox.

## Auto-fill through the URL

Every field can be passed as a query parameter:

| Parameter | Format                  | Example   |
| --------- | ----------------------- | --------- |
| `call`    | letters, digits and `/` | `PY2AAA`  |
| `date`    | `YYYY-MM-DD` (UTC)      | `2026-09-30` |
| `time`    | `HHMM` or `HH:MM` (UTC) | `1225`    |
| `freq`    | free text               | `145.570` |
| `mode`    | free text               | `APRS`    |

Example:

```
https://qsl.example.net/?call=PY2AAA&date=2026-09-30&time=1225&freq=145.570&mode=APRS
```

Values are sanitized on load. When no parameter is present, the last contact
saved in the browser is used (frequency and mode default to `144.390` and `APRS`).

## Installation

This guide installs the app on a **Debian or Ubuntu server** (a VPS, for example)
with Apache as the public web server. Follow the steps **in order**.

Before you start, you need:

- SSH access to the server with **root** (or sudo) privileges;
- a domain or subdomain **already pointing to the server's IP address**;
- ports **80 and 443** open to the internet (required by Let's Encrypt).

Conventions used below:

- `qsl.example.net` is an example: **replace it with your own domain** everywhere.
- All commands run in a **root shell**. If you log in as a normal user, run `sudo -i` first.
- The project is installed in `/var/www/html/cards`.

A condensed checklist of these steps is available in
[`templates/install.txt`](templates/install.txt).

How the pieces fit together:

```
Browser ──HTTPS──▶ Apache (443) ──proxy──▶ srvx on 127.0.0.1:3000 ──▶ built app
```

### Step 1: Check the requirements

Run the requirements script **before anything else**. It makes sure nothing is
missing and stops you early if something is incompatible, so you do not find out
halfway through the installation.

You do not need the project for this step. Download the script on its own and run it
(if `curl` is missing, install it first with `apt update && apt install -y curl`):

```bash
curl -fsSLo check-requirements.sh \
  https://raw.githubusercontent.com/PP5PK/QSL_card_Creator/main/templates/check-requirements.sh
bash check-requirements.sh
```

**Do not continue until the script ends with `All requirements are satisfied.`**
It always asks for confirmation before changing anything, and you can run it as many
times as you want.

Example of the report:

```
Checking requirements
  git                          [ OK ]    2.43.0
  curl                         [ OK ]    8.5.0
  ca-certificates              [ OK ]    20240203
  Node.js                      [WARN]    18.19.0 (needs ^20.19 or >=22.12)
  npm                          [ OK ]    9.2.0
  Apache (apache2)             [MISS]    not installed
  ...

!! Incompatible versions found
  ! Node.js 18.19.0 is incompatible: this project needs ^20.19 or >=22.12.
```

What the script checks and does:

| Requirement | Check | If missing or too old |
| ----------- | ----- | --------------------- |
| `git`, `curl`, `ca-certificates`, `apache2` (>= 2.4), `certbot`, `python3-certbot-apache` | installed + version | installed with `apt` |
| Node.js `^20.19` or `>= 22.12` and npm | installed + version | installed from [NodeSource](https://github.com/nodesource/distributions) (Node.js 22 LTS, npm included) |
| Apache modules `proxy`, `proxy_http`, `rewrite`, `ssl` | enabled | enabled with `a2enmod`, then Apache is restarted |
| Unused packages | listed by `apt` | removed with `apt autoremove` (the list is shown first) |

Options:

| Option | Effect |
| ------ | ------ |
| `-c`, `--check-only` | only report, never install or remove anything |
| `-n`, `--dry-run` | show the commands that would run, without running them |
| `-y`, `--yes` | do not ask for confirmation (non-interactive) |
| `-h`, `--help` | show the help |

The script exits with status `0` when every requirement is satisfied and `1`
otherwise. Automatic installation works on Debian/Ubuntu (apt); on other systems it
only reports.

<details>
<summary>Prefer to do it by hand? Manual installation</summary>

| Component | Why it is needed |
| --------- | ---------------- |
| `git` | download the project and, later, updates |
| `curl`, `ca-certificates` | add the Node.js repository and run the checks |
| **Node.js `^20.19` or `>= 22.12`** with **npm** | install dependencies, build and run the app |
| `apache2` | public web server (HTTPS and reverse proxy) |
| `certbot`, `python3-certbot-apache` | free Let's Encrypt certificate |

```bash
apt update
apt install -y git curl ca-certificates apache2 certbot python3-certbot-apache

# Node.js 22 LTS with npm (the distribution packages are often too old)
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

# Apache modules
a2enmod proxy proxy_http rewrite ssl
systemctl restart apache2

# Check everything
git --version
node -v        # must be v20.19+ or v22.12+
npm -v         # must print a version
apache2 -v
certbot --version
apache2ctl -M | grep -E "proxy_module|proxy_http_module|rewrite_module|ssl_module"
```

</details>

### Step 2: Download the project

```bash
git clone https://github.com/PP5PK/QSL_card_Creator.git /var/www/html/cards
cd /var/www/html/cards
```

### Step 3: Install the dependencies and build

```bash
npm ci
npm run build
```

The build is written to `.vercel/output/` (it is not committed to git).

Optional smoke test. Start the app, check it from a second terminal and stop it
with Ctrl+C:

```bash
npm start
# in another terminal:
curl -sI http://127.0.0.1:3000/card/bg.jpg | head -1    # HTTP/1.1 200
```

### Step 4: Create the Apache site (HTTP)

Copy the template **using your domain as the file name** and edit it:

```bash
cp /var/www/html/cards/templates/qsl.domain.net.conf /etc/apache2/sites-available/qsl.example.net.conf
nano /etc/apache2/sites-available/qsl.example.net.conf
```

Both the **file name** and its **content** must match your domain. Inside the file,
replace `qsl.domain.net` with your domain in the `ServerName` and `RewriteCond`
lines:

```apache
<VirtualHost *:80>
     ServerName qsl.example.net
     DocumentRoot /var/www/html/cards
RewriteEngine on
RewriteCond %{SERVER_NAME} =qsl.example.net
RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>
```

Enable the site, check the syntax and reload Apache. The check must end with
`Syntax OK`; a warning about the server's *fully qualified domain name* (`AH00558`)
before it is harmless:

```bash
a2ensite qsl.example.net
apache2ctl configtest
systemctl reload apache2
```

### Step 5: Get the HTTPS certificate

```bash
certbot --apache -d qsl.example.net
```

Answer the questions (e-mail, terms of service). Certbot creates and enables the
HTTPS site `/etc/apache2/sites-available/qsl.example.net-le-ssl.conf`.

### Step 6: Point the HTTPS site to the app

Edit the file certbot just created:

```bash
nano /etc/apache2/sites-available/qsl.example.net-le-ssl.conf
```

Certbot copies the `DocumentRoot` line from the HTTP site. **Replace that line** with
the three proxy lines, as in
[`templates/qsl.domain.net-le-ssl.conf`](templates/qsl.domain.net-le-ssl.conf).

Before:

```apache
     ServerName qsl.example.net
     DocumentRoot /var/www/html/cards
```

After:

```apache
     ServerName qsl.example.net

     ProxyPreserveHost On
     ProxyPass / http://127.0.0.1:3000/
     ProxyPassReverse / http://127.0.0.1:3000/
```

Removing the `DocumentRoot` is recommended: with `ProxyPass /` every request goes to
the app, so Apache never serves files from that folder. If you keep the line, it
does no harm while the proxy works, but should the proxy lines ever be removed or
mistyped, Apache would start serving the project folder (source code,
`package.json`, `.git`) to the internet.

Check the syntax (`Syntax OK`) and reload:

```bash
apache2ctl configtest
systemctl reload apache2
```

### Step 7: Create the systemd service

```bash
cp /var/www/html/cards/templates/qsl.service /etc/systemd/system/qsl.service
systemctl daemon-reload
systemctl enable --now qsl.service
systemctl status qsl.service --no-pager
```

The template assumes the project is in `/var/www/html/cards`. If you installed it
elsewhere, edit the paths in `/etc/systemd/system/qsl.service` before the
`daemon-reload`.

### Step 8: Test

```bash
curl -sI http://127.0.0.1:3000/card/bg.jpg | head -1    # HTTP/1.1 200
curl -sI https://qsl.example.net/ | head -1             # 200 (HTTP/1.1 or HTTP/2)
```

Then open `https://qsl.example.net/` in your browser. Done.

### Updating

After pulling new code or editing any file under `src/` or `public/`, rebuild
and restart the service. The service serves the **built** output, so restarting
alone does not apply source changes:

```bash
cd /var/www/html/cards
git pull
npm ci
npm run build
systemctl restart qsl.service
```

## Customizing

All the card content lives in a few files:

| What                                            | Where                          |
| ----------------------------------------------- | ------------------------------ |
| Callsign, name, QTH, grid/zones, website        | `src/components/qsl-card.tsx`  |
| Card colors, fonts, positions and sizes         | `src/styles.css`               |
| Background image                                | `public/card/bg.jpg`           |
| Downloaded file name prefix (`PP5PK_...png`)    | `fileName()` in `src/lib/qso.ts` |
| Page header, helper texts, mode buttons         | `src/routes/index.tsx`         |
| Page title and description                      | `src/routes/__root.tsx`        |
| Print size (default 140 × 90 mm)                | `@page` rule in `src/styles.css` |

Tips:

- To move the identification block (callsign, name, QTH...) change `top` and
  `left` in the `.qsl-id` rule of `src/styles.css`. Values are percentages of
  the card, so the layout scales with it.
- The QSO data panel is styled by `.qsl-qso`; its darkness comes from the
  gradient in its `background`.
- The background image is scaled with `object-fit: cover` and cropped to the card ratio (14:9), so any
  image works; the current one is 1728 × 1152 px. Keep important details away from the edges.
- Rebuild and restart the service after any change (see [Updating](#updating)).

### Keep the card CSS safe for PNG export

The PNG is generated in the browser with
[modern-screenshot](https://github.com/qq15725/modern-screenshot). Some CSS
renders differently when exported, mostly in Firefox. If you restyle the card,
check the downloaded PNG in Firefox too. Two cases are already handled in this
project:

- `backdrop-filter` is not applied in the exported PNG, so the QSO panel uses a
  plain translucent gradient instead of a blur.
- `repeating-linear-gradient` is rendered incorrectly in Firefox exports, so the
  decorative stripe above the QSO panel is a small inline SVG tile.

## Project structure

```
.
├── docs/                 Screenshot used by this README
├── public/               Static files (card background, favicon)
├── src/
│   ├── components/       QSL card component
│   ├── lib/              QSO parsing/formatting helpers
│   ├── routes/           Page (TanStack Router)
│   └── styles.css        Card and page styles
├── templates/            Apache/systemd examples, install.txt, check-requirements.sh
├── package.json
└── vite.config.ts
```

Built with [TanStack Start](https://tanstack.com/start), React, Vite and
Tailwind CSS. Production runs through [srvx](https://github.com/h3js/srvx).

## Troubleshooting

- **My changes do not show up**: rebuild and restart the service
  (`npm run build && systemctl restart qsl.service`). Use a private window
  to rule out browser cache.
- **502 / Bad Gateway from Apache**: the service is not running or not on port
  3000. Check `systemctl status qsl.service` and
  `journalctl -u qsl.service -n 50 --no-pager`.
- **Service fails to start**: confirm that `node_modules/.bin/srvx` and
  `.vercel/output/` exist (run `npm ci` and `npm run build`) and that the paths
  in `qsl.service` match where you installed the project.
- **`apache2ctl configtest` complains about `Proxy`/`Rewrite`**: enable the
  modules with `a2enmod proxy proxy_http rewrite ssl` (or run `check-requirements.sh` again).
- **`npm: command not found`**: npm is not installed. Install Node.js with npm as
  described in [Step 1](#step-1-check-the-requirements).
- **Build fails with a Node.js version error**: this project needs Node.js
  `^20.19` or `>= 22.12`.

## License

Released into the public domain under [The Unlicense](LICENSE).

73 de PP5PK
