# Gitleaks Pre-commit Hook

Автоматична перевірка секретів у git репозиторії за допомогою gitleaks перед кожним комітом.

## Швидке встановлення (curl pipe sh)

```bash
curl -fsSL https://raw.githubusercontent.com/Bo3gyX19/git-pre-commit-hook/main/install-gitleaks-hook.sh | bash
```

## Ручне встановлення

1. Клонуйте репозиторій або завантажте файли:
```bash
git clone https://github.com/Bo3gyX19/git-pre-commit-hook.git
cd git-pre-commit-hook
```

2. Зробіть скрипт виконуваним та запустіть:
```bash
chmod +x install-gitleaks-hook.sh
./install-gitleaks-hook.sh
```

## Що робить інсталятор

1. **Визначає операційну систему** (macOS, Linux, Windows)
2. **Автоматично завантажує** останню версію gitleaks з GitHub
3. **Встановлює gitleaks** в систему (`/usr/local/bin` або `~/.local/bin`)
4. **Створює pre-commit hook** в `.git/hooks/pre-commit`
5. **Налаштовує конфігурацію** gitleaks (`.gitleaks.toml`)
6. **Створює файл ігнорування** (`.gitleaksignore`)
7. **Включає hook** через git config

## Використання

### Автоматична перевірка
Hook автоматично запускається при кожному `git commit`:

```bash
git add .
git commit -m "Ваше повідомлення"
# Автоматично запускається перевірка gitleaks
```

### Ручна перевірка
Перевірити файли вручну:

```bash
# Перевірка staged файлів
gitleaks protect --staged

# Перевірка всього репозиторію
gitleaks detect
```

### Управління hook

```bash
# Вимкнути gitleaks hook
git config hooks.gitleaks false

# Включити gitleaks hook
git config hooks.gitleaks true

# Перевірити статус
git config hooks.gitleaks
```

## Тестування

Створіть тестовий файл з Telegram bot token для перевірки роботи:

```bash
# Створити файл з секретом
echo "TELEGRAM_BOT_TOKEN=123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefgh" > test-secret.txt

# Спробувати закомітити
git add test-secret.txt
git commit -m "Test commit with secret"
# Повинен відхилити коміт з повідомленням про секрет
```

## Приклад виводу при виявленні секрету

```
Запуск перевірки секретів з gitleaks...

    ○
    │╲
    │ ○
    ○ ░
    ░    gitleaks

Finding:     TELEGRAM_BOT_TOKEN=123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefgh
Secret:      123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefgh
RuleID:      telegram-bot-token
Entropy:     4.8
File:        test-secret.txt
Line:        1

❌ КОМІТ ВІДХИЛЕНО!
Виявлено потенційні секрети в коді.

Для вирішення проблеми:
1. Видаліть секрети з коду
2. Використайте змінні оточення
3. Додайте файли до .gitleaksignore (якщо це false positive)

Для тимчасового пропуску перевірки:
git config hooks.gitleaks false
```

## Конфігурація

### .gitleaks.toml
Основний файл конфігурації з правилами виявлення секретів:

```toml
[extend]
useDefault = true

[[rules]]
id = "telegram-bot-token"
description = "Telegram Bot Token"
regex = '''[0-9]{8,10}:[a-zA-Z0-9_-]{35}'''
tags = ["telegram", "bot", "token"]
```

### .gitleaksignore
Файл для ігнорування false positive результатів:

```
# Формат: filename:rule-id:line-number
secrets.example.txt:generic-api-key:1
README.md:telegram-bot-token:15
```

## Підтримувані платформи

- **macOS** (Intel x64, Apple Silicon ARM64)
- **Linux** (x64, ARM64, ARMv7)
- **Windows** (x64, ARM64)

## Залежності

- **git** - для роботи з репозиторієм
- **curl** - для завантаження gitleaks
- **bash** - для виконання скриптів

## Усунення проблем

### Gitleaks не знайдено
```bash
# Перевірити PATH
echo $PATH

# Додати ~/.local/bin до PATH
export PATH="$PATH:$HOME/.local/bin"
```

### Проблеми з правами доступу
```bash
# Встановити в домашню директорію
mkdir -p ~/.local/bin
# Перезапустити інсталятор
```

### False positive результати
Додайте до `.gitleaksignore`:
```
filename:rule-id:line-number
```

## Деінсталяція

```bash
# Видалити hook
rm .git/hooks/pre-commit

# Вимкнути в git config
git config --unset hooks.gitleaks

# Видалити gitleaks (опціонально)
rm /usr/local/bin/gitleaks
# або
rm ~/.local/bin/gitleaks
```

## Допомога

Для додаткової інформації:
- [Gitleaks документація](https://github.com/gitleaks/gitleaks)
- [Git hooks документація](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
