#!/bin/bash -e

VBR="2500k"
FPS="30"
QUAL="medium"
YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2"

ffmpeg \
    -re \
    -f gdigrab -framerate "$FPS" \
    -i title='budo - Google Chrome' -offset_x 0 -offset_y 0 -video_size 1280x720
    -vcodec libx264 -pix_fmt yuv420p -preset $QUAL -r $FPS -g $(($FPS * 2)) -b:v $VBR \
    -acodec libmp3lame -ar 44100 -threads 6 -qscale:v 3 -b:a 712000 -bufsize 512k \
    -f flv "$YOUTUBE_URL/$KEY"
