#!/bin/bash

if ! type go >/dev/null 2>&1; then
  echo "Go not installed. Installing Go..."
  curl -sSf https://raw.githubusercontent.com/owenthereal/goup/master/install.sh | sh -s -- '--skip-prompt'
  goup install 1.21.11
fi

if ! type hugo >/dev/null 2>&1; then
  echo "Hugo not installed. Installing Hugo..."
  go install github.com/gohugoio/hugo@latest
fi

if ! type node >/dev/null 2>&1; then
  echo "Node not installed. Installing Node..."
  curl -fsSL https://fnm.vercel.app/install | bash
  source "$HOME"/.bashrc
  fnm install 16
fi

npm install -g postcss
npm install -g yarn
yarn
