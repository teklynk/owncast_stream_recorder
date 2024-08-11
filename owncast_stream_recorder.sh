#!/bin/bash

# Configuration variables
API_URL="https://<owncast-server>/api/status"
M3U8_STREAM_URL="https://<owncast-server>/hls/0/stream.m3u8"
RECORDINGS_DIR="<path-to-store-recordings>"

# Function to check if stream is online
is_stream_online() {
    response=$(curl -s "$API_URL")
    echo "$response" | grep -q '"online":true'
    return $?
}

# Function to start recording
start_recording() {
    timestamp=$(date +"%Y%m%d_%H%M%S")
    output_file="${RECORDINGS_DIR}/recording_${timestamp}.mp4"
    ffmpeg -i "$M3U8_STREAM_URL" -c copy "$output_file" &
    echo $! > /tmp/ffmpeg_pid
}

# Function to stop recording
stop_recording() {
    if [ -f /tmp/ffmpeg_pid ]; then
        pid=$(cat /tmp/ffmpeg_pid)
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            rm /tmp/ffmpeg_pid
            manage_recordings
        else
            echo "Recording process $pid not found. It may have already ended."
            rm /tmp/ffmpeg_pid
        fi
    fi
}

# Function to manage recordings
manage_recordings() {
    recordings=($(ls -t "${RECORDINGS_DIR}/recording_*.mp4"))
    if [ ${#recordings[@]} -gt 3 ]; then
        for ((i=3; i<${#recordings[@]}; i++)); do
            rm "${recordings[$i]}"
            echo "Deleted old recording: ${recordings[$i]}"
        done
    fi
}

# Main loop
while true; do
    if is_stream_online; then
        if [ ! -f /tmp/ffmpeg_pid ]; then
            echo "Stream is online. Waiting 30 seconds before starting recording..."
            sleep 30
            if is_stream_online; then  # Check again to ensure the stream is still online after waiting
                echo "Starting recording..."
                start_recording
            else
                echo "Stream went offline during the wait period. Not starting recording."
            fi
        fi
    else
        if [ -f /tmp/ffmpeg_pid ]; then
            echo "Stream is offline. Stopping recording..."
            stop_recording
        fi
    fi
    sleep 30
done
