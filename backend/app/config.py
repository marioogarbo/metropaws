"""Environment configuration — the single place that decides which environment
this process is running as, and where its settings come from.

One variable decides everything::

    APP_ENV=dev    (the default)  ->  .env.dev   — the DEV Supabase project
    APP_ENV=prod                  ->  .env.prod  — the LIVE database

Running the backend with no setup at all therefore targets DEV. Production is
never reached by accident: it takes an explicit ``APP_ENV=prod``.

**Real environment variables always win.** On Render, and with
``docker run --env-file``, the platform injects the settings directly and no
file on disk is read (env files are excluded from the image anyway). The env
files are a local-development convenience, not the deployment mechanism.

``.env.local`` is read first and beats the environment file. Put personal
machine settings there — a database on localhost, ``BASE_URL=http://localhost:8000``
— without editing a file that is shared with the Render services.

Import this module before any other project module. Several modules read
``os.getenv`` at import time, so the environment must be populated first; use
the ``require`` / ``env`` / ``env_int`` / ``env_bool`` helpers below in new code
so that ordering is enforced by the import rather than by convention.
"""
import os
import sys
from pathlib import Path
from urllib.parse import urlsplit

from dotenv import load_dotenv

# The backend directory, i.e. the parent of this app package. Everything that
# lives beside the app rather than inside it is found from here: the .env files,
# assets/, and the XLSX exports the broadcast script reads. Note the .parent
# twice — this module sits at backend/app/config.py, not backend/config.py.
BACKEND_DIR = Path(__file__).resolve().parent.parent

DEFAULT_APP_ENV = "dev"
ENV_FILES = {"dev": ".env.dev", "prod": ".env.prod"}
LOCAL_OVERRIDE_FILE = ".env.local"


def _resolve_app_env() -> str:
    app_env = os.getenv("APP_ENV", DEFAULT_APP_ENV).strip().lower()
    if app_env not in ENV_FILES:
        valid = ", ".join(sorted(ENV_FILES))
        raise RuntimeError(f"APP_ENV={app_env!r} is not a known environment. Use one of: {valid}.")
    return app_env


def _load_env_files(app_env: str) -> list[str]:
    """Populate os.environ from the env files, closest override first.

    ``load_dotenv`` never overwrites a variable that is already set, so the
    order below is the precedence order: real environment > .env.local >
    .env.<app_env>. A missing file is normal — in deployment there are none.
    """
    loaded = []
    for filename in (LOCAL_OVERRIDE_FILE, ENV_FILES[app_env]):
        path = BACKEND_DIR / filename
        if path.is_file():
            load_dotenv(path)
            loaded.append(filename)
    return loaded


APP_ENV = _resolve_app_env()
LOADED_ENV_FILES = _load_env_files(APP_ENV)
IS_PROD = APP_ENV == "prod"


def env(name: str, default: str | None = None) -> str | None:
    """Read an optional setting."""
    return os.getenv(name, default)


def require(name: str) -> str:
    """Read a setting the app cannot start without."""
    value = os.getenv(name)
    if not value:
        raise RuntimeError(
            f"{name} is not set. Add it to {ENV_FILES[APP_ENV]} (APP_ENV={APP_ENV}), "
            f"or set it in the environment when running in Docker or on Render."
        )
    return value


def env_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if raw is None or raw.strip() == "":
        return default
    try:
        return int(raw)
    except ValueError as exc:
        raise RuntimeError(f"{name}={raw!r} is not a whole number.") from exc


def env_list(name: str) -> list[str]:
    """Read a comma-separated setting. Blank entries are dropped, so trailing
    commas and stray spaces in an env file are harmless."""
    raw = os.getenv(name) or ""
    return [item.strip() for item in raw.split(",") if item.strip()]


def env_bool(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None or raw.strip() == "":
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def database_target() -> str:
    """The DATABASE_URL host and database name, with the credentials stripped.

    Safe to log — this is what tells you at a glance which database you are
    about to talk to.
    """
    url = os.getenv("DATABASE_URL")
    if not url:
        return "unset"
    parts = urlsplit(url)
    if not parts.hostname:
        # No host to name (SQLite, for instance) — the scheme is the whole story
        # and, unlike the raw URL, cannot carry a password.
        return parts.scheme or "unknown"
    port = f":{parts.port}" if parts.port else ""
    return f"{parts.hostname}{port}{parts.path}"


def describe() -> str:
    source = ", ".join(LOADED_ENV_FILES) if LOADED_ENV_FILES else "environment variables"
    return f"APP_ENV={APP_ENV}  db={database_target()}  config={source}"


def _announce() -> None:
    """Print the active target on startup, so no run is a guess about which
    database it is pointed at. Production gets a louder line — importing this
    package alone is enough to create tables against whatever it resolves to.
    """
    print(f"[config] {describe()}", file=sys.stderr)
    if IS_PROD:
        print("[config] *** PRODUCTION — this process targets the LIVE database ***", file=sys.stderr)


_announce()
