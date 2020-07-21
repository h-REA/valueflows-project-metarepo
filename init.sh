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

NPM=$(which npm)

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
#
status_line "Setup Holo-REA..."
pushd holo-rea
  git checkout sprout

  # ensure PNPM is installed in the nix env
  nix-shell --run 'sudo $NPM i -g pnpm'

  # setup dependencies
  nix-shell --run 'pnpm i'
  # build node modules but leave backend unbuilt until end (some devs may be mocking)
  nix-shell --run 'npm run build:graphql-adapter'
popd




# build & register locally developed NPM modules

status_line "Setup vf-graphql..."
pushd vf-graphql
  git checkout sprout
  nix-shell --run 'pnpm i' ../holo-rea/default.nix
  nix-shell --run 'npm run build' ../holo-rea/default.nix
popd

status_line "Setup vf-ui..."
pushd vf-ui
  git checkout sprout
  nix-shell --run 'pnpm i' ../holo-rea/default.nix
popd

status_line "Setup apps..."

pushd app-offers-needs-marketplace/
  git checkout sprout
  nix-shell --run 'pnpm i' ../holo-rea/default.nix
popd

pushd app-personal-agent/
  git checkout sprout
  nix-shell --run 'pnpm i' ../holo-rea/default.nix
popd






status_line "Finished installing. Continuing to build Holo-REA; if you don't need this please CTRL-C..."
pushd holo-rea
  nix-shell --run 'npm run build'
popd
