#!/bin/bash

### DESCRIPTION ###
# records video from capture card
# run this script by doing `./record.sh {recording_name} {record_duration_minutes: integer}`
# for example:
    # ./record.sh tape_01 120

### DEFAULT VALUES ###
recording_name="recording"
duration=0

### ENVIRONMENT VARIABLE CHECKS ###
if [[ -v DEVICE ]]; then
  echo "Recording capture device: $DEVICE"
else
  echo "Environment Variable DEVICE is not defined"
  exit 1
fi

if [[ -v INPUT_TYPE ]]; then
  echo "Recording input: $INPUT_TYPE"
else
  echo "Environment Variable INPUT_TYPE is not defined"
  exit 1
fi

### ARGUMENT CHECKS ###
if [ "$#" -ge 1 ]; then
  recording_name="$1"
fi

if [ "$#" -ge 2 ]; then
  duration=$2
  if ! [[ $duration =~ ^[0-9]+$ ]]; then
    echo "Error: Record duration must be an integer."
    exit 1
  fi
  echo "Record duration set to ${duration} minutes"
fi

# get the format of incoming video
probe_response=$(ffprobe -hide_banner \
-f decklink \
-i "${DEVICE}" \
-select_streams v:0 \
-video_input ${INPUT_TYPE} \
-audio_input embedded \
-show_entries stream=width,height,r_frame_rate,pix_fmt \
-of default=noprint_wrappers=1:nokey=1 -v quiet)

width=$(echo "$probe_response" | awk 'NR==1')
height=$(echo "$probe_response" | awk 'NR==2')
pixel_format=$(echo "$probe_response" | awk 'NR==3')
r_frame_rate=$(echo "$probe_response" | awk 'NR==4')

echo "Source dimensions: ${width}x${height} at ${r_frame_rate} fps"

format_code=$(grep "${width}x${height} at ${r_frame_rate} fps" ./formats.txt | awk '{print $1}')
echo "Input format code: ${format_code}"

command="ffmpeg -hide_banner -y \
-format_code $format_code \
-f decklink \
-video_input $INPUT_TYPE \
-audio_input embedded \
-raw_format $pixel_format \
-i \"${DEVICE}\"" \
-vf "scale=640:480,setsar=1:1"

if [ "$duration" != 0 ]; then
    duration=$((duration * 60)) # convert minutes to seconds
    command="${command} -t $duration"
fi

TIMESTAMP=$(date +"%Y-%m-%d_%H%M%S")
RECORD_PATH="/media/${TIMESTAMP}_${recording_name}.mkv"

echo "Recording destination set to: $RECORD_PATH"

command="${command} \
-c:v libx264 \
-preset ultrafast \
-crf 18 \
-pix_fmt yuv420p \
-profile:v main \
-c:a aac \"${RECORD_PATH}\""

echo "Running ffmpeg command: $command"
eval "${command}"