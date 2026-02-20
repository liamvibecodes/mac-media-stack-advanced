<div align="center">
  <br>
  <a href="#one-command-install">
    <img src="https://img.shields.io/badge/MAC_MEDIA_STACK-00C853?style=for-the-badge&logo=apple&logoColor=white" alt="Mac Media Stack" height="40" />
  </a>
  <br>
  <img src="https://img.shields.io/badge/ADVANCED-FFD700?style=flat-square&labelColor=333" alt="Advanced" />
  <br><br>
  <strong>Fully automated, self-healing media server for macOS</strong>
  <br>
  <sub>Everything from the <a href="https://github.com/liamvibecodes/mac-media-stack">basic stack</a>, plus transcoding, quality profiles, metadata automation, download watchdog, VPN failover, and automated backups.</sub>
  <br><br>
  <img src="https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white" />
  <img src="https://img.shields.io/badge/Plex-EBAF00?style=flat-square&logo=plex&logoColor=white" />
  <img src="https://img.shields.io/badge/Sonarr-00CCFF?style=flat-square&logo=sonarr&logoColor=white" />
  <img src="https://img.shields.io/badge/Radarr-FFC230?style=flat-square&logo=radarr&logoColor=black" />
  <img src="https://img.shields.io/badge/Tdarr-5C2D91?style=flat-square&logoColor=white" />
  <img src="https://img.shields.io/badge/Recyclarr-FF6B35?style=flat-square&logoColor=white" />
  <img src="https://img.shields.io/badge/Kometa-FF4081?style=flat-square&logoColor=white" />
  <img src="https://img.shields.io/badge/macOS-000000?style=flat-square&logo=apple&logoColor=white" />
  <br><br>
  <img src="https://img.shields.io/github/stars/liamvibecodes/mac-media-stack-advanced?style=flat-square&color=yellow" />
  <img src="https://img.shields.io/github/license/liamvibecodes/mac-media-stack-advanced?style=flat-square" />
  <br><br>
</div>

## Why This Version?

The [basic stack](https://github.com/liamvibecodes/mac-media-stack) gets you up and running. This version is for people who want it to run itself: automatic transcoding to save disk space, quality profiles that filter out bad releases, metadata that keeps Plex looking clean, a watchdog that fixes stalled downloads, and VPN failover so your tunnel never stays down. All of it runs on macOS with launchd, not systemd. Built for Macs, not adapted from Linux.

---

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

<details>
<summary>See it in action</summary>
<br>
<img src="demo.gif" alt="Mac Media Stack install demo" width="700" />
</details>

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

## What It Looks Like

<img src="ui-flow.gif" alt="Request to streaming UI flow" width="700" />

## How It Works

<img src="flow.gif" alt="Request to streaming flow" width="700" />

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

## License

[MIT](LICENSE)
