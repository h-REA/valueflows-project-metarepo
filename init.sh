#!/usr/bin/env bash
#
# Initialisation script for setting up an integrated
# development environment for ValueFlows projects.
#
# If you are only contributing to one of the projects listed
# in .gitmodules, there is no need to use this repo. The setup
# here is to automate workflows where multiple core components
# are being developed in tandem, and changes need to be easily
# synchronised locally between each codebase.
#

HAS_NIX=$(command -v nix-shell >/dev/null 2>&1)
HAS_NIX=$?

bold=$(tput bold)
normal=$(tput sgr0)

function status_line() {
  echo ""
  echo "${bold}$1${normal}"
  echo ""
}

if [[ ! $HAS_NIX ]]; then
  status_line "Nix is not installed- see https://nixos.org/nix/download.html"
  exit 1
fi

status_line "Configuring NPM to handle Nix env mismatches properly..."

npm config set scripts-prepend-node-path true

status_line "Registering modules..."

# Create submodules if not already present
git submodule init
git submodule update

# All packages need to be put on master branch, as metadata in this repo is probably outdated.
pushd ecosystem-wiki
  git checkout master
popd

# Configure HoloREA first, all commands will be run within its Nix environment
pushd holo-rea
  git checkout master

  status_line "Setup HoloREA packages..."

  # wiring between vf-graphql-holochain and holo-rea/examples is handled by
  # yarn within holo-rea codebase

  nix-shell --run 'yarn'
popd

# build & register locally developed NPM modules

status_line "Setup vf-graphql..."
pushd vf-graphql
  git checkout master
  nix-shell --run 'yarn' ../holo-rea/default.nix
  nix-shell --run 'npm run build' ../holo-rea/default.nix
  pushd lib
    nix-shell --run 'NPM=$(which npm); sudo $NPM link' ../../holo-rea/default.nix
  popd
popd

status_line "Setup vf-ui..."
pushd vf-ui
  git checkout master
  nix-shell --run 'NPM=$(which npm); sudo $NPM link' ../holo-rea/default.nix
popd

# wire local NPM modules into dependants

status_line "Setup vf-graphql-holochain..."
pushd holo-rea/modules/vf-graphql-holochain
  nix-shell --run 'npm link @valueflows/vf-graphql' ../../default.nix
popd
