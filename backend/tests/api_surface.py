"""The app's route table, derived from its OpenAPI schema.

Not from `app.routes`. That attribute is an internal representation and it
changed shape in FastAPI 0.141: included routers became `_IncludedRouter`
placeholders, so enumerating it returned the app's own handlers and nothing
else. The failure mode was quiet — parametrised tests built from it simply
generated zero cases, and the suite went from 333 tests to 209 while still
reporting success for everything it did run.

The OpenAPI schema is the published contract, it is what every client sees, and
it survives version bumps.
"""

# FastAPI serves these itself and they are absent from the schema, so they have
# to be named. They are part of the unauthenticated surface either way.
DOCS_ROUTES = frozenset(
    {
        "GET /openapi.json",
        "GET /docs",
        "GET /docs/oauth2-redirect",
        "GET /redoc",
    }
)


def route_table(app) -> list[str]:
    """Every documented operation as "METHOD /path", sorted.

    HEAD is dropped: Starlette adds it alongside GET and it is never declared.
    """
    schema = app.openapi()
    return sorted(
        f"{method.upper()} {path}"
        for path, operations in schema["paths"].items()
        for method in operations
        if method.upper() != "HEAD"
    )


def routes_under(app, prefix: str) -> list[tuple[str, str]]:
    """(method, path) for every documented operation under `prefix`."""
    return sorted(
        (entry.split(" ", 1)[0], entry.split(" ", 1)[1])
        for entry in route_table(app)
        if entry.split(" ", 1)[1].startswith(prefix)
    )
