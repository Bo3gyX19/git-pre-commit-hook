#!/bin/bash

# Gitleaks Pre-commit Hook Installer
# Автоматичне встановлення gitleaks та налаштування pre-commit hook

set -e

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функція для логування
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Перевірка чи ми в git репозиторії
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Це не git репозиторій! Спочатку ініціалізуйте git репозиторій."
        exit 1
    fi
}

# Визначення операційної системи
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "darwin" ;;
        Linux*)     echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)          echo "unknown" ;;
    esac
}

# Визначення архітектури
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "x64" ;;
        arm64|aarch64) echo "arm64" ;;
        armv7*) echo "armv7" ;;
        *) echo "x64" ;; # default fallback
    esac
}

# Встановлення gitleaks
install_gitleaks() {
    log "Встановлення gitleaks..."

    local os=$(detect_os)
    local arch=$(detect_arch)

    if [ "$os" = "unknown" ]; then
        error "Непідтримувана операційна система"
        exit 1
    fi

    # Перевірка чи gitleaks вже встановлений
    if command -v gitleaks >/dev/null 2>&1; then
        local version=$(gitleaks version 2>/dev/null | head -n1 || echo "unknown")
        success "Gitleaks вже встановлений: $version"
        return 0
    fi

    log "Завантаження останньої версії gitleaks для $os-$arch..."

    # Отримання останньої версії з GitHub API
    local latest_version
    if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        error "curl не знайдено. Будь ласка, встановіть curl."
        exit 1
    fi

    if [ -z "$latest_version" ]; then
        error "Не вдалося отримати інформацію про останню версію gitleaks"
        exit 1
    fi

    log "Остання версія: $latest_version"

    # Формування URL для завантаження
    local filename
    if [ "$os" = "windows" ]; then
        filename="gitleaks_${latest_version#v}_${os}_${arch}.zip"
    else
        filename="gitleaks_${latest_version#v}_${os}_${arch}.tar.gz"
    fi

    local download_url="https://github.com/gitleaks/gitleaks/releases/download/${latest_version}/${filename}"
    local temp_dir=$(mktemp -d)

    log "Завантаження з: $download_url"

    # Завантаження та розпакування
    cd "$temp_dir"
    if ! curl -L -o "$filename" "$download_url"; then
        error "Помилка завантаження gitleaks"
        rm -rf "$temp_dir"
        exit 1
    fi

    if [ "$os" = "windows" ]; then
        unzip -q "$filename"
    else
        tar -xzf "$filename"
    fi

    # Встановлення в систему
    local install_dir="/usr/local/bin"
    if [ ! -w "$install_dir" ]; then
        install_dir="$HOME/.local/bin"
        mkdir -p "$install_dir"

        # Додавання до PATH якщо потрібно
        if [[ ":$PATH:" != *":$install_dir:"* ]]; then
            warning "Додайте $install_dir до вашого PATH:"
            echo "export PATH=\"\$PATH:$install_dir\""
        fi
    fi

    if [ "$os" = "windows" ]; then
        mv gitleaks.exe "$install_dir/"
    else
        mv gitleaks "$install_dir/"
    fi

    chmod +x "$install_dir/gitleaks"

    # Очищення
    rm -rf "$temp_dir"

    success "Gitleaks успішно встановлено в $install_dir"
}

# Створення pre-commit hook
create_pre_commit_hook() {
    log "Створення pre-commit hook..."

    local git_dir=$(git rev-parse --git-dir)
    local hooks_dir="$git_dir/hooks"
    local hook_file="$hooks_dir/pre-commit"

    # Створення директорії hooks якщо не існує
    mkdir -p "$hooks_dir"

    # Створення pre-commit hook
    cat > "$hook_file" << 'EOF'
#!/bin/bash

# Gitleaks Pre-commit Hook
# Перевіряє код на наявність секретів перед комітом

# Кольори для виводу
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Перевірка чи включений gitleaks hook
if [ "$(git config --bool hooks.gitleaks)" = "false" ]; then
    echo -e "${YELLOW}Gitleaks hook вимкнений. Для включення виконайте:${NC}"
    echo "git config hooks.gitleaks true"
    exit 0
fi

# Перевірка наявності gitleaks
if ! command -v gitleaks >/dev/null 2>&1; then
    echo -e "${RED}ERROR: gitleaks не знайдено!${NC}"
    echo "Встановіть gitleaks: ./install-gitleaks-hook.sh"
    exit 1
fi

echo -e "${YELLOW}Запуск перевірки секретів з gitleaks...${NC}"

# Запуск gitleaks для staged файлів
if ! gitleaks protect --staged --verbose; then
    echo -e "${RED}❌ КОМІТ ВІДХИЛЕНО!${NC}"
    echo -e "${RED}Виявлено потенційні секрети в коді.${NC}"
    echo
    echo -e "${YELLOW}Для вирішення проблеми:${NC}"
    echo "1. Видаліть секрети з коду"
    echo "2. Використайте змінні оточення"
    echo "3. Додайте файли до .gitleaksignore (якщо це false positive)"
    echo
    echo -e "${YELLOW}Для тимчасового пропуску перевірки:${NC}"
    echo "git config hooks.gitleaks false"
    echo
    exit 1
fi

echo -e "${GREEN}✅ Перевірка секретів пройшла успішно!${NC}"
exit 0
EOF

    # Робимо hook виконуваним
    chmod +x "$hook_file"

    success "Pre-commit hook створено: $hook_file"
}

