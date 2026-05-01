#!/bin/bash

# Query metrics - using comma as the only delimiter for the query
# Now running the "heavy" nvidia-smi tool exactly once per refresh cycle instead of 8 separate times
OUTPUT=$(nvidia-smi --query-gpu=name,driver_version,utilization.memory,utilization.gpu,utilization.decoder,utilization.encoder,temperature.gpu,fan.speed --format=csv,noheader,nounits 2>/dev/null)

if [[ -z "$OUTPUT" ]]; then
    echo "GPU Error or Not Found"
    exit 1
fi

# Use awk to split by comma specifically, preserving spaces within the GPU name
NAME=$(echo "$OUTPUT" | awk -F', ' '{print $1}')
DRIVER=$(echo "$OUTPUT" | awk -F', ' '{print $2}')
VRAM=$(echo "$OUTPUT" | awk -F', ' '{print $3}' | sed 's/\[N\/A\]/0/')
GPU=$(echo "$OUTPUT" | awk -F', ' '{print $4}' | sed 's/\[N\/A\]/0/')
DEC=$(echo "$OUTPUT" | awk -F', ' '{print $5}' | sed 's/\[N\/A\]/0/')
ENC=$(echo "$OUTPUT" | awk -F', ' '{print $6}' | sed 's/\[N\/A\]/0/')
TEMP=$(echo "$OUTPUT" | awk -F', ' '{print $7}' | sed 's/\[N\/A\]/0/')
FAN=$(echo "$OUTPUT" | awk -F', ' '{print $8}' | sed 's/\[N\/A\]/0/')

# Save temp to file for your Lua alert script to read
echo "$TEMP" > /tmp/gpu_temp

# Determine temperature color logic for Conky
if [ "$TEMP" -ge 75 ]; then TCOLOR="\${color red}"; else TCOLOR="\${color green}"; fi


# Define VRAM Usage bar length
# Define total bar length (e.g., 20 blocks)
BAR_MAX=24
# Calculate segments
NUM_BLOCKS=$(( VRAM * BAR_MAX / 100 ))
NUM_EMPTY=$(( BAR_MAX - NUM_BLOCKS ))
# Generate strings using the EXACT same character for both
FILL_STR=$(printf '█%.0s' $(seq 1 $NUM_BLOCKS 2>/dev/null))
EMPTY_STR=$(printf '█%.0s' $(seq 1 $NUM_EMPTY 2>/dev/null))
# Apply colors: White for usage, Dark Grey for the "background" of the bar
BAR_STR="\${color white}${FILL_STR}\${color #333333}${EMPTY_STR}\$color"

# Output the RAW Conky code for display by execpi in conky.conf
cat <<EOF
\${font Good Times:size=12}\${color Tan1}GPU \$alignr \${font}\$color $NAME
\${color grey}Driver:\$color \$alignr $DRIVER
\${color grey}VRAM Usage:\$color $VRAM% $BAR_STR
\${color grey}Temperature: $TCOLOR \$alignr $TEMP°C\${lua check_alert GPU /tmp/gpu_temp}
\${color grey}Graphics Usage: \$color \$alignr $GPU%
\${color grey}Video Decoder: \$color \$alignr $DEC%
\${color grey}Video Encoder: \$color \$alignr $ENC%
\${color grey}Fan speed: \$color \$alignr $FAN%
EOF
