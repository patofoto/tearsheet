# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Tearsheet** is the name of the whole product: an Immich companion for a library of photographers' work and the models in it. The app serves Immich; the extensions serve the app. It must stay independent of any one install: the user's Immich library is called **Inspiration Board / Inspo Board**, but that name (and the user's addresses) belongs only in settings and deployment files, never in code or built-in defaults.

The parts:

1. **Chrome extension** (`extension/`, "Tearsheet") - right-click a photo → **Save to Tearsheet** (POSTs it to the saver); toolbar popup → collect a whole Tumblr tag, YouPic portfolio or any page (`popup.js`, `collector.js`) through the saver's `/batch` endpoints, and **Scan library** (also on the toolbar icon's right-click menu, `scan-library`): a GET to the library scan address in Settings (`webhookUrl` in chrome.storage; the user points it at an n8n workflow that starts Immich's external library scan). The Webhook Trigger extension was folded in at 1.14. The manifest's `key` fixes the extension ID (`njdhpdampnbbeoieeeebmgglpfghiogl`), so moving the folder keeps its settings
2. **Finder Quick Action** (`finder/`) - "Save to Tearsheet": right-click photos or folders in Finder → `save-to-tearsheet.sh` POSTs each file to `/upload-bytes` with `X-File-Name` (the saved file keeps its name, no "Saved from" line). HEIC, camera raw and files over 50 MB are made JPEG with `sips` first. Settings (`SERVER_URL`, `API_KEY`, optional `SCAN_WEBHOOK_URL`) in `~/.config/tearsheet/config`, asked for on first use; no built-in address. `install.sh` moves the old `~/.config/inspo-board`, removes the old "Save Image to Inspiration Board" Quick Action, copies the workflow bundle to `~/Library/Services` and puts the script inside it; rerun it after editing the script
3. **iPhone Shortcut** ("Inspo Board", not in this repo) - shares a link to the saver's `/upload` (Tumblr posts, image links, and since Nov 19, 2026 Pinterest pins: `pin.it/…` or `/pin/<id>/`, saved at the original upload). (The old Scriptable script was removed.)
4. **Saver** - `tearsheet-saver/` in homelab-config (below)
5. **Tearsheet app** - `tearsheet/` in homelab-config (`immich-cull/` until Nov 19, 2026): the web app (Photos, Explore, Views, Duplicates, Backlog), Python, talks to Immich only through its API. Its own README and version (`app/VERSION`). The VS Code workspace `tearsheet.code-workspace` opens this repo plus both homelab-config folders

**Machines** (both Mac minis): the **Immich server** (M1, `server_m1@10.0.1.26`, ssh alias `immich-server`) runs Immich and the saver, which must sit there because it writes into the library's folder; 8 GB, tight during Immich's ML jobs. The **Docker server** (`pato@10.0.30.20`, Ubuntu, Portainer at :9000) runs the Tearsheet app (stack `tearsheet`, 31 GB). The saver and the app were called image-downloader-m1 and immich-cull until Nov 19, 2026.

## The saver and the app live elsewhere

The saver is **not** in this repo. It is `tearsheet-saver/` in the `patofoto/homelab-config` repo (local clone: `~/Documents/GitHub/homelab-config`). Make saver changes there.

- Runs on the Immich server (`server_m1@10.0.1.26`) as the Portainer stack `tearsheet-saver` (container `tearsheet-saver`, data `~/tearsheet-saver`); public URL `https://inspo-dl.make3.co`.
- The container bind-mounts `server.js` from the Immich server's checkout at `/Users/server_m1/homelab-config/tearsheet-saver/server`, not from Portainer's Git copy. To deploy a saver change: push to homelab-config, `git pull` in `~/homelab-config` on the Immich server (its deploy key is read-only: it can pull, not push), then restart it: `docker restart tearsheet-saver` on the Immich server (Portainer's **Pull and redeploy** leaves the container running when only the code changed, not the compose file).
- Env vars are set in the Portainer stack UI, and the stack's `docker-compose.yml` must list each one or it never reaches the container: `API_KEY`, `TUMBLR_CONSUMER_KEY`, `TUMBLR_CONSUMER_SECRET`, `TUMBLR_OAUTH_TOKEN`, `TUMBLR_OAUTH_TOKEN_SECRET`.
- Tumblr post links are resolved through Tumblr's API v2 with OAuth 1.0a (sees login-only blogs; the token doesn't expire), falling back to scraping the post page. Browser session cookies were abandoned because Tumblr invalidates copied cookies within minutes.
- The Tearsheet app is `tearsheet/` in homelab-config, built by Portainer from git on the Docker server (push, then **Pull and redeploy** the `tearsheet` stack; container `tearsheet`, data `/home/pato/tearsheet`).

## Flow (Chrome extension)

```text
Right-click image → extension/background.js
  → reads serverUrl + apiKey from chrome.storage.local (set on the Settings page)
  → POST {serverUrl}/upload { imageUrl, sourceUrl, apiKey }
  → badge "..." (sending), "✓" (saved), "✗" (error)
```

**On Tumblr pages the same menu item saves the whole post** (there is only one item since 1.5): `page-context.js` (content script) records the right-clicked element; `findPostLinks` collects the post links in its `<article>` (or the nearest element with post links), plus the page itself if it's a permalink, and sends them as `postUrls` with the image. The server saves the photos of the first candidate post that really contains the image, else just the image; the reply's `post` is the matched link or `null`. Badge: `✓` for one image, else the count saved; orange if `post` is `null`. Right-clicking Tumblr's enlarged preview finds no post, so only that image is saved: the user relies on this to pick one image, keep it.

**Other sites (since 1.6):** the extension reads the image bytes itself (`readImage` runs `fetch` in the page with its cookies; else the service worker fetches it) and POSTs them to `/upload-bytes` (headers `X-API-Key`, `X-Image-Url`, `X-Source-Url`, URI-encoded). Sites behind Cloudflare's bot check (e.g. Bellazon) answer the server with a challenge page, never the image. If Chrome can't read the image, or the server answers 404 (older server), it falls back to `/upload` with the address. Images labelled `application/octet-stream` (YouPic) are accepted too; the server sniffs the bytes.

**Instagram (since 1.12):** Instagram lays a clear layer over each photo, so Chrome's image item never shows there; a second item (`download-instagram`, contexts page + link, only on instagram.com) does. `page-context.js` records where the right-click was; `findInstagramPhoto` takes the image under that point (`elementsFromPoint`, else any image under the point; a video, a reel's tile or an avatar-sized image finds nothing, badge `✗`), its largest `srcset` size, else the image as loaded (checked 2026-11-15: no srcset, Instagram serves the photo at 1080 px or larger, up to its full size, e.g. 3112 px), and the post's link (`/p/<code>/` from the grid tile, the feed's `<article>` or the page) as the source. The bytes go to `/upload-bytes` like other sites. Not yet: every photo of a multi-photo post, the iPhone.

