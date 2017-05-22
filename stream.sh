#!/bin/bash -ex

# Chrome should be run as:
# /c/Program\ Files\ \(x86\)/Google/Chrome/Application/chrome.exe --kiosk --user-data-dir=chrome-user-data --no-first-run http://localhost:9966

FPS="30"
YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2"
WINDOW_TITLE='budo - Google Chrome'
FFMPEG="$HOME/Desktop/ffmpeg-3.3.1-win64-static/bin/ffmpeg"

# @todo loop audio or get it from desktop
"$FFMPEG" \
    -f gdigrab -framerate "$FPS" -offset_x 0 -offset_y 0 -video_size 1280x720 -draw_mouse 0 \
    -i title="$WINDOW_TITLE" \
    -f concat -safe 0 \
    -i audio-playlist.txt \
    -vsync 1 \
    -g $(($FPS * 2)) \
    -vcodec libx264 -pix_fmt yuv420p -preset ultrafast -crf 18 -r $FPS -maxrate 1984k \
    -acodec libmp3lame -ar 44100 -b:a 712000 \
    -bufsize 3968k \
    -threads 2 \
    -f flv \
    "$YOUTUBE_URL/$KEY"

