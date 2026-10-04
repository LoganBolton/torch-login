# Torch login

A macOS `torch` command for SSH clusters that use Microsoft device-code sign-in.

The repository is public. Each user's cluster and Microsoft account settings stay on their own Mac.

It starts SSH, enters the fresh device code in a dedicated Chrome window, selects your configured account, confirms the sign-in, closes the window, and continues to the remote shell. It handles up to three device challenges per connection.

## Requirements

- macOS with Google Chrome, SSH, and `/usr/bin/expect`
- A cluster account with Microsoft device-code sign-in
- Your Microsoft account signed in to Chrome
- macOS Automation and Accessibility permission for your terminal app if prompted

## Install

Clone this repository and run the installer:

```sh
git clone https://github.com/LoganBolton/torch-login.git
cd torch-login
./install.sh
```

The installer asks for your cluster SSH username, SSH hostname, and Microsoft account email. It installs `torch` in `~/.local/bin`, adds that directory to your zsh PATH, and keeps your account settings in `~/.local/share/torch-login/config.local.tcl`. Open a new Terminal window, then run `torch`. Running the installer again updates the scripts while preserving your account settings.

If you already have a `config.local.tcl` next to `install.sh`, the installer uses that file instead of asking again.

The script stores no passwords or persistent device codes. It copies each device code to the clipboard during sign-in as a fallback.

## Privacy

The repository includes only placeholder account values. The installer saves your real SSH username, hostname, and Microsoft account email in `~/.local/share/torch-login/config.local.tcl`. A `config.local.tcl` in the checkout is ignored by Git. Keep that file and any login codes out of commits and issue reports.
