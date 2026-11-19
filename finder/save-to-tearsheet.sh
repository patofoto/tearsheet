#!/bin/zsh
# Finder Quick Action "Save to Tearsheet": sends the selected photos (and the photos inside
# selected folders) to Tearsheet's saver, which puts them in your library like a web save
# (JPEG, camera details kept, location removed). Installed by install.sh, which puts this
# script inside the Quick Action.
#
# Settings: ~/.config/tearsheet/config (asked for on first use)
#   SERVER_URL        the saver's address (the one in the Chrome extension's Settings)
#   API_KEY           the saver's key (the one in the Chrome extension's Settings)
#   SCAN_WEBHOOK_URL  optional: the library scan address (also in the extension's Settings),
#                     called after the photos are sent so they show up in Immich

CONFIG="$HOME/.config/tearsheet/config"
SERVER_URL=""
API_KEY=""
SCAN_WEBHOOK_URL=""
[[ -f $CONFIG ]] && source "$CONFIG"

TITLE="Tearsheet"
MAX_BYTES=$((50 * 1024 * 1024))   # the saver's limit per photo

# Show a message; with "ask", return what was typed (empty if cancelled)
dialog() {
  osascript - "$@" <<'EOF' 2>/dev/null
on run argv
  set msg to item 1 of argv
  if (count of argv) > 1 then
    set mode to item 2 of argv
    if mode is "secret" then
      return text returned of (display dialog msg default answer "" with hidden answer with title "Tearsheet")
    else
      return text returned of (display dialog msg default answer "" with title "Tearsheet")
    end if
  end if
  display dialog msg buttons {"OK"} default button "OK" with title "Tearsheet"
end run
EOF
}

notify() {
  osascript -e 'on run argv' -e 'display notification (item 1 of argv) with title "Tearsheet"' -e 'end run' "$1" >/dev/null 2>&1
}

save_config() {
  mkdir -p "${CONFIG:h}"
  {
    print -r -- "SERVER_URL=${(q)SERVER_URL}"
    print -r -- "API_KEY=${(q)API_KEY}"
    print -r -- "SCAN_WEBHOOK_URL=${(q)SCAN_WEBHOOK_URL}"
  } > "$CONFIG"
  chmod 600 "$CONFIG"
}

urlencode() {
  print -rn -- "$1" | /usr/bin/perl -pe 's/([^A-Za-z0-9._~-])/sprintf("%%%02X", ord($1))/ge'
}

# First use: ask for the saver's address and key (and the optional scan address)
if [[ -z $SERVER_URL ]]; then
  SERVER_URL=$(dialog "The address of Tearsheet's saver (the same one as in the Chrome extension's Settings):" text)
  SERVER_URL=${SERVER_URL%/}
  [[ -z $SERVER_URL ]] && exit 0
  save_config
fi
if [[ -z $API_KEY ]]; then
  API_KEY=$(dialog "Paste the saver's API key (the same one as in the Chrome extension's Settings):" secret)
  [[ -z $API_KEY ]] && exit 0
  SCAN_WEBHOOK_URL=$(dialog "Optional: the library scan address (the same one as in the Chrome extension's Settings), so new photos show up in Immich right away. Leave empty to skip." text)
  save_config
fi

# The photos: selected files, plus image files inside selected folders
setopt extendedglob nullglob nocaseglob
IMAGE_EXTS='(jpg|jpeg|png|webp|avif|tif|tiff|heic|heif|bmp|jxl|dng|cr2|cr3|nef|arw|raf|orf|rw2)'
files=()
for arg in "$@"; do
  if [[ -d $arg ]]; then
    files+=("$arg"/**/*.${~IMAGE_EXTS}(.N))
  elif [[ -f $arg ]]; then
    files+=("$arg")
  fi
done
(( ${#files} )) || { dialog "No photos in the selection."; exit 0; }

tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT

sent=0
failed=()
for f in "${files[@]}"; do
  name=${f:t}
  ext=${${f:e}:l}
  send=$f
  # The saver can't read HEIC or camera raw files: turn them into JPEG here first (sips keeps
  # the camera details; the saver removes the location). Very large files too.
  size=$(stat -f %z "$f")
  if [[ $ext == (heic|heif|dng|cr2|cr3|nef|arw|raf|orf|rw2|bmp) ]] || (( size > MAX_BYTES )); then
    send="$tmp/${name:r}.jpg"
    if ! /usr/bin/sips -s format jpeg -s formatOptions 92 "$f" --out "$send" >/dev/null 2>&1; then
      failed+=("$name: couldn't convert it to JPEG")
      continue
    fi
    (( $(stat -f %z "$send") > MAX_BYTES )) && { failed+=("$name: too large (over 50 MB)"); continue; }
  fi

  code=$(/usr/bin/curl -sS -o "$tmp/reply" -w '%{http_code}' --max-time 300 \
    -X POST "$SERVER_URL/upload-bytes" \
    -H "X-API-Key: $API_KEY" \
    -H "X-File-Name: $(urlencode "$name")" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @"$send" 2>"$tmp/curl-error")
  if [[ $code == 200 ]]; then
    (( sent++ ))
  elif [[ $code == 401 ]]; then
    # Wrong key: forget it so the next run asks again
    API_KEY=""
    save_config
    dialog "The saver didn't accept the API key. Run the Quick Action again to enter it. ($sent sent before this.)"
    exit 1
  else
    reason=$(/usr/bin/perl -0ne 'print $1 if /"message"\s*:\s*"((?:[^"\\]|\\.)*)"/' "$tmp/reply" 2>/dev/null)
    [[ -z $reason ]] && reason=$(<"$tmp/curl-error")
    [[ -z $reason ]] && reason="server answered $code"
    failed+=("$name: $reason")
  fi
done

if (( sent )) && [[ -n $SCAN_WEBHOOK_URL ]]; then
  /usr/bin/curl -fsS --max-time 30 "$SCAN_WEBHOOK_URL" >/dev/null 2>&1 || failed+=("(the library scan didn't start; use Scan library in the Chrome extension)")
fi

photos() { (( $1 == 1 )) && print "1 photo" || print "$1 photos"; }
if (( ${#failed} )); then
  dialog "Saved $(photos $sent). Not saved:"$'\n\n'"${(F)failed[1,15]}$( (( ${#failed} > 15 )) && print "\n…and $(( ${#failed} - 15 )) more")"
else
  notify "Sent $(photos $sent) to Tearsheet."
fi
