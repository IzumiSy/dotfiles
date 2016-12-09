#!/bin/bash

set -e

git clone https://github.com/rbenv/rbenv.git "$HOME/.rbenv"
git clone https://github.com/rbenv/ruby-build.git "$HOME/.rbenv/plugins/ruby-build"

# TODO: Add modification script here to load rbenv.

