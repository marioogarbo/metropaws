"""migrate.py must do nothing until it is asked to.

It used to be 378 lines of top-level statements, so `import migrate` ran all 16
migrations against whatever database APP_ENV resolved to. That is the same shape
of hazard as the old prod-pointing .env, and this file exists to stop it coming
back.
"""
import ast
from pathlib import Path

from scripts import migrate

MIGRATE_SOURCE = Path(migrate.__file__)

# Declarations and the __main__ guard are inert on import; anything else runs.
INERT = (ast.Import, ast.ImportFrom, ast.FunctionDef, ast.ClassDef, ast.Assign, ast.AnnAssign)


def _statements_that_run_on_import() -> list[ast.stmt]:
    tree = ast.parse(MIGRATE_SOURCE.read_text(encoding="utf-8"))
    executable = []
    for node in tree.body:
        if isinstance(node, INERT):
            continue
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Constant):
            continue  # the module docstring
        if isinstance(node, ast.If) and _is_main_guard(node):
            continue
        executable.append(node)
    return executable


def _is_main_guard(node: ast.If) -> bool:
    test = node.test
    return (
        isinstance(test, ast.Compare)
        and isinstance(test.left, ast.Name)
        and test.left.id == "__name__"
    )


def test_importing_migrate_executes_nothing():
    """The whole point: importing must not touch a database."""
    assert _statements_that_run_on_import() == []


def test_every_migration_is_registered():
    """A step that isn't in MIGRATIONS never runs, and nothing would say so."""
    defined = {
        node.name
        for node in ast.parse(MIGRATE_SOURCE.read_text(encoding="utf-8")).body
        if isinstance(node, ast.FunctionDef) and not node.name.startswith("_")
    } - {"main"}
    registered = {step.__name__ for step in migrate.MIGRATIONS}

    assert defined == registered


def test_migrations_run_in_a_fixed_order():
    """Later steps assume columns earlier ones added, so this is a tuple, and
    tables are created before anything alters them."""
    assert isinstance(migrate.MIGRATIONS, tuple)
    assert migrate.MIGRATIONS[0] is migrate.create_new_tables


def test_no_migration_is_registered_twice():
    names = [step.__name__ for step in migrate.MIGRATIONS]

    assert len(names) == len(set(names))


def test_every_migration_explains_itself():
    """These get run by hand against production; each needs to say what it does."""
    undocumented = [step.__name__ for step in migrate.MIGRATIONS if not (step.__doc__ or "").strip()]

    assert undocumented == []
