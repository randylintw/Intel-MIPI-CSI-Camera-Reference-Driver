    unset XDG_RUNTIME_DIR
    export DISPLAY=:0; xhost +
    export GST_PLUGIN_PATH=/usr/lib/gstreamer-1.0
    export LIBVA_DRIVER_NAME=iHD
    export GST_GL_API=gles2
    export GST_GL_PLATFORM=egl
    export LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/lib64/pkgconfig:/usr/lib/pkgconfig
    export LD_LIBRARY_PATH=/usr/local/lib/pkgconfig:/usr/local/lib:/usr/lib64:/usr/lib:/usr/lib/x86_64-linux-gnu
    export logSink=terminal
    rm -rf ~/.cache/gstreamer-1.0

gst-launch-1.0 icamerasrc num-buffers=-1 num-vc=8 scene-mode=normal device-name=acpi-1 printfps=true io-mode=mmap ! 'video/x-raw,drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false \
icamerasrc num-buffers=-1 num-vc=8 scene-mode=normal device-name=acpi-2 printfps=true io-mode=mmap ! 'video/x-raw,drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false \
icamerasrc num-buffers=-1 num-vc=8 scene-mode=normal device-name=acpi-3 printfps=true io-mode=mmap ! 'video/x-raw,drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false \
icamerasrc num-buffers=-1 num-vc=8 scene-mode=normal device-name=acpi-4 printfps=true io-mode=mmap ! 'video/x-raw,drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false \
icamerasrc num-buffers=-1 num-vc=8 scene-mode=normal device-name=acpi-5 printfps=true io-mode=mmap ! 'video/x-raw,drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false \
icamerasrc num-buffers=-1 num-vc=8 scene-mode=normal device-name=acpi-6 printfps=true io-mode=mmap ! 'video/x-raw,drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false \
icamerasrc num-buffers=-1 num-vc=8 scene-mode=normal device-name=acpi-7 printfps=true io-mode=mmap ! 'video/x-raw,drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false \
icamerasrc num-buffers=-1 num-vc=8 scene-mode=normal device-name=acpi-8 printfps=true io-mode=mmap ! 'video/x-raw,drm-format=UYVY,width=1920,height=1536' ! glimagesink sync=false 
