#!/usr/bin/env bash
# Copyright 2020 Z Lab Corporation. All rights reserved.
#
# For the full copyright and license information, please view the LICENSE
# file that was distributed with this source code.

set -eu
export LC_ALL=C

echo "export PS1='\[\e[01;31m\]@master\[\e[00m\]:\$ '" >> ~vagrant/.bashrc
