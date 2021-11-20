#!/bin/sh
# -*-mode:sh-*- vim:ft=shell-script

# ~/dotfiles.sh
# =============================================================================
# Idempotent manual setup script to install or update shell dependencies.

set -e

command_exists() {
    command -v "$@" >/dev/null 2>&1
}

error() {
    printf -- "%sError: $*%s\n" >&2 "$RED" "$RESET"
    exit 1
}

setup_color() {
    # Only use colors if connected to a terminal
    if [ -t 1 ]; then
        RED=$(printf '\033[31m')
        GREEN=$(printf '\033[32m')
        YELLOW=$(printf '\033[33m')
        BLUE=$(printf '\033[34m')
	PURPLE=$(printf '\033[35m')
	CYAN=$(printf '\033[36m')
        BOLD=$(printf '\033[1m')
        RESET=$(printf '\033[m')
    else
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
	PURPLE=""
	CYAN=""
        BOLD=""
        RESET=""
    fi
}

import_repo() {
    repo=$2
    destination=$3
    if uname | grep -Eq '^(cygwin|mingw|msys)'; then
        uuid=$(powershell -NoProfile -Command "[guid]::NewGuid().ToString()")
    else
        uuid=$(uuidgen)
    fi
    TMPFILE=$(mktemp /tmp/dotfiles."${uuid}".tar.gz) || exit 1
    curl -s -L -o "$TMPFILE" "$repo" || exit 1
    chezmoi import --strip-components 1 --destination "$destination" "$TMPFILE" || exit 1
    rm -f "$TMPFILE"
}

pretty_import() {
    PACKAGE_NAME=$1
    PACKAGE_TYPE=$2
    REPO=$3
    DESTINATION=$4
    printf -- "%sInstalling/updating %s: %s...%s\n" "$CYAN" "$PACKAGE_TYPE" "$PACKAGE_NAME" "$RESET"
    import_repo "$REPO" "$DESTINATION" || { error "Import of ${PACKAGE_NAME} failed" }
}

curl_install() {
    url=$1
    /bin/bash -c "$(curl -fsSL ${url})"
}

setup_dependencies() {
    printf -- "\n%sSetting up dependencies:%s\n\n" "$BOLD" "$RESET"

    # Install Homebrew if it's missing
    command_exists brew || { curl_install "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" }
    command_exists brew || { error "Brew failed to install." }
    command_exists chezmoi || { brew install chezmoi }
    command_exists chezmoi || { error "chezmoi install failed" }
}

setup_main() {
    # Install chezmoi if it's missing
    printf -- "%sInitializing/updating dotfiles with chezmoi...%s\n" "$CYAN" "$RESET"
    chezmoi init Icehawk78 --apply

    # Install Homebrew packages
    printf -- "%sInstalling/updating apps using Homebrew...%s\n" "$CYAN" "$RESET"
    brew bundle --global
}

setup_prompts() {
    printf -- "\n%Setting up zsh and related tools:%S\n\n" "$BOLD" "$RESET"
    
    # Install Zsh/Oh-My-Zsh if it's missing, and set it as the default shell
    command_exists zsh || { brew install zsh }
    if [ command_exists zsh ]; then
        command_exists omz || { curl_install "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh" }
        command_exists omz || { "Oh-My-Zsh failed to install."; exit 1 }
    else
        error "zsh failed to install."
        exit 1
    fi

    # Install Oh-My-Zsh plugins
    DESCRIPTION="Zsh plugin"
    DESTINATION="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}/plugins"
    declare -A PLUGINS
    PLUGINS["zsh-autosuggestions"]="https://github.com/robbyrussell/oh-my-zsh/archive/master.tar.gz"
    PLUGINS["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting/archive/master.tar.gz"

    for key in "${!PLUGINS[@]}"; do
	pretty_import "$key" "$DESCRIPTION" "${PLUGINS[$key]}" "$DESTINATION/$key"
    done

    pretty_import "External rc" "Ultimate vimrc" "https://github.com/amix/vimrc/archive/master.tar.gz" "${HOME}/.vim_runtime"
}

# shellcheck source=/dev/null
setup_devtools() {
    printf -- "\n%sSetting up development tools:%s\n\n" "$BOLD" "$RESET"

    command_exists git || { error "git is not installed" }
    command_exists git-credential-manager-core || {
	if [ command_exists dpkg ]; then
	    latest_gcm_deb=curl -s  -H "Accept: application/vnd.github.v3+json"   https://api.github.com/repos/gitcredentialmanager/git-credential-manager/releases/latest | grep 'url' | grep '.deb' | sed -E 's/^.+?": "(.+?)".+?$/\1/g'
            curl_install $latest_gcm_deb
	else
	    error "Git Credential Manager Core failed to install"
	fi
    }
    command_exists asdf || { error "asdf is not installed" }

    printf -- "%sInstalling/updating ASDF plugins...%s\n" "$CYAN" "$RESET"
    asdf plugin add nodejs
    asdf plugin add python
    asdf plugin add ruby
    asdf plugin update --all

    printf -- "%sImporting PGP keyrings for ASDF plugins...%s\n" "$CYAN" "$RESET"
    "$HOME"/.asdf/plugins/nodejs/bin/import-release-team-keyring

    asdf install nodejs latest
    asdf install ruby latest
    asdf install python latest
    asdf global nodejs latest
    asdf global ruby latest
    asdf global python latest
}

setup_dotfiles() {
    printf -- "\n%sSetting up dotfiles:%s\n\n" "$BOLD" "$RESET"

    printf -- "%sUpdating dotfiles at destination...%s\n" "$CYAN" "$RESET"
    chezmoi init Icehawk78 --apply

}

main() {
    setup_color

    printf -- "\n%sNew environment setup script:%s\n" "$BOLD" "$RESET"

    setup_dependencies
    setup_prompts
    setup_main
    setup_devtools

    printf -- "\n%sDone.%s\n\n" "$GREEN" "$RESET"

    [ -s "$HOME/.zshrc" ] && \. "$HOME/.zshrc"
}

main "$@"
