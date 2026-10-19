gst-launch-1.0 v4l2src device=/dev/video0 ! 'video/x-raw,format=UYVY,width=1920,height=1536,framerate=30/1,pixel-aspect-ratio=1/1' ! videoconvert ! fpsdisplaysink  -v &
gst-launch-1.0 v4l2src device=/dev/video1 ! 'video/x-raw,format=UYVY,width=1920,height=1536,framerate=30/1,pixel-aspect-ratio=1/1' ! videoconvert ! fpsdisplaysink  -v &
gst-launch-1.0 v4l2src device=/dev/video2 ! 'video/x-raw,format=UYVY,width=1920,height=1536,framerate=30/1,pixel-aspect-ratio=1/1' ! videoconvert ! fpsdisplaysink  -v &
gst-launch-1.0 v4l2src device=/dev/video3 ! 'video/x-raw,format=UYVY,width=1920,height=1536,framerate=30/1,pixel-aspect-ratio=1/1' ! videoconvert ! fpsdisplaysink  -v &
gst-launch-1.0 v4l2src device=/dev/video16 ! 'video/x-raw,format=UYVY,width=1920,height=1536,framerate=30/1,pixel-aspect-ratio=1/1' ! videoconvert ! fpsdisplaysink  -v &
gst-launch-1.0 v4l2src device=/dev/video17 ! 'video/x-raw,format=UYVY,width=1920,height=1536,framerate=30/1,pixel-aspect-ratio=1/1' ! videoconvert ! fpsdisplaysink  -v &
gst-launch-1.0 v4l2src device=/dev/video18 ! 'video/x-raw,format=UYVY,width=1920,height=1536,framerate=30/1,pixel-aspect-ratio=1/1' ! videoconvert ! fpsdisplaysink  -v &
gst-launch-1.0 v4l2src device=/dev/video19 ! 'video/x-raw,format=UYVY,width=1920,height=1536,framerate=30/1,pixel-aspect-ratio=1/1' ! videoconvert ! fpsdisplaysink  -v &
