#!/bin/bash
# Builds the release from /opt/portermills/src. Run as the portermills user.
# deps and _build live outside src so each deploy only recompiles what changed.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH" LANG=C.UTF-8
# Java in .tool-versions is for the Android build only.
export MISE_DISABLE_TOOLS=java
export MIX_ENV=prod MIX_DEPS_PATH="$HOME/deps" MIX_BUILD_ROOT="$HOME/build"

cd "$HOME/src"
mise install --yes erlang elixir
cd server
mise exec -- mix local.hex --force --if-missing
mise exec -- mix local.rebar --force --if-missing
mise exec -- mix deps.get --only prod
mise exec -- mix release --overwrite
