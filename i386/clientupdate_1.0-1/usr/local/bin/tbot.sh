#!/bin/bash
CONFIG_FILE=/etc/default/clientupdate

# https://ugeek.github.io/blog/post/2019-03-14-crea-un-bot-de-telegram-con-bash-y-una-sola-linea-de-terminal.html

if [ -f ${CONFIG_FILE} ]; then
    # Load custom configuration options.
    . ${CONFIG_FILE}
else
    echo "Missing ${CONFIG_FILE} with parameters BOT_TOKEN BOT_CHANNELID BOT_URL."
fi


#BOT_TOKEN="Your token"
#BOT_CHANNELID="1234"
#BOT_URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"

curl -s -X POST ${BOT_URL} -d chat_id=${BOT_CHANNELID} -d text="$1" 1>/dev/null 2>&1 &

