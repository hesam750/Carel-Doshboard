Deployment to Vercel

Overview
- This dashboard is a static web UI hosted on Vercel, with a serverless proxy at `/proxy` to forward HTTP requests to the PLC (to avoid browser CORS issues).
- Only HTTP/HTTPS PLC endpoints are supported (e.g., `getvar.csv`, `vars.htm`, `setvar.csv`).

Quick Start (CLI)
- Install: `npm i -g vercel`
- From this folder: `cd dashboard`
- First deploy (interactive): `vercel`
  - Framework: None
  - Build Command: (leave empty)
  - Output Directory: `.`
- Production deploy: `vercel --prod`

Configure Proxy Security
- Set Vercel env `ALLOWED_PROXY_HOSTS` to the public PLC host(s), e.g. `1.2.3.4:8080`.
- Vercel → Project → Settings → Environment Variables.
- If unset, the proxy allows all hosts (for quick tests only). Configure it before sharing publicly.

PLC URL and Dashboard
- The app reads `assets/data/dashboard.config.json` if present. If it contains `deviceUrl`, it uses that as the base (e.g., `http://1.2.3.4:8080/getvar.csv`).
- Otherwise it defaults to `http://169.254.61.68/getvar.csv`.
- All reads/writes are sent via `/proxy?url=<full-target-url>`.

Notes
- PowerShell scripts (`*.ps1`) are not executed on Vercel. They remain for local commissioning only.
- If the PLC does not serve HTTP or blocks cross-origin requests entirely, use a dedicated backend that speaks the PLC protocol and exposes an HTTP API, then point the dashboard to it.