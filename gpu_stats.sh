#!/bin/bash

# Define your total VRAM in MiB (12GB = 12288 MiB)
TOTAL_VRAM=12288

# Query metrics - running the "heavy" nvidia-smi tool exactly once per refresh
# cycle instead of 8 separate times.
#
# OPTIMISED: the previous version then split that single line by piping it
# through 8 separate 'echo | awk' subshells plus 7 'sed' calls - about 30 forks
# every 10 seconds (~260k processes a day) purely to split one CSV line.
# Bash can do the whole split natively with one 'read', so this is now 2 forks.
IFS=',' read -r NAME DRIVER VRAM_RAW GPU DEC ENC TEMP FAN < <(
    nvidia-smi --query-gpu=name,driver_version,memory.used,utilization.gpu,utilization.decoder,utilization.encoder,temperature.gpu,fan.speed \
        --format=csv,noheader,nounits 2>/dev/null
)

if [[ -z "$NAME" ]]; then
    echo "GPU Error or Not Found"
    exit 1
fi

# Trim leading/greedy whitespace left by the CSV separator, and normalise the
# [N/A] values nvidia-smi emits for unsupported metrics. Pure bash, no sed forks.
for v in NAME DRIVER VRAM_RAW GPU DEC ENC TEMP FAN; do
    val="${!v}"
    val="${val#"${val%%[![:space:]]*}"}"   # strip leading whitespace
    val="${val%"${val##*[![:space:]]}"}"   # strip trailing whitespace
    [[ "$val" == "[N/A]" ]] && val=0
    printf -v "$v" '%s' "$val"
done

# Guard against non-numeric values so the arithmetic below can't error out
[[ "$VRAM_RAW" =~ ^[0-9]+$ ]] || VRAM_RAW=0
[[ "$TEMP"     =~ ^[0-9]+$ ]] || TEMP=0

# Calculate VRAM percentage: (Used / Total) * 100
VRAM_PERC=$(( VRAM_RAW * 100 / TOTAL_VRAM ))

# Save temp to file for the Lua alert script to read
echo "$TEMP" > /tmp/gpu_temp

# Determine temperature color logic for Conky
if [ "$TEMP" -ge 80 ]; then TCOLOR="\${color red}"; else TCOLOR="\${color green}"; fi

# VRAM bar: written to a file and drawn by conky's native execibar so it matches the other bars
echo "$VRAM_PERC" > /tmp/gpu_vram_perc

# Output the RAW Conky code for display by execpi in conky.conf
cat <<EOF
\${font Good Times:size=12}\${color Tan1}GPU \$alignr \${font}\$color $NAME
\${color1}Driver:\$color \$alignr $DRIVER
\${color1}VRAM Usage:\$color $VRAM_PERC% \${execibar 10 cat /tmp/gpu_vram_perc}
\${color1}Temperature: $TCOLOR \$alignr $TEMP°C\${lua check_alert GPU /tmp/gpu_temp}
\${color1}Graphics Usage: \$color \$alignr $GPU%
\${color1}Video Decoder: \$color \$alignr $DEC%
\${color1}Video Encoder: \$color \$alignr $ENC%
\${color1}Fan speed: \$color \$alignr $FAN%
EOF
