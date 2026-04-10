# 1. Создаем структуру папок
mkdir -p /opt/stealthnet-tools/logs

# 2. Создаем сам скрипт обновления
cat << 'EOF' > /opt/stealthnet-tools/update.sh
#!/bin/bash

# Настройки путей
PROJECT_PATH="/opt/remnawave-STEALTHNET-Bot"
LOG_FILE="/opt/stealthnet-tools/logs/update_$(date +%Y-%m-%d).log"

{
    echo "--- Начало обновления: $(date) ---"
    cd $PROJECT_PATH || exit

    echo "Шаг 1: Сохранение изменений..."
    git stash
    sleep 20

    echo "Шаг 2: Скачивание кода..."
    git pull
    sleep 20

    echo "Шаг 3: Возврат настроек и фикс памяти..."
    git stash pop
    git checkout --ours nginx/nginx.conf &> /dev/null
    git add nginx/nginx.conf &> /dev/null
    # Гарантируем, что лимит памяти в Dockerfile не слетел после pull
    sed -i 's/npm run build/NODE_OPTIONS=--max-old-space-size=1536 npm run build/g' frontend/Dockerfile
    sleep 20

    echo "Шаг 4: Сборка образов..."
    docker compose build
    sleep 20

    echo "Шаг 5: Запуск контейнеров..."
    docker compose up -d
    sleep 20

    echo "Шаг 6: Синхронизация базы данных..."
    docker compose exec -T api npx prisma db push
    sleep 20

    echo "--- Обновление завершено: $(date) ---"
} >> "$LOG_FILE" 2>&1
EOF

# 3. Даем права на запуск
chmod +x /opt/stealthnet-tools/update.sh

# 4. Настраиваем Cron (удаляем старые задачи бота и ставим новую)
(crontab -l 2>/dev/null | grep -v "update.sh"; echo "0 4 * * * /bin/bash /opt/stealthnet-tools/update.sh") | crontab -

echo "Успешно! Скрипт: /opt/stealthnet-tools/update.sh"
echo "Логи будут здесь: /opt/stealthnet-tools/logs/"
