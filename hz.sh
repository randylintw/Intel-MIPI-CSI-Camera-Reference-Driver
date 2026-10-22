echo 0 >/sys/class/pps-gen/pps-gen0/enable
sleep 1
echo 25 > /sys/module/pps_gen_tio/parameters/pps_frequency_hz
echo 1 >/sys/class/pps-gen/pps-gen0/enable
