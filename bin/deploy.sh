#!/usr/bin/env bash

# example:
#
#   bin/deploy.sh nft "https://turf.mob.land/metadata/"
#

TOKEN_URI=$3 npx hardhat run scripts/deploy-$1.js --network $2
