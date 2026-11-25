#!/bin/bash
unset XDG_RUNTIME_DIR
export DISPLAY=${DISPLAY:-:0}
xhost + >/dev/null 2>&1 || true
export GST_PLUGIN_PATH=/usr/lib/gstreamer-1.0
export INTEL_FORCE_PROBE='*'

CAPS='video/x-raw,format=UYVY,width=1920,height=1536,framerate=30/1,pixel-aspect-ratio=1/1'

for n in 0 1 2 3 16 17 18 19; do
    gst-launch-1.0 v4l2src device=/dev/video$n ! "$CAPS" ! \
        fpsdisplaysink video-sink=glimagesink sync=false text-overlay=false -v &
done

wait