# Створення конфігурації gitleaks
create_gitleaks_config() {
    log "Створення базової конфігурації gitleaks..."

    if [ ! -f ".gitleaks.toml" ]; then
        cat > ".gitleaks.toml" << 'EOF'
# Gitleaks configuration file

[extend]
# useDefault will extend the base configuration with the default gitleaks config:
# https://github.com/gitleaks/gitleaks/blob/master/config/gitleaks.toml
useDefault = true

[allowlist]
description = "Allowlist for specific patterns that are safe"
# regexes = [
#   '''219-09-9999''', # fake SSN
#   '''078-05-1120''', # fake SSN
# ]
# paths = [
#   '''.*_test\.go''',
#   '''.*\.md''',
# ]
# commits = [
#   "allowedcommithashhere"
# ]

# Додаткові правила для виявлення українських секретів
[[rules]]
id = "telegram-bot-token"
description = "Telegram Bot Token"
regex = '''[0-9]{8,10}:[a-zA-Z0-9_-]{35}'''
tags = ["telegram", "bot", "token"]

[[rules]]
id = "ukrainian-api-key"
description = "Generic Ukrainian API Key"
regex = '''(?i)(api[_-]?key|apikey)['":\s]*[=:]\s*['"][a-zA-Z0-9_-]{20,}['"]'''
tags = ["api", "key"]
EOF
        success "Створено .gitleaks.toml конфігурацію"
    else
        warning ".gitleaks.toml вже існує"
    fi

    # Створення .gitleaksignore якщо не існує
    if [ ! -f ".gitleaksignore" ]; then
        cat > ".gitleaksignore" << 'EOF'
# Gitleaks ignore patterns
# Використовуйте цей файл для ігнорування false positive результатів

# Приклади:
# secrets.example.txt:generic-api-key:1
# README.md:telegram-bot-token:15
EOF
        success "Створено .gitleaksignore файл"
    else
        warning ".gitleaksignore вже існує"
    fi
}

# Налаштування git config
configure_git() {
    log "Налаштування git конфігурації..."

    # Включення gitleaks hook за замовчуванням
    git config hooks.gitleaks true

    success "Git конфігурацію оновлено"
}

# Тестування установки
test_installation() {
    log "Тестування установки..."

    # Перевірка gitleaks
    if ! command -v gitleaks >/dev/null 2>&1; then
        error "Gitleaks не знайдено в PATH"
        return 1
    fi

    local version=$(gitleaks version 2>/dev/null | head -n1 || echo "unknown")
    success "Gitleaks версія: $version"

    # Перевірка hook
    local git_dir=$(git rev-parse --git-dir)
    local hook_file="$git_dir/hooks/pre-commit"

    if [ -x "$hook_file" ]; then
        success "Pre-commit hook встановлено і виконуваний"
    else
        error "Pre-commit hook не знайдено або не виконуваний"
        return 1
    fi

    success "Установка успішно завершена!"
}

# Головна функція
main() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE} Gitleaks Pre-commit Hook Installer${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo

    check_git_repo
    install_gitleaks
    create_pre_commit_hook
    create_gitleaks_config
    configure_git
    test_installation

    echo
    echo -e "${GREEN}🎉 Установка завершена!${NC}"
    echo
    echo -e "${YELLOW}Використання:${NC}"
    echo "• Hook автоматично запускається при git commit"
    echo "• Для вимкнення: git config hooks.gitleaks false"
    echo "• Для включення: git config hooks.gitleaks true"
    echo "• Для тестування: gitleaks protect --staged"
    echo
    echo -e "${YELLOW}Файли конфігурації:${NC}"
    echo "• .gitleaks.toml - конфігурація gitleaks"
    echo "• .gitleaksignore - файл для ігнорування false positive"
    echo
}

# Запуск скрипта
main "$@"
