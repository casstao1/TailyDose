#!/bin/zsh
set -euo pipefail

ROOT="/Users/castao/Desktop/PetMed/TailyDose"
FFMPEG_BIN="${FFMPEG_BIN:-$(command -v ffmpeg)}"
FFPROBE_BIN="${FFPROBE_BIN:-$(command -v ffprobe)}"
OUT="${1:-$ROOT/mockups/tailydose-iphone-usage-15s.mp4}"

SPLASH_IMG="$ROOT/mockups/current-home-check.png"
HOME_IMG="$ROOT/mockups/current-home-check-3.png"
MANAGE_IMG="$ROOT/mockups/simulator-screenshots/02-manage-actual.png"
PET_IMG="$ROOT/mockups/simulator-screenshots/04-pet-profile-actual.png"
SHARE_IMG="$ROOT/mockups/simulator-screenshots/05-share-actual.png"

FPS=30
WIDTH=810
HEIGHT=1758
TRANSITION=0.25

SPLASH_DURATION=2.4
HOME_DURATION=4.3
MANAGE_DURATION=3.3
PET_DURATION=3.1
SHARE_DURATION=2.9

OFFSET_1=$(python3 - <<PY
print(f"{float('$SPLASH_DURATION') - float('$TRANSITION'):.3f}")
PY
)
OFFSET_2=$(python3 - <<PY
print(f"{float('$SPLASH_DURATION') + float('$HOME_DURATION') - 2*float('$TRANSITION'):.3f}")
PY
)
OFFSET_3=$(python3 - <<PY
print(f"{float('$SPLASH_DURATION') + float('$HOME_DURATION') + float('$MANAGE_DURATION') - 3*float('$TRANSITION'):.3f}")
PY
)
OFFSET_4=$(python3 - <<PY
print(f"{float('$SPLASH_DURATION') + float('$HOME_DURATION') + float('$MANAGE_DURATION') + float('$PET_DURATION') - 4*float('$TRANSITION'):.3f}")
PY
)

rm -f "$OUT"

"$FFMPEG_BIN" -y \
    -i "$SPLASH_IMG" \
    -i "$HOME_IMG" \
    -i "$MANAGE_IMG" \
    -i "$PET_IMG" \
    -i "$SHARE_IMG" \
    -filter_complex "\
[0:v]zoompan=z='1+0.12*(on/71)':x='(iw-iw/zoom)/2':y='((ih-ih/zoom))*0.15*(on/71)':d=72:s=${WIDTH}x${HEIGHT}:fps=${FPS}[splash]; \
[1:v]zoompan=z='1+0.06*(on/128)':x='(iw-iw/zoom)/2':y='((ih-ih/zoom))*0.55*(on/128)':d=129:s=${WIDTH}x${HEIGHT}:fps=${FPS}[home]; \
[2:v]zoompan=z='1+0.08*(on/98)':x='(iw-iw/zoom)/2':y='((ih-ih/zoom))*0.68*(on/98)':d=99:s=${WIDTH}x${HEIGHT}:fps=${FPS}[manage]; \
[3:v]zoompan=z='1+0.08*(on/92)':x='(iw-iw/zoom)/2':y='((ih-ih/zoom))*0.72*(on/92)':d=93:s=${WIDTH}x${HEIGHT}:fps=${FPS}[pet]; \
[4:v]zoompan=z='1+0.08*(on/86)':x='(iw-iw/zoom)/2':y='((ih-ih/zoom))*0.72*(on/86)':d=87:s=${WIDTH}x${HEIGHT}:fps=${FPS}[share]; \
[splash][home]xfade=transition=fade:duration=${TRANSITION}:offset=${OFFSET_1}[v1]; \
[v1][manage]xfade=transition=slideleft:duration=${TRANSITION}:offset=${OFFSET_2}[v2]; \
[v2][pet]xfade=transition=slideleft:duration=${TRANSITION}:offset=${OFFSET_3}[v3]; \
[v3][share]xfade=transition=slideleft:duration=${TRANSITION}:offset=${OFFSET_4},format=yuv420p[v]" \
    -map "[v]" \
    -an \
    -c:v libx264 \
    -preset veryfast \
    -crf 24 \
    -pix_fmt yuv420p \
    -movflags +faststart \
    "$OUT" >/dev/null 2>&1

"$FFPROBE_BIN" -v error -show_entries format=duration -of default=nw=1:nk=1 "$OUT"
