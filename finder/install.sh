#!/bin/zsh
# Installs the Finder Quick Action "Save to Tearsheet" (right-click photos or folders →
# Quick Actions). Run again after editing save-to-tearsheet.sh.
set -e
here=${0:A:h}
name="Save to Tearsheet.workflow"
dest="$HOME/Library/Services/$name"
config_dir="$HOME/.config/tearsheet"

# Before it was called Tearsheet: "Save Image to Inspiration Board", settings in ~/.config/inspo-board.
# Move the settings over and take the old Quick Action out of the menu.
old_dir="$HOME/.config/inspo-board"
if [[ -d $old_dir && ! -e $config_dir/config ]]; then
  mkdir -p "$config_dir"
  [[ -f $old_dir/config ]] && mv "$old_dir/config" "$config_dir/config"
  [[ -d $old_dir/previous-quick-action.workflow ]] && mv "$old_dir/previous-quick-action.workflow" "$config_dir/"
  rmdir "$old_dir" 2>/dev/null || true
  echo "Moved the settings from $old_dir to $config_dir"
fi
rm -rf "$HOME/Library/Services/Save Image to Inspiration Board.workflow"

# The saver's address was built in before; settings from then may not have it
if [[ -f $config_dir/config ]] && ! grep -q '^SERVER_URL=..' "$config_dir/config"; then
  print -n "The address of Tearsheet's saver (as in the Chrome extension's Settings): "
  read -r server_url
  if [[ -n $server_url ]]; then
    sed -i '' '/^SERVER_URL=/d' "$config_dir/config"
    print -r -- "SERVER_URL=${(q)${server_url%/}}" >> "$config_dir/config"
  fi
fi

# Keep the previous version once (outside Services, so it doesn't show up twice in the menu)
backup="$config_dir/previous-quick-action.workflow"
if [[ -d $dest && ! -d $backup ]]; then
  mkdir -p "$config_dir"
  cp -R "$dest" "$backup"
fi

rm -rf "$dest"
cp -R "$here/$name" "$dest"
plutil -replace actions.0.action.ActionParameters.COMMAND_STRING \
  -string "$(<"$here/save-to-tearsheet.sh")" "$dest/Contents/document.wflow"
/System/Library/CoreServices/pbs -update
echo "Installed: right-click photos or folders in Finder → Quick Actions → Save to Tearsheet"
