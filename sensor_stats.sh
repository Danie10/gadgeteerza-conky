#!/bin/bash
# Single 'sensors' call feeding CPU temp + all 3 fan RPMs to /tmp cache files.
# This replaced a long inline execi command in conky.conf which was being
# silently truncated by conky's default text_buffer_size (256 bytes).
# Keeping this as a short external script, same pattern as gpu_stats.sh,
# avoids the buffer limit entirely.
#
# OPTIMISED: the previous version ran 'sensors' then piped its output through
# 4 separate greps and 3 awks (8 forks). One awk pass now extracts all four
# values, cutting this to 2 forks per cycle.
#
# ALSO ADDED: drive + NVMe temps, read straight from the kernel's hwmon sysfs
# (the 'drivetemp' module is loaded). This replaces the two
# 'sudo smartctl' calls that conky.conf ran every 300s - those needed root,
# forked 4 processes each, and could spin up an idle disk just to read it.
# sysfs reads are free and need no privileges.

sensors > /tmp/sensors_cache

# One awk pass replaces the old 4x grep + 3x awk pipeline.
awk '
    /Tctl/  { gsub(/[^0-9.]/, "", $2); print $2 > "/tmp/cpu_temp"  }
    /^fan1/ { print $2 > "/tmp/fan1_rpm" }
    /^fan2/ { print $2 > "/tmp/fan2_rpm" }
    /^fan3/ { print $2 > "/tmp/fan3_rpm" }
' /tmp/sensors_cache

# ---------------------------------------------------------------
# Drive temps via hwmon sysfs (no sudo, no smartctl, no disk wake)
# ---------------------------------------------------------------
# hwmon numbering is NOT stable across reboots, so resolve each drivetemp
# node by the block device it actually belongs to rather than hardcoding an
# index. Values are millidegrees, so divide by 1000.
for h in /sys/class/hwmon/hwmon*; do
    [[ -r "$h/name" ]] || continue
    read -r hname < "$h/name"

    case "$hname" in
        drivetemp)
            # Resolve the block device via shell globbing rather than $(ls ...),
            # which would fork a subshell + ls + head for every hwmon node.
            blk=""
            for b in "$h"/device/block/*; do
                [[ -e "$b" ]] && { blk="${b##*/}"; break; }
            done
            [[ -n "$blk" && -r "$h/temp1_input" ]] || continue
            read -r mt < "$h/temp1_input"
            case "$blk" in
                sda) echo "$(( mt / 1000 ))" > /tmp/sda_temp ;;
                sdc) echo "$(( mt / 1000 ))" > /tmp/sdc_temp ;;
            esac
            ;;
        nvme)
            [[ -r "$h/temp1_input" ]] || continue
            read -r mt < "$h/temp1_input"
            echo "$(( mt / 1000 ))" > /tmp/nvme_temp
            ;;
    esac
done

# ---------------------------------------------------------------
# Root filesystem usage percentage, for the Lua "almost full" alert.
# ---------------------------------------------------------------
# conky.conf previously tried: ${execi 600 echo ${fs_used_perc /} > /tmp/root_usage}
# That never worked - conky passes the literal string "${fs_used_perc /}" to
# the shell, which errors with "bad substitution", so /tmp/root_usage was never
# created and the Root_Full voice alert could never fire. Computing it here fixes it.
# Single df fork; awk is avoided by letting bash strip the '%' and header.
{ read -r _; read -r pcent; } < <(df --output=pcent /)
printf '%s\n' "${pcent//[^0-9]/}" > /tmp/root_usage
