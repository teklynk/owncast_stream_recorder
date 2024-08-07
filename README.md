## Owncast Stream Recorder

This script monitors the `/api/status` endpoint every 30 seconds to check if `"online": true`. When the stream is detected as online, the script waits an additional 30 seconds before starting to record the stream's m3u8 URL. The recordings are saved to a specified directory. When the stream ends, the recording stops automatically.

You can set up this script as a cron job on your server, home PC, or NAS to automatically start recording whenever you go live.

# Setup

1. Modify the script for your environment
```bash
# Configuration variables
API_URL="https://<owncast-server>/api/status"
M3U8_STREAM_URL="https://<owncast-server>/hls/0/stream.m3u8"
RECORDINGS_DIR="<path-to-store-recordings>"
```

2. Make the script executable:
```bash
chmod +x /path/to/owncast_stream_recorder.sh
```

3. Add the script to your crontab to run on system boot:
```bash
crontab -e
```

4. Add the following line to the crontab file:
```bash
@reboot /path/to/owncast_stream_recorder.sh
```

This configuration ensures the script runs at startup and continuously monitors the stream status, handling the recording process automatically.