#!/bin/bash
set -euo pipefail

die() {
  printf 'torch installer: %s\n' "$*" >&2
  exit 1
}

[[ $(uname -s) == Darwin ]] || die 'This installer requires macOS.'
for tool in /usr/bin/expect /usr/bin/ssh /usr/bin/osascript; do
  [[ -x $tool ]] || die "Missing required tool: $tool"
done
[[ -d '/Applications/Google Chrome.app' || -d "$HOME/Applications/Google Chrome.app" ]] || die 'Install Google Chrome before running this installer.'

source_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
install_dir=${TORCH_INSTALL_DIR:-"$HOME/.local/share/torch-login"}
bin_dir=${TORCH_BIN_DIR:-"$HOME/.local/bin"}
zshrc=${TORCH_ZSHRC:-"$HOME/.zshrc"}
config_path="$install_dir/config.local.tcl"
torch_command="$bin_dir/torch"

[[ -f "$source_dir/torch" && -f "$source_dir/torch-login.exp" && -f "$source_dir/torch-fill.applescript" ]] || die 'Run this script from a complete repository checkout.'

umask 077
mkdir -p "$install_dir" "$bin_dir"

if [[ ! -f $config_path ]]; then
  if [[ -f "$source_dir/config.local.tcl" ]]; then
    cp "$source_dir/config.local.tcl" "$config_path"
  else
    printf 'Cluster SSH username: '
    IFS= read -r ssh_user || die 'No username supplied.'
    printf 'Cluster SSH hostname: '
    IFS= read -r ssh_host || die 'No hostname supplied.'
    printf 'Microsoft account email: '
    IFS= read -r account_email || die 'No email supplied.'

    user_pattern='^[A-Za-z0-9_.-]+$'
    host_pattern='^[A-Za-z0-9.-]+$'
    email_pattern='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$'
    [[ $ssh_user =~ $user_pattern ]] || die 'Invalid SSH username.'
    [[ $ssh_host =~ $host_pattern ]] || die 'Invalid SSH hostname.'
    [[ $account_email =~ $email_pattern ]] || die 'Invalid Microsoft account email.'

    printf 'set torch_ssh_user {%s}\nset torch_ssh_host {%s}\nset torch_account_email {%s}\n' \
      "$ssh_user" "$ssh_host" "$account_email" > "$config_path"
  fi
fi
chmod 600 "$config_path"

cp "$source_dir/torch" "$source_dir/torch-login.exp" "$source_dir/torch-fill.applescript" "$install_dir/"
chmod 755 "$install_dir/torch" "$install_dir/torch-login.exp"
chmod 644 "$install_dir/torch-fill.applescript"

if [[ -e $torch_command || -L $torch_command ]]; then
  [[ -L $torch_command && $(readlink "$torch_command") == "$install_dir/torch" ]] || \
    die "$torch_command already exists and belongs to another installation."
else
  ln -s "$install_dir/torch" "$torch_command"
fi

marker='# >>> torch-login installer >>>'
touch "$zshrc"
if ! grep -Fq "$marker" "$zshrc"; then
  printf -v quoted_bin '%q' "$bin_dir"
  {
    printf '\n%s\n' "$marker"
    printf 'export PATH=%s:$PATH\n' "$quoted_bin"
    printf '# <<< torch-login installer <<<\n'
  } >> "$zshrc"
fi

printf '\nInstalled torch at %s\n' "$torch_command"
printf 'Account settings are in %s (local only).\n' "$config_path"
printf 'Open a new Terminal window, then run: torch\n'
