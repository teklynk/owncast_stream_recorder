#!/bin/bash

# Configuration variables
API_URL="https://<owncast-server>/api/status"
M3U8_STREAM_URL="https://<owncast-server>/hls/0/stream.m3u8"
RECORDINGS_DIR="<path-to-store-recordings>"
FILE_NAME_PREFIX="stream_"

# Function to check if stream is online
is_stream_online() {
    response=$(curl -s "$API_URL")
    echo "$response" | grep -q '"online":true'
    return $?
}

# Function to start recording
start_recording() {
    timestamp=$(date +"%Y%m%d_%H%M%S")
    output_file="${RECORDINGS_DIR}/${FILE_NAME_PREFIX}${timestamp}.mp4"
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
        else
            echo "Recording process $pid not found. It may have already ended."
            rm /tmp/ffmpeg_pid
        fi
    fi
    manage_recordings
    sleep 1
    remux_videos
}

# Function to manage recordings
manage_recordings() {
    cd "$RECORDINGS_DIR" || { echo "Directory not found: $RECORDINGS_DIR"; return 1; }

    echo "Looking for files in $RECORDINGS_DIR"

    recordings=($(ls -t *.mp4))
    
    echo "Found ${#recordings[@]} recordings."

    if [ ${#recordings[@]} -gt 6 ]; then
        for ((i=6; i<${#recordings[@]}; i++)); do
            echo "Deleting: ${recordings[$i]}"
            rm "${recordings[$i]}"
        done
    fi
}

remux_videos() { 
    cd "$RECORDINGS_DIR" || { echo "Directory not found: $RECORDINGS_DIR"; return 1; }
    echo "Looking for files in $RECORDINGS_DIR"

    # Loop through all mp4 files sorted by modification time
    for file in *.mp4; do
        if [ -f "$file" ]; then
            echo "Processing $file..."
            # Define the output file name for the re-muxed video
            temp_file="${file%.mp4}_temp.mp4"

            # Re-mux the file to ensure metadata is at the beginning
            ffmpeg -i "$file" -c copy -movflags +faststart "$temp_file"

            # Check if the re-muxing was successful
            if [ $? -eq 0 ]; then
                echo "Successfully re-muxed $file to $temp_file"
                # Remove the original file and rename the re-muxed file
                rm "$file"
                mv "$temp_file" "$file"
            else
                echo "Failed to re-mux $file"
                # Remove the temporary file if re-muxing failed
                rm "$temp_file"
            fi
        fi
    done
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
