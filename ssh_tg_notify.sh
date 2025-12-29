#!/bin/bash
if [ "$PAM_TYPE" != "close_session" ]; then
    HOST=$(hostname)

    MESSAGE=" *SSH Access Alert*%0A*Server:* $HOST%0A*User:* $PAM_USER%0A*Remote IP:* $PAM_RHOST%0A*Timestamp:* $(date '+%Y-%m-%d %H:%M:%S')"
    
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$MESSAGE" \
        -d "parse_mode=Markdown" > /dev/null
fi