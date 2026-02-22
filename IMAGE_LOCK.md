# Image Lock Matrix

This stack is pinned to exact image digests in `docker-compose.yml` for reproducible installs.

Tested lock snapshot:
- Date: `2026-02-22`
- Docker Engine: `29.2.1`
- Platform: `aarch64` (Docker Desktop on macOS)

| Service | Locked Image |
|---|---|
| gluetun | `qmcgaw/gluetun@sha256:495cdc65ace4c110cf4de3d1f5f90e8a1dd2eb0f8b67151d1ad6101b2a02a476` |
| qbittorrent | `lscr.io/linuxserver/qbittorrent@sha256:85eb27d2d09cd4cb748036a4c7f261321da516b6f88229176cf05a92ccd26815` |
| prowlarr | `lscr.io/linuxserver/prowlarr@sha256:e74a1e093dcc223d671d4b7061e2b4946f1989a4d3059654ff4e623b731c9134` |
| sonarr | `lscr.io/linuxserver/sonarr@sha256:37be832b78548e3f55f69c45b50e3b14d18df1b6def2a4994258217e67efb1a1` |
| radarr | `lscr.io/linuxserver/radarr@sha256:6d3e68474ea146f995af98d3fb2cb1a14e2e4457ddaf035aa5426889e2f9249c` |
| bazarr | `lscr.io/linuxserver/bazarr@sha256:1cf40186b1bc35bec87f4e4892d5d8c06086da331010be03e3459a86869c5e74` |
| flaresolverr | `ghcr.io/flaresolverr/flaresolverr@sha256:7962759d99d7e125e108e0f5e7f3cdbcd36161776d058d1d9b7153b92ef1af9e` |
| seerr | `ghcr.io/seerr-team/seerr@sha256:1b5fc1ea825631d9d165364472663b817a4c58ef6aa1013f58d82c1570d7c866` |
| tdarr | `ghcr.io/haveagitgat/tdarr@sha256:20a5656c4af4854e1877046294f77113f949d27e35940a9a65f231423d063207` |
| unpackerr | `ghcr.io/unpackerr/unpackerr@sha256:dc72256942ce50d1c8a1aeb5aa85b6ae2680a36eefd2182129d8d210fce78044` |
| kometa | `kometateam/kometa@sha256:46fc4bdd6f64dbd92655c6495d9f9d1a745845bd60fa13a7283755db48de8bc0` |
| recyclarr | `ghcr.io/recyclarr/recyclarr@sha256:30e13877e8ef2242b053b986e69e64801797b39ae4f74b744d8f4dc3f98757ab` |
| lidarr (music profile) | `lscr.io/linuxserver/lidarr@sha256:37a3df74f4c2a6f10eead66f4d8034362ebf2866f935026b4a71dd888b9e7f08` |
| tidarr (music profile) | `cstaelen/tidarr@sha256:79a2c62aed04dbe9770272443192eae145f26bdc2d188e665b13ab763341206c` |
| watchtower (optional) | `containrrr/watchtower@sha256:6dd50763bbd632a83cb154d5451700530d1e44200b268a4e9488fefdfcf2b038` |

## Updating The Lock

1. Pull new candidates:
```bash
docker compose --profile autoupdate --profile music pull
```
2. Smoke test stack behavior (core services, then optional profiles).
3. Update digests in `docker-compose.yml`.
4. Update this matrix in `IMAGE_LOCK.md`.
