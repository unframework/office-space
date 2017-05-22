#!/bin/bash -e

VBR="2500k"
FPS="30"
QUAL="fast"
YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2"
WINDOW_TITLE='budo - Google Chrome'
FFMPEG='/c/Users/Nikita/Desktop/ffmpeg-3.3.1-win64-static/bin/ffmpeg'

"$FFMPEG" \
    -re \
    -f gdigrab -framerate "$FPS" \
    -offset_x 0 -offset_y 0 -video_size 1280x720 \
    -i title="$WINDOW_TITLE" \
    -vcodec libx264 -pix_fmt yuv420p -preset $QUAL -r $FPS -g $(($FPS * 2)) -b:v $VBR \
    -acodec libmp3lame -ar 44100 -threads 6 -crf 20 -b:a 712000 -bufsize 512k \
    -f flv \
    "$YOUTUBE_URL/$KEY"