**Pinterest (since 1.13):** right-clicks land on the `<img>` itself, so the ordinary image item works. `largerVersions` tries the biggest size first: Pinterest keeps each size in a folder (`i.pinimg.com/236x/`, `474x/`, `736x/`, `originals/`); it asks for `originals/` (checked 2026-11-15: all 12 tried loaded, up to 2500×3750, often far past 736 px), then `736x/`, then what's shown. (YouPic's 1440 px address goes through the same list.) `findPinLink` sends the pin's own page (`/pin/<id>/`, from the tile's link or the page) as the source, not the search or board.

**Sites that block right-click (since 1.7):** `option-rightclick.js` (content script on all sites, `document_start`, all frames) stops a right-click made with ⌥ Option from reaching the page, so Chrome's menu opens (e.g. YouPic cancels every right-click). It also records the clicked element, since `page-context.js` won't see that click. A plain right-click is untouched.

Single saves always save, even an image saved before (the user deletes duplicates in Immich); the server still records each saved image's media key, so tag runs skip it.

The server fetches the image itself, which avoids CORS issues in the browser.

**Saved files keep their metadata (since 2026-10-31):** the server converts every photo to JPEG keeping the photographer's EXIF/IPTC/XMP (camera, lens, date taken, credit, caption) minus the location, and writes `Saved from <page>` (plus `Collected from …` for runs) into the description Immich shows (`server/photo-metadata.js` in homelab-config). Tearsheet's Group by shoot uses the camera details (never the download time).

## Flow (Tumblr tag collector)

