#!/bin/bash
# -*-mode:bash-*- vim:ft=shell-script

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

curl_install() {
    url=$1
    echo "Curl install:"
    echo $url
    /bin/bash -c "$(curl -fsSL ${url})"
}

curl_dpkg() {
    url=$1
    echo "Curl install:"
    echo $url
    if uname | grep -Eq '^(cygwin|mingw|msys)'; then
        uuid=$(powershell -NoProfile -Command "[guid]::NewGuid().ToString()")
    else
        uuid=$(uuidgen)
    fi
    TMPFILE=$(mktemp /tmp/dotfiles."${uuid}".XXXXX.tar.gz) || {
            error "tempfile error"
    }
    curl -s -L -o "$TMPFILE" "$url" || {
            error "curl error: ${url}"
    }
    sudo dpkg -i "$TMPFILE" || {
        rm -f "$TMPFILE"
        error "dpkg error"
    }
    rm -f "$TMPFILE"
}

setup_dependencies() {
    printf -- "\n%sSetting up dependencies:%s\n\n" "$BOLD" "$RESET"

    # Install Homebrew if it's missing
    command_exists brew || {
        curl_install "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    }
    command_exists brew || {
        error "Brew failed to install."
    }
    command_exists chezmoi || {
        brew install chezmoi
    }
    command_exists chezmoi || {
        error "chezmoi install failed"
    }
}

setup_main() {
    # Initialize or update chezmoi
    printf -- "%sInitializing/updating dotfiles with chezmoi...%s\n" "$CYAN" "$RESET"
    if [ -d ~/.local/share/chezmoi/.git ]; then
        chezmoi apply
    else
        chezmoi init Icehawk78 --apply
    fi

    # Install Homebrew packages
    printf -- "%sInstalling/updating apps using Homebrew...%s\n" "$CYAN" "$RESET"
    brew bundle --global
}

setup_prompts() {
    printf -- "\n%sSetting up zsh and related tools:%s\n\n" "$BOLD" "$RESET"

    # Install Zsh/Oh-My-Zsh if it's missing, and set it as the default shell
    command_exists zsh || {
	printf -- "%sInstalling zsh...%s\n" "$PURPLE" "$RESET"
	brew install zsh
    }
    if command_exists zsh; then
        [ -d ~/.oh-my-zsh ] || {
            printf -- "%sInstalling Oh-My-Zsh\n%s" "$PURPLE" "$RESET"
                    curl_install "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
        }
        [ -d ~/.oh-my-zsh ] || {
            error "Oh-My-Zsh failed to install."
        }
    else
        error "zsh failed to install."
    fi
}

# shellcheck source=/dev/null
setup_devtools() {
    printf -- "\n%sSetting up development tools:%s\n\n" "$BOLD" "$RESET"

    command_exists git || {
	    error "git is not installed"
    }

    command_exists git-credential-manager-core || {
        if command_exists dpkg; then
            url=`curl -sH "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/gitcredentialmanager/git-credential-manager/releases/latest" | grep "url" | grep ".deb" | sed -E 's/^.+?": "(.+?)".+?$/\1/g'`
            curl_dpkg $url
            git-credential-manager-core configure

            git config --global credential.credentialStore gpg
        else
            error "Git Credential Manager Core failed to install"
        fi
    }

    command_exists asdf || {
        error "asdf is not installed"
    }

    printf -- "%sInstalling/updating ASDF plugins...%s\n" "$CYAN" "$RESET"
    asdf plugin add nodejs || true
    asdf plugin add yarn || true
    asdf plugin add python || true
    asdf plugin add ruby || true
    asdf plugin add crystal || true
    asdf plugin update --all

    # printf -- "%sImporting PGP keyrings for ASDF plugins...%s\n" "$CYAN" "$RESET"
    # "$HOME"/.asdf/plugins/nodejs/bin/import-release-team-keyring

    asdf install nodejs latest || true
    asdf install yarn latest || true
    asdf install ruby latest || true
    asdf install python latest || true
    asdf install crystal latest || true
    asdf global nodejs latest
    asdf global ruby latest
    asdf global python latest
    asdf global crystal latest

    # Install/Update ultimate vimrc
    [ -d ~/.vim_runtime ] || {
        git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime
        sh ~/.vim_runtime/install_awesome_vimrc.sh
    }
    if [ -d ~/.vim_runtime ] && command_exists python; then
        cd ~/.vim_runtime
        git reset --hard
        git clean -d --force
        git pull --rebase
        python update_plugins.py
    fi
}

main() {
    setup_color

    printf -- "\n%sNew environment setup script:%s\n" "$BOLD" "$RESET"

    setup_dependencies
    setup_prompts
    setup_main
    setup_devtools

    printf -- "\n%sDone.%s\n\n" "$GREEN" "$RESET"

#    [ -s "$HOME/.zshrc" ] && \. "$HOME/.zshrc"
}

main "$@"
