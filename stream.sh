#!/bin/bash -ex

# Chrome should be run as:
# /c/Program\ Files\ \(x86\)/Google/Chrome/Application/chrome.exe --kiosk --user-data-dir=chrome-user-data --no-first-run http://localhost:9966

FPS="30"
QUAL="fast"
YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2"
WINDOW_TITLE='budo - Google Chrome'
FFMPEG="$HOME/Desktop/ffmpeg-3.3.1-win64-static/bin/ffmpeg"

"$FFMPEG" \
    -f gdigrab -framerate "$FPS" \
    -offset_x 0 -offset_y 0 -video_size 1280x720 \
    -i title="$WINDOW_TITLE" \
    -vcodec libx264 -pix_fmt yuv420p -preset fast -crf 20 -r $FPS -b:v 2500k \
    -acodec libmp3lame -ar 44100 -b:a 712000 \
    -f flv \
    "$YOUTUBE_URL/$KEY"

    # -bufsize 512k \
    # -threads 6 \
