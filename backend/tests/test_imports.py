"""Every intra-package import must be written `app.<module>`.

The `app/` package move (commit 1bff552) left four imports addressing project
modules as though they were top-level — `from paw_points_utils import ...`,
`import invoice_utils`, `import paymongo`. All four sat INSIDE functions, so
nothing failed at import time, no test touched them, and the OpenAPI surface was
identical. They only raised when the code path ran, and one of them was
`_grant_plan` — the function that activates a plan after a member pays.

A static check is the right guard because the dynamic one is impractical: these
imports are function-local precisely to break circular-import cycles, so
importing every module cannot reach them.
"""
import ast
from pathlib import Path

import pytest

APP_DIR = Path(__file__).resolve().parent.parent / "app"


def _project_module_names() -> set[str]:
    """Top-level names that live inside app/ — the ones that must be qualified."""
    names = set()
    for path in APP_DIR.iterdir():
        if path.is_dir() and (path / "__init__.py").is_file():
            names.add(path.name)
        elif path.suffix == ".py" and path.stem != "__init__":
            names.add(path.stem)
    for path in (APP_DIR / "domain").glob("*.py"):
        if path.stem != "__init__":
            names.add(path.stem)
    return names


def _unqualified_imports(source: str, project_modules: set[str]) -> list[str]:
    offenders = []
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.ImportFrom):
            # Relative imports are already package-anchored.
            if node.level or not node.module:
                continue
            root = node.module.split(".")[0]
            if root in project_modules:
                offenders.append(f"line {node.lineno}: from {node.module} import ...")
        elif isinstance(node, ast.Import):
            for alias in node.names:
                root = alias.name.split(".")[0]
                if root in project_modules:
                    offenders.append(f"line {node.lineno}: import {alias.name}")
    return offenders


@pytest.mark.parametrize(
    "source_file",
    sorted(APP_DIR.rglob("*.py")),
    ids=lambda path: str(path.relative_to(APP_DIR)),
)
def test_project_imports_are_qualified_with_the_app_package(source_file):
    project_modules = _project_module_names()
    offenders = _unqualified_imports(
        source_file.read_text(encoding="utf-8"), project_modules
    )

    assert not offenders, (
        f"{source_file.relative_to(APP_DIR)} imports a project module without the "
        f"`app.` prefix, which raises only when that line runs: {offenders}"
    )
