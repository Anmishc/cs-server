# 🎮 CS 1.6 Server — Plugin Manager

Локальный проект для управления плагинами, модами и конфигами CS 1.6 сервера.

**Сервер:** `91.211.118.77:27015`  
**FTP:** `ftp://s37112@91.211.118.77:21`

---

## 📁 Структура проекта

```
cs16-server/
├── addons/
│   ├── amxmodx/
│   │   ├── plugins/          ← Скомпилированные плагины (.amxx)
│   │   ├── scripting/        ← Исходники плагинов (.sma)
│   │   │   └── include/      ← Заголовочные файлы (.inc)
│   │   └── configs/          ← Конфиги плагинов
│   │       ├── plugins.ini   ← Список активных плагинов (главный!)
│   │       ├── plugins/      ← Конфиги отдельных плагинов
│   │       ├── mode/         ← Конфиги режимов по картам
│   │       ├── rt_configs/   ← Конфиги Respawn Team
│   │       └── aes/          ← Конфиги системы опыта
│   └── metamod/
│       └── plugins.ini       ← Список модулей metamod
└── server-configs/           ← Основные конфиги сервера
    ├── server.cfg            ← Главный конфиг сервера
    ├── game.cfg              ← Игровые настройки
    ├── mapcycle.txt          ← Список карт в ротации
    └── ...
```

---

## 🚀 Деплой на сервер

### Задачи VS Code (Ctrl+Shift+B)
| Задача | Описание |
|--------|----------|
| 🚀 Deploy ALL to FTP | Загрузить все изменения |
| 📦 Deploy plugins only | Только плагины (.amxx) |
| ⚙️ Deploy configs only | Только конфиги |
| 📥 Pull from FTP | Синхронизировать с сервера |

### Через терминал
```powershell
# Загрузить все изменения на сервер
.\deploy.ps1

# Только плагины
.\deploy.ps1 -Only plugins

# Только конфиги
.\deploy.ps1 -Only configs

# Скачать актуальные файлы с сервера
.\sync-from-ftp.ps1
```

---

## 🧩 Управление плагинами

### Включить/выключить плагин
Редактируй файл `addons/amxmodx/configs/plugins.ini`:
```ini
; Включён
admin.amxx

; Выключен (закомментировать)
; vip.amxx
```

### Ключевые плагины
| Файл | Описание |
|------|----------|
| `vip.amxx` | VIP система |
| `mode.amxx` | Игровые режимы |
| `map_manager_*.amxx` | Управление картами (RTV, номинации) |
| `molotov_grenade.amxx` | Граната-молотов |
| `healthnade.amxx` | Лечащая граната |
| `rt_*.amxx` | Respawn Team режим |
| `aes_*.amxx` | Система опыта и статистики |
| `auto_team_balance_advanced.amxx` | Автобаланс команд |
| `awp_limiter.amxx` | Ограничение AWP |
| `chatmanager.amxx` | Управление чатом |

---

## 📝 Создание и деплой нового плагина

### Шаг 1 — Написать плагин
Создай файл `.sma` в `addons/amxmodx/scripting/`:
```
addons/amxmodx/scripting/my_plugin.sma
```

### Шаг 2 — Скомпилировать
Компилятор `amxxpc.exe` уже лежит в `addons/amxmodx/scripting/`.  
Запускать **обязательно из этой папки**, иначе не найдёт `include/`:
```powershell
cd addons\amxmodx\scripting
.\amxxpc.exe my_plugin.sma
# Создаст my_plugin.amxx рядом
```
Или через **AMXX-Studio** — просто нажать F5 (компилятор уже настроен).

### Шаг 3 — Положить .amxx в plugins
```powershell
Move-Item addons\amxmodx\scripting\my_plugin.amxx addons\amxmodx\plugins\
```

### Шаг 4 — Прописать в plugins.ini
Добавь строку в `addons/amxmodx/configs/plugins.ini`:
```ini
my_plugin.amxx
```

### Шаг 5 — Задеплоить на сервер
```powershell
.\deploy.ps1 -Env dev -Only plugins
# или сразу всё:
.\deploy.ps1 -Env dev
```

> ⚠️ Все кастомные `.inc` заголовки кладутся в `addons/amxmodx/scripting/include/`

---

## 🗺️ Карты в ротации
Редактируй `server-configs/mapcycle.txt` — одна карта на строку.

---

## ⚙️ VIP система
Конфиг: `addons/amxmodx/configs/plugins/vip_system.json`

---

## 👮 Администраторы
Файл: `addons/amxmodx/configs/users.ini`
```ini
; "nickname/steamid/ip" "password" "access_flags" "account_flags"
"STEAM_0:0:12345" "" "abcdefghijklmnopqrstu" "ce"
```
