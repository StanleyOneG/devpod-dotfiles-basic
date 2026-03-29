# DevPod Devcontainer Dotfiles

Dotfiles для настройки dev-окружения в [DevPod](https://devpod.sh) контейнерах. Включает Nix-пакеты (Python, Go, Node.js, jq и др.), zsh с autosuggestions/syntax-highlighting и автоматическую установку Claude Code.

## Что такое DevPod

DevPod создаёт воспроизводимое dev-окружение внутри Docker-контейнера. Твой проект монтируется в контейнер, все инструменты устанавливаются автоматически по конфигу, а подключиться можно через IDE или терминал.

Основные понятия:

- **Provider** --- где запускается контейнер (локальный Docker или удалённый сервер)
- **Dotfiles** --- репозиторий с настройками shell/инструментов (этот репозиторий), клонируется внутрь контейнера
- **devcontainer.json** --- конфиг в твоём проекте, описывает базовый образ и features для контейнера
- **Workspace** --- запущенный контейнер с твоим проектом внутри

## 1. Подготовка dotfiles-репозитория (опционально, если хочешь перенести в свой репозиторий - далее будет использоваться путь до этого репозитория)

Создай репозиторий на GitHub с содержимым этого каталога (`.zshrc`, `config.nix`, `setup` и т.д.).

DevPod клонирует dotfiles по HTTPS URL внутри контейнера и запускает скрипт `setup`. Локальные пути **не поддерживаются** флагом `--dotfiles` --- только git-репозитории.

Чтобы указать конкретную ветку, добавь `@branch-name` к URL:

```
--dotfiles https://github.com/<user>/<repo>@branch-name
```

> **Приватный репозиторий:** DevPod пробрасывает HTTPS-credentials с хоста в контейнер. Установи `gh` на хосте и выполни `gh auth login`, выбрав **HTTPS** протокол (не SSH). После этого DevPod сможет клонировать приватные dotfiles.

## 2. Установка DevPod CLI

```bash
# macOS
brew install devpod

# Linux
curl -L -o devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64"
chmod +x devpod
sudo mv devpod /usr/local/bin/
```

## 3. Подготовка проекта

### 3.1. Файл `.devcontainer/devcontainer.json`

В корне твоего проекта создай директорию `.devcontainer` и файл `devcontainer.json`.

**Базовый пример:**

```json
{
  "image": "mcr.microsoft.com/devcontainers/base:debian",
  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {
      "installZsh": true,
      "configureZshAsDefaultShell": true,
      "installOhMyZsh": true
    },
    "ghcr.io/devcontainers/features/nix:1": {},
    "ghcr.io/devcontainers/features/docker-in-docker:2": {
      "moby": false
    }
  },
  "mounts": [
    "source=${localWorkspaceFolder}/.devcontainer/.claude-config,target=/workspaces/.devcontainer/.claude-config,type=bind"
  ]
}
```

### 3.2. Docker внутри контейнера

Если тебе нужен Docker внутри devcontainer, есть два варианта:

**Docker-in-Docker** --- запускает отдельный Docker daemon внутри контейнера. Полная изоляция, но больше ресурсов:

```json
"ghcr.io/devcontainers/features/docker-in-docker:2": {
  "moby": false
}
```

**Docker-outside-of-Docker** --- использует Docker daemon хоста через проброс сокета. Легче по ресурсам, но контейнеры создаются как "соседи", а не "дети":

```json
"ghcr.io/devcontainers/features/docker-outside-of-docker:1": {
  "moby": false
}
```

Выбери один из вариантов в `features` своего `devcontainer.json`. Если Docker внутри контейнера не нужен --- убери оба.

### 3.3. Файл `.env` и токен Claude Code

Создай файл `.env` (на основе `.env.example` из этого репозитория). Расположение файла не принципиально --- путь к нему передаётся явно через флаг `--workspace-env-file` при запуске `devpod up`.

```
CLAUDE_CODE_OAUTH_TOKEN=<твой токен>
CLAUDE_CONFIG_DIR=/workspaces/.devcontainer/.claude-config
```

Также создай пустую директорию `.devcontainer/.claude-config/` --- она будет смонтирована в контейнер через bind mount для хранения конфигурации Claude Code.

`CLAUDE_CODE_OAUTH_TOKEN` --- OAuth-токен для аутентификации Claude Code в контейнере (без необходимости логина через браузер).

Чтобы получить long-lived токен (действует 1 год), выполни на хост-машине (где уже залогинен в Claude Code):

```bash
claude setup-token
```

Скопируй полученный токен в `.env` файл.

## 4. Выбор способа запуска

Есть два основных подхода. Выбери тот, который подходит под твой сценарий.

---

### Подход A: DevPod на локальной машине (рекомендуется для начала)

**Когда использовать:** проект лежит на твоём компьютере, или ты хочешь клонировать git-репозиторий. DevPod делает всё сам --- создаёт контейнер, монтирует проект, открывает IDE.

**Где установить DevPod:** на твоём компьютере (Mac/Linux).

#### Шаг 1. Добавь provider

```bash
# Если контейнер будет работать локально (нужен Docker на твоей машине):
devpod provider add docker

# Если контейнер будет работать на удалённом сервере (нужен Docker на сервере):
devpod provider add ssh
devpod provider set-options ssh -o HOST=user@your-server.com
```

#### Шаг 2. Запусти workspace

```bash
# Локальный проект + локальный Docker + VS Code
devpod up ./my-project \
  --provider docker \
  --dotfiles https://github.com/StanleyOneG/devpod-dotfiles-basic \
  --workspace-env-file /path/to/.env \
  --ide vscode

# Git-репозиторий + удалённый сервер + VS Code
devpod up github.com/user/repo \
  --provider ssh \
  --dotfiles https://github.com/StanleyOneG/devpod-dotfiles-basic \
  --workspace-env-file /path/to/.env \
  --ide vscode
```

DevPod автоматически:

1. Создаёт контейнер (локально или на сервере, в зависимости от provider)
2. Монтирует проект внутрь контейнера
3. Клонирует dotfiles и запускает `setup`
4. Открывает выбранную IDE, подключённую к контейнеру (см. ниже список ide)

#### Шаг 3. Подключение к контейнеру

Выбранныя на предыдущем этапе IDE открывается автоматически.

Если не открылся автоматически, то можно воспользоваться следующей командой:

```sh
devpod up <workspace-name> --ide vscode
```

Для терминального доступа:

```bash
devpod ssh <workspace-name>
# или
ssh <workspace-name>.devpod
```

**Ограничение:** при использовании SSH provider, DevPod сам выбирает где на сервере хранить данные. Нельзя указать конкретную директорию на сервере --- DevPod берёт локальный путь или git URL и сам разворачивает проект на сервере.

---

### Подход B: DevPod на удалённом сервере напрямую

**Когда использовать:** проект уже лежит в конкретной директории на сервере, и ты хочешь, чтобы контейнер монтировал именно эту директорию. Например, `/home/user/projects/my-app` на сервере.

**Где установить DevPod:** на самом сервере.

#### Шаг 1. Подключись к серверу и установи DevPod

```bash
ssh user@your-server.com

# Установи DevPod на сервере
curl -L -o devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64"
chmod +x devpod
sudo mv devpod /usr/local/bin/

# Добавь Docker provider
devpod provider add docker

# Отключи auto-exit (по умолчанию DevPod завершается после простоя)
devpod context set-options -o EXIT_AFTER_TIMEOUT=false
```

#### Шаг 2. Подготовь проект на сервере

В директории проекта на сервере должна быть папка `.devcontainer` с конфигами (как описано в разделе 3):

```
/home/user/projects/my-app/
├── .devcontainer/
│   ├── devcontainer.json    # конфиг контейнера (см. раздел 3.1)
│   └── .claude-config/      # пустая директория для конфига Claude Code
└── ... (твой проект)

# .env файл может лежать где угодно --- путь передаётся через --workspace-env-file
```

#### Шаг 3. Запусти workspace

```bash
# На сервере --- путь к проекту локальный для сервера
devpod up /home/user/projects/my-app \
  --dotfiles https://github.com/StanleyOneG/devpod-dotfiles-basic \
  --workspace-env-file /path/to/.env \
  --ide none
```

Контейнер создаётся на Docker сервера, проект монтируется из указанной директории.

#### Шаг 4. Подключение

**Терминал (самый простой способ):**

```bash
# На сервере:
devpod ssh my-app

# Или с локальной машины в одну команду:
ssh user@your-server.com -t "devpod ssh my-app"
```

**VS Code (через Dev Containers extension):**

1. Установи расширение [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) и [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) в VS Code
2. Подключись к серверу через Remote-SSH (`Ctrl+Shift+P` -> `Remote-SSH: Connect to Host`)
3. Когда VS Code подключён к серверу, выбери `Dev Containers: Attach to Running Container` (`Ctrl+Shift+P`)
4. Выбери контейнер DevPod из списка

Это даёт полноценный VS Code, подключённый к контейнеру на сервере.

---

### Какой подход выбрать?

| Сценарий | Подход |
|---|---|
| Проект на твоём компьютере, Docker локальный | **A** с `--provider docker` |
| Проект в git, контейнер на удалённом сервере | **A** с `--provider ssh` |
| Проект уже лежит в конкретной папке на сервере | **B** |
| Нужен VS Code с автоматическим подключением | **A** (любой provider) |
| Нужен только терминал | **A** или **B** с `--ide none` |
| Claude Code на сервере, доступный 24/7 | **B** + tmux (см. ниже) |

## 5. Постоянно запущенный Claude Code на удалённом сервере

Для постоянно работающего Claude Code на сервере используй **Подход B + tmux**.

Claude Code --- интерактивный процесс, умирает вместе с SSH-сессией. `tmux` решает эту проблему. Он уже включён в dotfiles.

```bash
# Первый запуск
ssh user@your-server.com -t "devpod ssh my-app"
tmux new -s claude
claude

# Переподключение (после disconnect / с другого устройства)
ssh user@your-server.com -t "devpod ssh my-app"
tmux attach -t claude
```

## 6. Флаг `--ide`

| Значение | IDE |
|---|---|
| `vscode` | VS Code (локальный) |
| `vscode-insiders` | VS Code Insiders |
| `cursor` | Cursor |
| `openvscode` | VS Code в браузере |
| `zed` | Zed |
| `fleet` | JetBrains Fleet |
| `intellij` | IntelliJ IDEA |
| `pycharm` | PyCharm |
| `goland` | GoLand |
| `webstorm` | WebStorm |
| `none` | Без IDE (только терминал) |

## 6. Что устанавливается

Скрипт `setup` автоматически:

- Устанавливает Nix-пакеты: `python3`, `uv`, `go`, `nodejs`, `jq`, `lsof`, `tmux`
- Настраивает zsh с autosuggestions и syntax-highlighting
- Устанавливает Claude Code через `npm install -g @anthropic-ai/claude-code`
- Подключает `.zshrc` с базовыми алиасами и настройками
