# Tearsheet

**Tearsheet** is a companion to [Immich](https://immich.app) for a library of photographers' work and the models in it. Save photos from the web (or your Mac) into the library, then name the models, sort the photographers into albums, explore and cull in the Tearsheet app. It works with any Immich library; this install's is the **Inspo Board**.

The parts:

| Part | Where | What it does |
| --- | --- | --- |
| **Chrome extension** | `extension/` (this repo) | Right-click a photo → **Save to Tearsheet**; collect a whole Tumblr tag, YouPic portfolio or page; **Scan library** |
| **Finder action** | `finder/` (this repo) | Right-click photos or folders on the Mac → **Save to Tearsheet** |
| **iPhone Shortcut** | "Inspo Board" in the share sheet (not in this repo) | Share a link → it's saved |
| **Saver** | [`homelab-config/image-downloader-m1`](https://github.com/patofoto/homelab-config/tree/main/image-downloader-m1) | Receives the photos and saves them into the library's folder (an Immich external library) |
| **Tearsheet app** | [`homelab-config/tearsheet`](https://github.com/patofoto/homelab-config/tree/main/tearsheet) | The web app: name, albums, Explore, Duplicates. Talks to Immich only through its API |

Here the saver runs on the **Immich server** (the M1 Mac mini, 10.0.1.26), because it writes into the Inspo Board's folder there, at `https://inspo-dl.make3.co`. The app runs on the **Docker server** (10.0.30.20), because the Immich server's memory is tight while Immich's own jobs run, at `https://tearsheet.make3.co`. Open `tearsheet.code-workspace` in VS Code to get all three folders.

## Setup

### Chrome extension

1. Open `chrome://extensions/`, turn on **Developer mode**, click **Load unpacked**, pick `extension/`.
2. Open the extension's **Settings**: the saver's address (here `https://inspo-dl.make3.co`), the API key (the saver's `API_KEY`), and optionally the **library scan address** (here the n8n workflow that starts Immich's library scan).

The extension's ID is fixed in its manifest (`key`), so it keeps its settings if the folder moves.

### Downloading a whole Tumblr post

On Tumblr, right-click → **Save to Tearsheet** saves every photo in the post the image belongs to, like sharing the post from the phone; on any other site it saves just the image. It works on the dashboard, tag and search pages and on a post's own page. The badge shows `✓` for one image, the number saved for a post with several, in orange when the post couldn't be found, in which case only the clicked image was saved. (Tabs opened before the extension was loaded or reloaded may need a refresh first.) Right-clicking the enlarged preview saves just that image, a way to pick one image from a post.

On Instagram, right-click a photo (in the feed, a profile's grid or a post) → **Save to Tearsheet** saves it at the size Instagram serves (1080 px or more, sometimes the full size), with the post's link as where it came from. A video, a reel, or a right-click off a photo shows a red `✗`. For a post with several photos it saves the one on screen.

On Pinterest, right-click a pin's photo → **Save to Tearsheet** saves the original upload (often far bigger than what Pinterest shows; if it can't be had, the 736 px copy), with the pin's page as where it came from.

Sites that block right-clicking (YouPic, for one): hold **⌥ Option** while right-clicking and Chrome's menu, with **Save to Tearsheet**, opens anyway.

On other sites the extension sends the image as Chrome already has it, so sites that block downloads by anything but a browser (for example forums behind Cloudflare's bot check, like Bellazon) work too.

### Collecting a Tumblr tag

1. Click the extension's toolbar button. On a Tumblr tag page (`tumblr.com/tagged/…`) choose **Collect this tag**; anywhere else, type a name (e.g. *Marta Bevacqua*) and open its tag page first. The tag is used exactly as typed; spaces are part of it.
2. Keep the tab in front while it collects (about a minute per 1,000 posts). It reads the tag's Latest view with your login, so mature posts are included, and leaves out ads, GIFs, text posts and reblogs of the same upload.
3. The saver checks the list and the panel shows a preview: photos found, downloaded before, re-uploads (the same photo posted by several blogs; the biggest copy is kept), new to download. Nothing has been downloaded yet.
4. **Download** saves the new ones through the saver, one at a time. The panel shows progress; **Stop** pauses (continue later), **Hide** closes the panel while the saver carries on. The album box (pre-filled with the tag) puts the photos into that Immich album once Immich has scanned them, only if an album by that name exists already.
5. **Scan library** (in the toolbar panel, or right-click the toolbar icon) so Immich picks up the new photos, then cull them in Tearsheet's Duplicates tab.
6. Give the new photos their model's name or photographer's album in bulk on the Tearsheet app's Photos tab (https://tearsheet.make3.co, or http://10.0.30.20:8102 at home; sign in with your Immich account). Its **Explore** tab (`/explore`) finds a model's photos by a photographer, smart-searches inside them, and shows the photos that look like one (the rest of a shoot); **Group by shoot** sorts a model's or photographer's photos into shoots.

### Collecting a YouPic portfolio, or any page

The toolbar button also collects:

- **A YouPic profile** (`youpic.com/<name>`): **Collect this portfolio** scrolls through the whole portfolio and takes every photo at the largest size YouPic serves (1440 px; the grid shows 768). The album box is pre-filled with the photographer's name.
- **Any other page**: **Collect the photos on this page** scrolls to the end (pages that load more as you scroll) and takes every photo at least 500 px, or the full-size image a thumbnail links to. **Use what's found** stops scrolling early.

Keep the tab in front while it scrolls. Then it works like a tag run: preview, **Download** through the saver, rerunning later only fetches what's new. Some sites only send images to a browser (Bellazon, behind Cloudflare); those fail on the saver, and **From this tab** sends them from the open tab instead.

Single right-click saves always save, even an image saved before; duplicates are culled in Tearsheet's Duplicates tab.

Plan and findings: [`docs/tumblr-tag-collector.md`](docs/tumblr-tag-collector.md).

### Photos on your computer (Finder)

Run `zsh finder/install.sh` once. Then select photos, or folders of photos, in Finder → right-click → **Quick Actions** → **Save to Tearsheet**. They go through the saver like a web save: converted to JPEG (HEIC and camera raw files are converted on the Mac first), camera details kept, location removed, file name kept. The first time it asks for the saver's address, its API key and, optionally, the library scan address (all three as in the Chrome extension's Settings); with the scan address set, Immich scans as soon as the photos are sent. Settings live in `~/.config/tearsheet/config` (`install.sh` moves them from the old `~/.config/inspo-board`). A notification says how many were saved; anything not saved is listed in a message. Up to 50 MB per photo (larger ones are made smaller as JPEG first). Rerun `install.sh` after editing `finder/save-to-tearsheet.sh`.

### Scan library

**Scan library** (the toolbar panel, or right-click the toolbar icon) calls the library scan address from the extension's Settings with a GET; the badge shows `✓` or `✗`. It replaced the separate Webhook Trigger extension (1.14).

## Saver API

`POST /upload` with JSON `{ "imageUrl": "...", "sourceUrl": "...", "apiKey": "..." }` (or the key in an `X-API-Key` header).

- `imageUrl` can be a direct image link or a Tumblr post link. For Tumblr posts the saver finds the photos itself, including every photo of a multi-photo post and posts on login-only blogs. GIFs are skipped.
- `200` → `{ "success": true, "count": 1, "filename": "...", "filenames": [...] }`
- `401` → wrong API key
- `422` → `{ "error": "...", "message": "..." }` when nothing could be saved

Tag runs use `POST /batch`, `GET /batch/:id`, `POST /batch/:id/download` and `POST /batch/:id/cancel`; see the saver's README.

`GET /health` → `{ "status": "ok" }`
