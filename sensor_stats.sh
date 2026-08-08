#!/bin/bash
# Single 'sensors' call feeding CPU temp + all 3 fan RPMs to /tmp cache files.
# This replaced a long inline execi command in conky.conf which was being
# silently truncated by conky's default text_buffer_size (256 bytes) - that
# truncation was cutting the command off right before the fan3 extraction,
# so /tmp/fan3_rpm never got written (Rear Fan showed blank).
# Keeping this as a short external script, same pattern as gpu_stats.sh,
# avoids the buffer limit entirely.

sensors > /tmp/sensors_cache
grep 'Tctl' /tmp/sensors_cache | cut -c16-19 > /tmp/cpu_temp
grep 'fan1' /tmp/sensors_cache | awk '{print $2}' > /tmp/fan1_rpm
grep 'fan2' /tmp/sensors_cache | awk '{print $2}' > /tmp/fan2_rpm
grep 'fan3' /tmp/sensors_cache | awk '{print $2}' > /tmp/fan3_rpm
