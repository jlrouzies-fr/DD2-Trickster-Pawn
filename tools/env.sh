# Sourced by every tool. Set DD2_DIR to the game folder (the one that holds DD2.exe), e.g.
#   export DD2_DIR="E:/SteamLibrary/steamapps/common/Dragons Dogma 2"
# Optional: DD2_SAVE_DIR (the win64_save folder) and DD2_SAVE_BACKUP (a copy of it): start.sh then puts the backup
# back before every launch, so each test run starts from the same save.
: "${DD2_DIR:?set DD2_DIR to the game folder (the one with DD2.exe)}"
TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$TOOLS")"
WORK="${PT_WORK:-$TOOLS/work}"; mkdir -p "$WORK"
DEV="$DD2_DIR/reframework/data/pt_dev"; mkdir -p "$DEV"
PTLOG="$DD2_DIR/reframework/data/PawnTrickster/log.txt"
# run a console script, once more if the answer was lost (two writers at the same moment lose a command)
L() { local r; r=$(bash "$TOOLS/lua.sh" "$1"); case "$r" in TIMEOUT*) r=$(bash "$TOOLS/lua.sh" "$1");; esac; echo "$r"; }
game_running() { tasklist //FI "IMAGENAME eq DD2.exe" 2>/dev/null | grep -q DD2; }
