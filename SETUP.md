# Media Server Setup Guide (Advanced)

Everything from the [basic setup](https://github.com/liamvibecodes/mac-media-stack), plus transcoding, quality profiles, metadata automation, download watchdog, VPN failover, and automated backups.

**Time to complete:** About 30 minutes

---

## Quick Option: One-Command Install

If you already have OrbStack (or Docker Desktop) and Plex installed, you can run a single command that handles the core setup:

```bash
curl -fsSL https://raw.githubusercontent.com/liamvibecodes/mac-media-stack-advanced/main/bootstrap.sh | bash
```

It will prompt you for VPN keys, configure all services, and install automation jobs. You'll still need to do Step 7 (configure Recyclarr, Kometa, Tdarr, and Unpackerr with API keys) manually afterward.

---

## Prerequisites

- A Mac (any recent macOS)
- [OrbStack](https://orbstack.dev) (recommended) or [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- Plex installed and signed in
- ProtonVPN WireGuard credentials
- A free TMDB API key (https://www.themoviedb.org/settings/api)

> **Why OrbStack?** It starts in ~2 seconds (vs 30s for Docker Desktop), uses ~1GB RAM (vs 4GB), and has 2-10x faster file I/O. It's a drop-in replacement that runs the same Docker commands. Docker Desktop works fine too.

---

## Step 1: Install a Container Runtime

You need a container runtime to run the behind-the-scenes services. Pick one:

### Option A: OrbStack (Recommended)

OrbStack is faster and lighter than Docker Desktop (~2s startup, ~1GB RAM).

```bash
brew install --cask orbstack
```

Or download from https://orbstack.dev. Open it once after installing.

### Option B: Docker Desktop

1. Go to https://www.docker.com/products/docker-desktop/
2. Click "Download for Mac"
   - If you have an M-series Mac (M1, M2, M3, M4): choose "Apple Silicon"
   - If you're not sure, click the Apple icon top-left of your screen > "About This Mac" and check the chip
3. Open the downloaded `.dmg` file
4. Drag Docker to your Applications folder
5. Open Docker Desktop from Applications
6. It will ask for your password to install components. Enter it.
7. Wait for it to finish starting (the whale icon in your menu bar will stop animating)
8. In Docker Desktop settings (gear icon), go to "General" and make sure "Start Docker Desktop when you sign in" is checked

Both options use the same `docker` and `docker compose` commands. Everything in this guide works identically with either one.

---

## Step 2: Download and Setup

```bash
cd ~
git clone https://github.com/liamvibecodes/mac-media-stack-advanced.git
cd mac-media-stack-advanced
bash scripts/setup.sh
```

---

## Step 3: Add VPN Keys

```bash
open -a TextEdit .env
```

Fill in `WIREGUARD_PRIVATE_KEY` and `WIREGUARD_ADDRESSES` from your ProtonVPN account.

---

## Step 4: Start the Stack

```bash
docker compose up -d
bash scripts/health-check.sh
```

Wait for all containers to show OK. First pull takes 3-5 GB.

Optional: enable automatic container updates (Watchtower):
```bash
docker compose --profile autoupdate up -d watchtower
```

---

## Step 5: Auto-Configure Services

```bash
bash scripts/configure.sh
```

This configures qBittorrent, Prowlarr (indexers), Radarr, Sonarr, and Seerr. It will print your API keys at the end. **Save them.**

---

## Step 6: Set Up Plex Libraries

1. Open http://localhost:32400/web
2. Settings > Libraries > Add Library
3. Add Movies (your home folder > Media > Movies)
4. Add TV Shows (your home folder > Media > TV Shows)

---

## Step 7: Configure Advanced Services

### Recyclarr (TRaSH quality profiles)

The setup script copied a template to `~/Media/config/recyclarr/recyclarr.yml`. Open it and replace the API key placeholders with the keys printed by configure.sh:

```bash
open -a TextEdit ~/Media/config/recyclarr/recyclarr.yml
```

Replace `YOUR_SONARR_API_KEY` and `YOUR_RADARR_API_KEY`, then save.

Recyclarr runs automatically at 3am daily. To trigger a manual sync:
```bash
docker compose run --rm recyclarr sync
```

### Kometa (Plex metadata)

Open the Kometa config and add your Plex token and TMDB API key:

```bash
open -a TextEdit ~/Media/config/kometa/config.yml
```

- **Plex token:** Follow https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token/
- **TMDB API key:** Create a free account at https://www.themoviedb.org/settings/api

Replace `YOUR_PLEX_TOKEN` and `YOUR_TMDB_API_KEY`, then save.

### Tdarr (transcoding)

1. Open http://localhost:8265
2. Configure your libraries (Movies: `/movies`, TV: `/tv`)
3. Add transcode plugins based on your preference (H.265 conversion saves ~50% disk space)
4. Set the temp/cache directory to `/temp`

### Unpackerr

Update `.env` with your Radarr and Sonarr API keys:
```bash
open -a TextEdit .env
```
Fill in `UN_SONARR_0_API_KEY` and `UN_RADARR_0_API_KEY`, then restart:
```bash
docker compose restart unpackerr
```

---

## Step 8: Install Automation Jobs

```bash
bash scripts/install-launchd-jobs.sh
```

This installs:
- Auto-healer (hourly VPN/container health check + restart)
- Nightly backup (configs + databases, 14-day retention)
- Download watchdog (stalled torrent auto-fix every 15 min)
- Kometa scheduler (metadata refresh every 4 hours)

Automation logs go to `~/Media/logs/` and launchd stdout/stderr logs go to `~/Media/logs/launchd/`.

### Optional: VPN Failover

If you have a NordVPN account as backup:

1. Copy `.env.nord.example` to `.env.nord`
2. Add your NordVPN WireGuard private key
3. Install the failover watcher:
```bash
bash scripts/install-vpn-failover.sh
```

This checks every 2 minutes and auto-switches between Proton and Nord after 3 consecutive failures.

---

## Day-to-Day Usage

| What | Where |
|------|-------|
| Browse and request | http://localhost:5055 |
| Watch | http://localhost:32400/web |
| Check downloads | http://localhost:8080 |
| Transcode status | http://localhost:8265 |

Everything else is fully automated.

---

## Troubleshooting

**Check overall health:**
```bash
bash scripts/health-check.sh
```

**View automation logs:**
```bash
tail -50 ~/Media/logs/auto-heal.log
tail -50 ~/Media/logs/download-watchdog.log
tail -50 ~/Media/logs/vpn-failover.log
```

**Manual VPN switch:**
```bash
bash scripts/vpn-mode.sh status    # check current provider
bash scripts/vpn-mode.sh proton    # switch to Proton
bash scripts/vpn-mode.sh nord      # switch to Nord
```

**Restart everything:**
```bash
docker compose down && docker compose up -d
```

**Uninstall automation jobs:**
```bash
for f in ~/Library/LaunchAgents/com.media-stack.*.plist; do launchctl unload "$f" && rm "$f"; done
```
