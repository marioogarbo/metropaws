"""Environment selection — config.py.

The default matters more than anything else here: an unconfigured run must
resolve to dev, never to the live database.
"""
import pytest

import config


def test_default_environment_is_dev(monkeypatch):
    monkeypatch.delenv("APP_ENV", raising=False)

    assert config._resolve_app_env() == "dev"


def test_explicit_prod_is_honoured(monkeypatch):
    monkeypatch.setenv("APP_ENV", "prod")

    assert config._resolve_app_env() == "prod"


def test_environment_name_is_case_insensitive(monkeypatch):
    monkeypatch.setenv("APP_ENV", "  PROD ")

    assert config._resolve_app_env() == "prod"


def test_unknown_environment_is_rejected(monkeypatch):
    monkeypatch.setenv("APP_ENV", "staging")

    with pytest.raises(RuntimeError, match="staging"):
        config._resolve_app_env()


def test_environment_file_is_loaded(monkeypatch, tmp_path):
    (tmp_path / ".env.dev").write_text("SETTING_FROM_FILE=from-dev\n")
    monkeypatch.setattr(config, "BACKEND_DIR", tmp_path)
    monkeypatch.delenv("SETTING_FROM_FILE", raising=False)

    loaded = config._load_env_files("dev")

    assert loaded == [".env.dev"]
    assert config.env("SETTING_FROM_FILE") == "from-dev"


def test_local_overrides_beat_the_environment_file(monkeypatch, tmp_path):
    (tmp_path / ".env.dev").write_text("SETTING_BOTH=from-dev\n")
    (tmp_path / ".env.local").write_text("SETTING_BOTH=from-local\n")
    monkeypatch.setattr(config, "BACKEND_DIR", tmp_path)
    monkeypatch.delenv("SETTING_BOTH", raising=False)

    config._load_env_files("dev")

    assert config.env("SETTING_BOTH") == "from-local"


def test_real_environment_beats_every_file(monkeypatch, tmp_path):
    """This is how Render and `docker run --env-file` configure the service."""
    (tmp_path / ".env.dev").write_text("SETTING_PLATFORM=from-dev\n")
    monkeypatch.setattr(config, "BACKEND_DIR", tmp_path)
    monkeypatch.setenv("SETTING_PLATFORM", "from-platform")

    config._load_env_files("dev")

    assert config.env("SETTING_PLATFORM") == "from-platform"


def test_missing_files_are_not_an_error(monkeypatch, tmp_path):
    """In deployment there are no env files at all."""
    monkeypatch.setattr(config, "BACKEND_DIR", tmp_path)

    assert config._load_env_files("dev") == []


def test_require_returns_a_set_value(monkeypatch):
    monkeypatch.setenv("NEEDED_SETTING", "present")

    assert config.require("NEEDED_SETTING") == "present"


def test_require_names_the_file_to_fix(monkeypatch):
    monkeypatch.delenv("NEEDED_SETTING", raising=False)

    with pytest.raises(RuntimeError, match=r"\.env\."):
        config.require("NEEDED_SETTING")


def test_require_rejects_an_empty_value(monkeypatch):
    """An empty DATABASE_URL is as unusable as a missing one."""
    monkeypatch.setenv("NEEDED_SETTING", "")

    with pytest.raises(RuntimeError):
        config.require("NEEDED_SETTING")


def test_env_returns_the_default_when_unset(monkeypatch):
    monkeypatch.delenv("OPTIONAL_SETTING", raising=False)

    assert config.env("OPTIONAL_SETTING", "fallback") == "fallback"


def test_env_int_parses_a_number(monkeypatch):
    monkeypatch.setenv("NUMBER_SETTING", "42")

    assert config.env_int("NUMBER_SETTING", 7) == 42


def test_env_int_falls_back_when_blank(monkeypatch):
    monkeypatch.setenv("NUMBER_SETTING", "   ")

    assert config.env_int("NUMBER_SETTING", 7) == 7


def test_env_int_rejects_nonsense(monkeypatch):
    """Fail loudly at startup rather than silently running on a default."""
    monkeypatch.setenv("NUMBER_SETTING", "ten")

    with pytest.raises(RuntimeError, match="NUMBER_SETTING"):
        config.env_int("NUMBER_SETTING", 7)


@pytest.mark.parametrize("raw", ["1", "true", "TRUE", "yes", "on", " True "])
def test_env_bool_accepts_truthy_spellings(monkeypatch, raw):
    monkeypatch.setenv("FLAG_SETTING", raw)

    assert config.env_bool("FLAG_SETTING") is True


@pytest.mark.parametrize("raw", ["0", "false", "no", "off", "anything-else"])
def test_env_bool_treats_everything_else_as_false(monkeypatch, raw):
    monkeypatch.setenv("FLAG_SETTING", raw)

    assert config.env_bool("FLAG_SETTING") is False


def test_env_bool_uses_the_default_when_unset(monkeypatch):
    monkeypatch.delenv("FLAG_SETTING", raising=False)

    assert config.env_bool("FLAG_SETTING", default=True) is True


def test_database_target_hides_the_credentials(monkeypatch):
    """The banner is printed on every startup — it must never leak a password."""
    monkeypatch.setenv("DATABASE_URL", "postgresql://user:hunter2@db.example.com:5432/postgres")

    target = config.database_target()

    assert target == "db.example.com:5432/postgres"
    assert "hunter2" not in target


def test_database_target_reports_an_unset_url(monkeypatch):
    monkeypatch.delenv("DATABASE_URL", raising=False)

    assert config.database_target() == "unset"


def test_database_target_names_a_hostless_database(monkeypatch):
    """SQLite has no host; the banner should still say something truthful."""
    monkeypatch.setenv("DATABASE_URL", "sqlite://")

    assert config.database_target() == "sqlite"


def test_describe_names_the_environment(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql://user:pw@db.example.com:5432/postgres")

    assert "APP_ENV=" in config.describe()
