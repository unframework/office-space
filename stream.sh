#!/bin/bash -e

# @todo use 96k in the stereo mix device settings so that downsampling here would not be as bad
# Chrome should be run as:
# /c/Program\ Files\ \(x86\)/Google/Chrome/Application/chrome.exe --kiosk --user-data-dir=chrome-user-data --no-first-run http://localhost:9966

RESTART_SLEEP=20
SIZE="854x480"
FPS="30"
YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2"
WINDOW_TITLE='OFFICE-SPACE 3D VIEWPORT - Google Chrome'
AUDIO_TITLE='Stereo Mix (Realtek High Definition Audio)'
FFMPEG="$HOME/Desktop/ffmpeg-3.3.1-win64-static/bin/ffmpeg"

while true; do
    "$FFMPEG" \
        -rtbufsize 10M \
        -f dshow \
        -i "audio=$AUDIO_TITLE" \
        -f gdigrab -framerate "$FPS" -offset_x 0 -offset_y 0 -video_size "$SIZE" -draw_mouse 0 \
        -i title="$WINDOW_TITLE" \
        -vsync 2 \
        -g $(($FPS * 2)) \
        -vcodec libx264 -pix_fmt yuv444p -preset ultrafast -crf 10 -r $FPS -maxrate 2500k \
        -acodec libmp3lame -ac 1 -ar 44100 -q:a 0 \
        -bufsize 4M \
        -f flv \
        "$YOUTUBE_URL/$KEY" \
        || echo "FFmpeg exit code: $?"

    echo
    echo "==== auto restarting FFmpeg after $RESTART_SLEEP seconds ===="
    sleep "$RESTART_SLEEP"
    echo 'finished delay, restarting...'
    echo
done
