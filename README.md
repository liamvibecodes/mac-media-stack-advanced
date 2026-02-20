# Mac Media Stack (Advanced)

A fully automated, self-healing media server for macOS. Builds on [mac-media-stack](https://github.com/liamvibecodes/mac-media-stack) with additional services for transcoding, quality optimization, metadata management, and automated maintenance.

**New to this?** Start with the [basic version](https://github.com/liamvibecodes/mac-media-stack) first. This version is for users who want the full power-user setup.

## What's Added Over Basic

| Service | What It Does |
|---------|-------------|
| **Tdarr** | Automatic transcoding (convert codecs, save disk space) |
| **Recyclarr** | TRaSH Guides quality profiles (penalizes bad release groups, scene releases) |
| **Kometa** | Plex metadata automation (franchise collections, resolution overlays, RT ratings) |
| **Unpackerr** | Auto-extracts RAR'd downloads for Radarr/Sonarr |

## Automation

| Script | Schedule | What It Does |
|--------|----------|-------------|
| Auto-healer | Hourly | Restarts VPN/containers if they go down |
| Nightly backup | Daily | Backs up all configs and databases (14-day retention) |
| Download watchdog | Every 15 min | Detects stalled/slow torrents, auto-fixes or swaps them |
| Kometa | Every 4 hours | Updates Plex collections and metadata overlays |
| VPN failover | Every 2 min (optional) | Auto-switches between ProtonVPN and NordVPN on sustained failure |

## One-Command Install

Requires Docker Desktop and Plex already installed. Handles everything else.

```bash
curl -fsSL https://raw.githubusercontent.com/liamvibecodes/mac-media-stack-advanced/main/bootstrap.sh | bash
```

## Manual Quick Start

If you prefer to run each step yourself:

```bash
git clone https://github.com/liamvibecodes/mac-media-stack-advanced.git
cd mac-media-stack-advanced
bash scripts/setup.sh
# edit .env with VPN keys
docker compose up -d
bash scripts/configure.sh
bash scripts/install-launchd-jobs.sh
```

## Full Setup Guide

See [SETUP.md](SETUP.md) for the complete walkthrough.

## Architecture

```
Seerr (request) -> Radarr/Sonarr -> Prowlarr (search) -> qBittorrent (via VPN) -> Plex (watch)
                                                           |
                                     Unpackerr (extract) --+
                                     Bazarr (subtitles) ----+
                                     Tdarr (transcode) -----+
                                     Kometa (metadata) ------> Plex
                                     Recyclarr (quality) ----> Radarr/Sonarr
```

All download traffic routes through ProtonVPN (with optional NordVPN failover). Everything else uses your normal connection. All services auto-start on boot and self-heal if they go down.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup.sh` | Creates folders, generates .env, copies config templates |
| `scripts/configure.sh` | Auto-configures all service connections via API |
| `scripts/health-check.sh` | Full stack health diagnostic |
| `scripts/install-launchd-jobs.sh` | Installs all automation as background jobs |
| `scripts/install-vpn-failover.sh` | Installs VPN failover (requires NordVPN backup) |
| `scripts/auto-heal.sh` | Hourly self-healer |
| `scripts/backup.sh` | Config and database backup |
| `scripts/download-watchdog.py` | Stalled torrent detection and auto-fix |
| `scripts/vpn-mode.sh` | Manual VPN provider switcher |
| `scripts/vpn-failover-watch.sh` | Automatic VPN failover daemon |
| `scripts/run-kometa.sh` | Trigger Kometa metadata run |

## Config Templates

Pre-configured templates in `configs/` (copy to your Media folder after first boot):

- **recyclarr.yml** - TRaSH Guides quality profiles for Radarr and Sonarr
- **kometa.yml** - Plex metadata automation (franchise collections, resolution overlays)

Both require API keys that are generated on first boot. The configure script will print them for you.
