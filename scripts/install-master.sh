#!/usr/bin/env bash

set -eu
export LC_ALL=C

echo "export PS1='\[\e[01;31m\]@master\[\e[00m\]:\$ '" >> ~vagrant/.bashrc
