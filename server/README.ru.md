# CV Model Lab Server

Опциональный FastAPI backend для server mode в CV Model Lab. Он просматривает
датасеты внутри настроенных allowed roots, парсит и индексирует COCO annotations
и predictions на стороне сервера, отдаёт изображения и thumbnails, запускает
COCO AP metrics и TP/FP/FN evaluation, а также может отдавать Flutter Web/PWA
сборку.

Сервер работает с датасетами и prediction files в режиме read-only. Он записывает
только собственный cache и logs. Annotations, predictions и project files не
изменяются.

Полное руководство: [`docs/ru/server_mode.md`](../docs/ru/server_mode.md).

## Требования

- Python 3.9+
- [`uv`](https://docs.astral.sh/uv/) (рекомендуется)

## Установка

```bash
cd server
uv venv
uv pip install -e ".[dev]"
```

## Настройка

Скопируйте пример конфигурации и настройте allowed roots:

```bash
cp server.example.yaml server.yaml
```

`allowed_roots` обязателен: сервер читает файлы только внутри этих директорий.
Path traversal и выход через symlink отклоняются.

## Запуск

```bash
# из корня репозитория
scripts/run_server.sh server/server.yaml
# или напрямую
cd server
uv run python -m cvmlab_server.main --config server.yaml
```

Если `api_key` не задан, сервер запускается в режиме open access. В терминале он
запрашивает подтверждение (по умолчанию: no). При non-interactive запуске он
откажется стартовать без `--allow-unauthenticated`.

Чтобы включить authentication, задайте `api_key` в конфиге. Clients должны
передавать header `X-CVML-API-Key`.

## PWA

Соберите Flutter web app и укажите `static_web.root` на результат сборки:

```bash
flutter build web
# static_web.root по умолчанию указывает на ../build/web
```

После этого PWA доступна по `http://<host>:<port>/` и автоматически обращается к
API того же origin.

## Тесты

```bash
cd server
uv run pytest
```

Parity tests в `tests/test_parity.py` проверяют, что Python evaluation точно
повторяет Dart core. Fixtures генерируются командой
`flutter test test/server_parity/generate_fixtures_test.dart`.
