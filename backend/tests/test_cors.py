"""Which browser origins may call the API — main.cors_settings.

Getting this wrong is not a cosmetic failure: too strict locks admins out of
the website, too loose lets any site call the API with a token it obtained.
"""
import main

WEBSITE = "https://metropaws.ph"
LOCAL_WEBSITE = "http://localhost:3000"
PREVIEW_PATTERN = r"^https://[a-z0-9-]+\.vercel\.app$"


def test_configured_origins_are_used(monkeypatch):
    monkeypatch.setenv("ALLOWED_ORIGINS", f"{WEBSITE},{LOCAL_WEBSITE}")
    monkeypatch.delenv("ALLOWED_ORIGIN_REGEX", raising=False)

    assert main.cors_settings() == ([WEBSITE, LOCAL_WEBSITE], None)


def test_whitespace_and_trailing_commas_are_tolerated(monkeypatch):
    """Env files are hand-edited; a stray comma must not create a "" origin,
    which would silently match nothing."""
    monkeypatch.setenv("ALLOWED_ORIGINS", f"  {WEBSITE} , {LOCAL_WEBSITE},  ,")
    monkeypatch.delenv("ALLOWED_ORIGIN_REGEX", raising=False)

    origins, _regex = main.cors_settings()

    assert origins == [WEBSITE, LOCAL_WEBSITE]


def test_preview_pattern_is_passed_through(monkeypatch):
    monkeypatch.setenv("ALLOWED_ORIGINS", WEBSITE)
    monkeypatch.setenv("ALLOWED_ORIGIN_REGEX", PREVIEW_PATTERN)

    assert main.cors_settings() == ([WEBSITE], PREVIEW_PATTERN)


def test_a_pattern_alone_is_enough(monkeypatch):
    """A regex with no explicit list must not trip the permissive fallback."""
    monkeypatch.delenv("ALLOWED_ORIGINS", raising=False)
    monkeypatch.setenv("ALLOWED_ORIGIN_REGEX", PREVIEW_PATTERN)

    assert main.cors_settings() == ([], PREVIEW_PATTERN)


def test_nothing_configured_allows_everything(monkeypatch):
    """Deliberate: a missing variable must never lock admins out of production.
    The warning it prints is how you notice."""
    monkeypatch.delenv("ALLOWED_ORIGINS", raising=False)
    monkeypatch.delenv("ALLOWED_ORIGIN_REGEX", raising=False)

    assert main.cors_settings() == (["*"], None)


def test_blank_origins_are_treated_as_unset(monkeypatch):
    monkeypatch.setenv("ALLOWED_ORIGINS", "   ")
    monkeypatch.delenv("ALLOWED_ORIGIN_REGEX", raising=False)

    assert main.cors_settings() == (["*"], None)


def _cors_middleware():
    return next(m for m in main.app.user_middleware if "CORS" in str(m))


def test_middleware_uses_the_resolved_origins():
    assert _cors_middleware().kwargs["allow_origins"] == main.cors_origins


def test_credentials_track_whether_the_origin_list_is_explicit():
    """Browsers reject credentialed requests against "*", so claiming to allow
    them there would be a promise the middleware cannot keep."""
    expected = main.cors_origins != ["*"]

    assert _cors_middleware().kwargs["allow_credentials"] is expected