```text
Toolbar popup on tumblr.com/tagged/<tag> → injects extension/collector.js into the tab
  → pages through /api/v2/hubs/<tag>/timeline?sort=recent (Tumblr's internal API, logged-in
    session; next page in response.timeline._links.next) → photos only, merged by media key
  → background.js relays to the server: POST /batch → poll GET /batch/:id → preview
  → POST /batch/:id/download → poll until done (runs on the server; the panel can close)
```

- Plan, findings and calibration: `docs/tumblr-tag-collector.md`
- **Tags without a tag page (since 1.11):** Tumblr forwards some tags (e.g. `viktor korneev`, whose `/hubs/` feed answers 404) to `/search/<words>`. There the collector pages through `/api/v2/timeline/search?query=…&mode=recent&timeline_type=post&days=0` instead: same posts format, as deep as the tag feed (Nov 2026, `marta bevacqua`: 1,097 search posts vs 1,050 tag posts, 1,047 in both, both back to 2009), plus posts that only mention the name.
- **Other sources (since 1.8)**, chosen by `collector.js` from the tab's address: a **YouPic profile** (scrolls the portfolio, an inner `DIV.scroll` that recycles its tiles, reading `a.media-image` tiles after every step; each photo's address is `youpic.com/i/<40-hex ID><…><8-hex size>`, size = long side / 4, so it asks for `00000258` and gets YouPic's maximum, 1440 px; `00000087` = 540 px for the re-upload check) and **any page** (scrolls to the end; photos ≥ 500 px, the largest `srcset` entry, or the image file a thumbnail links to). Batches carry `source` (`tumblr` / `youpic` / `page`); the server keys YouPic photos `youpic:<id>`, others `url:<sha1>`. Photos the server can't fetch get **From this tab**: the panel reads them in the page and the background worker posts them to `/batch/:id/items/:index/bytes`.
- **Album:** the preview's album box (Tumblr: the tag; YouPic: the photographer; pages: empty) goes with the download; after the run the server adds the photos to that Immich album once the scan has picked them up, only if the album exists (never creates one).
- Chrome pauses background tabs, so collecting needs the tab in front; pauses use `pause()`, which ends early when the tab becomes visible.
- The server skips images downloaded before (ledger of media keys, existing file names) and re-uploads of the same photo (256-bit difference hash of the ~540 px thumbnail, ≤ 20 bits apart). It talks to Immich only for the album step (`IMMICH_API_KEY`: album.read, albumAsset.create, asset.read).

## Development

**Load the extension:** `chrome://extensions/` → Developer mode → Load unpacked → `extension/`. After editing `background.js` or `options.js`, click the reload icon there.

**Versioning:** bump `version` in `extension/manifest.json` with every change to the extension, so the number shown in `chrome://extensions` tells the user which build is loaded (1.2 = tag collector with download and an already-saved note; 1.3 = single saves always save again, the already-saved check and note removed; 1.4 = Download whole post; 1.5 = one right-click item, which saves the whole post on Tumblr; 1.6 = other sites send the image bytes from the browser; 1.7 = ⌥ Option + right-click on sites that block right-click, images labelled as plain data accepted; 1.8 = collect a YouPic portfolio or any page, album box, From this tab, YouPic right-click saves at 1440 px; 1.9 = two quick saves no longer clear each other's badge, srcset addresses with commas (Cloudinary, Substack) read whole, Collect on another page starts a new run once the old one is done collecting; 1.10 = scroll collector jumps to the top first so recycled tiles above aren't missed, broken srcset URLs skipped; 1.11 = collects Tumblr search pages too, for tags Tumblr forwards to search; 1.12 = right-click saves Instagram photos at their largest size; 1.13 = Pinterest saves the original upload, with the pin as the source; 1.14 = named Tearsheet (Save to Tearsheet), Scan library folded in from the Webhook Trigger extension, the ID fixed in the manifest).

**Test the saver:**

```bash
curl https://inspo-dl.make3.co/health
curl -X POST https://inspo-dl.make3.co/upload \
  -H "Content-Type: application/json" -H "X-API-Key: $API_KEY" \
  -d '{"imageUrl": "https://www.tumblr.com/<blog>/<post-id>"}'
```

`/upload` returns `200 { success, count, filename, filenames }`, `401` for a bad key, or `422 { error, message }` when nothing could be saved.

Extensions use native Chrome APIs only (no dependencies).
