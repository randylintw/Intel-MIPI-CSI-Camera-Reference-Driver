gst-launch-1.0 v4l2src device=/dev/video0 ! 'video/x-raw,format=UYVY,width=3840,height=2160,framerate=30/1,pixel-aspect-ratio=1/1' ! videoconvert ! fpsdisplaysink  text-overlay=false -v &
gst-launch-1.0 v4l2src device=/dev/video1 ! 'video/x-raw,format=UYVY,width=3840,height=2160,framerate=30/1,pixel-aspect-ratio=1/1' ! videoconvert ! fpsdisplaysink  text-overlay=false -v &

