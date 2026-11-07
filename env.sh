# Shared settings for every script, sourced by them. Values come from the environment or from local.env
# next to this file, which stays out of git. local.env.example shows what goes in it.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/local.env" ] && . "$HERE/local.env"
: "${TV:?set TV=<tv-ip>:5555 in local.env or in the environment}"
T="$TV"
