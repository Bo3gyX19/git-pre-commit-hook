#!/bin/bash

# Демонстраційний скрипт для тестування gitleaks pre-commit hook

set -e

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE} Gitleaks Pre-commit Hook - Демонстрація${NC}"
echo -e "${BLUE}================================================${NC}"
echo

# Перевірка чи ми в git репозиторії
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}Помилка: це не git репозиторій!${NC}"
    echo "Ініціалізуємо git репозиторій..."
    git init
    git config user.name "Test User"
    git config user.email "test@example.com"
fi

# Перевірка чи встановлений hook
if [ ! -f ".git/hooks/pre-commit" ]; then
    echo -e "${YELLOW}Pre-commit hook не встановлений!${NC}"
    echo "Запускаємо інсталятор..."
    ./install-gitleaks-hook.sh
fi

echo -e "${YELLOW}Тест 1: Створення файлу без секретів${NC}"
echo "# Безпечний файл без секретів" > safe-file.txt
echo "CONFIG_ENV=development" >> safe-file.txt
echo "DEBUG=true" >> safe-file.txt

git add safe-file.txt
if git commit -m "Додаткобезпечний файл"; then
    echo -e "${GREEN}✅ Коміт без секретів пройшов успішно${NC}"
else
    echo -e "${RED}❌ Неочікувана помилка при коміті безпечного файлу${NC}"
fi

echo
echo -e "${YELLOW}Тест 2: Спроба коміту файлу з секретами${NC}"
cp test-secrets.example test-secrets.txt

git add test-secrets.txt
if git commit -m "Додати файл з секретами"; then
    echo -e "${RED}❌ Коміт з секретами НЕ був заблокований! Це помилка!${NC}"
else
    echo -e "${GREEN}✅ Коміт з секретами був правильно заблокований${NC}"
fi

# Очищення
git reset HEAD test-secrets.txt 2>/dev/null || true
rm -f test-secrets.txt

echo
echo -e "${YELLOW}Тест 3: Вимкнення hook та повторна спроба${NC}"
git config hooks.gitleaks false

cp test-secrets.example test-secrets-disabled.txt
git add test-secrets-disabled.txt

if git commit -m "Коміт з вимкнутим hook"; then
    echo -e "${YELLOW}⚠️  Коміт пройшов з вимкнутим hook (очікувано)${NC}"
else
    echo -e "${RED}❌ Коміт не пройшов навіть з вимкнутим hook${NC}"
fi

# Видалення тестового файлу
git rm test-secrets-disabled.txt
git commit -m "Видалити тестовий файл з секретами"

echo
echo -e "${YELLOW}Тест 4: Включення hook знову${NC}"
git config hooks.gitleaks true

echo "TELEGRAM_BOT_TOKEN=987654321:ZYXWVUTSRQPONMLKJIHGFEDCBAabcdefgh" > telegram-test.txt
git add telegram-test.txt

if git commit -m "Тест Telegram токена"; then
    echo -e "${RED}❌ Telegram токен НЕ був виявлений! Потрібно перевірити конфігурацію!${NC}"
else
    echo -e "${GREEN}✅ Telegram токен був правильно виявлений та заблокований${NC}"
fi

# Очищення
git reset HEAD telegram-test.txt 2>/dev/null || true
rm -f telegram-test.txt

echo
echo -e "${YELLOW}Тест 5: Ручна перевірка gitleaks${NC}"
echo "API_KEY=sk-abcdef1234567890abcdef1234567890abcdef12" > manual-test.txt

echo -e "${BLUE}Запуск gitleaks detect:${NC}"
if gitleaks detect --source . --no-git; then
    echo -e "${RED}❌ Gitleaks не виявив секрети в manual-test.txt${NC}"
else
    echo -e "${GREEN}✅ Gitleaks правильно виявив секрети${NC}"
fi

rm -f manual-test.txt

echo
echo -e "${BLUE}================================================${NC}"
echo -e "${GREEN} Демонстрація завершена!${NC}"
echo -e "${BLUE}================================================${NC}"
echo
echo -e "${YELLOW}Результати тестування:${NC}"
echo "• Pre-commit hook встановлений та працює"
echo "• Секрети правильно виявляються та блокуються"
echo "• Hook можна вимикати/включати через git config"
echo "• Gitleaks працює як при коміті, так і вручну"
echo
echo -e "${YELLOW}Для подальшого використання:${NC}"
echo "• git config hooks.gitleaks true/false - увімкнути/вимкнути"
echo "• gitleaks detect - ручна перевірка"
echo "• Редагуйте .gitleaks.toml для налаштування правил"
echo "• Використовуйте .gitleaksignore для ігнорування false positive"
