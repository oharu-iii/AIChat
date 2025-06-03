#!/bin/bash

# アプリのバンドルIDを指定
BUNDLE_ID="com.example.aiChat"

# シミュレーターのデータディレクトリを取得
APP_DATA_DIR=$(xcrun simctl get_app_container booted $BUNDLE_ID data)

if [ -z "$APP_DATA_DIR" ]; then
    echo "エラー: アプリのデータディレクトリが見つかりません。"
    echo "シミュレーターでアプリが実行されているか確認してください。"
    exit 1
fi

# ログファイルのパス
LOG_FILE="$APP_DATA_DIR/Documents/ai_chat.log"

if [ ! -f "$LOG_FILE" ]; then
    echo "エラー: ログファイルが見つかりません: $LOG_FILE"
    exit 1
fi

# デスクトップにログファイルをコピー
DESKTOP_PATH="$HOME/Desktop"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="ai_chat_log_$TIMESTAMP.log"

cp "$LOG_FILE" "$DESKTOP_PATH/$BACKUP_NAME"

echo "ログファイルをデスクトップにコピーしました: $BACKUP_NAME"

# 最新の10行を表示
echo "\n最新のログ（最後の10行）:"
tail -n 10 "$LOG_FILE" 