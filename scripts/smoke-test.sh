#!/usr/bin/env bash
# Generates an app and a lib from the working tree and runs acceptance checks 1-3 on each.
# Usage: [PYTHON_VERSION=3.X] scripts/smoke-test.sh [output-dir]
#   output-dir      default: a fresh temporary directory
#   PYTHON_VERSION  overrides the template's default python_version, for machines that lack it
set -euo pipefail

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$(mktemp -d)}"
COPIER="$TEMPLATE_DIR/.venv/bin/copier"

# NOTE: an active venv (e.g. from `poetry run`) would make the generated project's Poetry install into it.
unset VIRTUAL_ENV

step() { printf '\n==> %s\n' "$*"; }

check_idea() {
  local project="$1"
  # NOTE: the generated venv's python parses XML, so the check needs nothing beyond the project itself.
  "$project/.venv/bin/python" - "$project/.idea" <<'EOF'
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

ABSOLUTE_PATH = re.compile(r'(?<![$\w])(/(home|Users|usr|opt|tmp|var)/|[A-Za-z]:\\)')
idea = pathlib.Path(sys.argv[1])
expected = [
    f"{idea.parent.name}.iml",
    "modules.xml",
    "watcherTasks.xml",
    *(f"runConfigurations/{name}.xml" for name in ("ruff_format", "ruff_check", "mypy", "pytest_debug", "pytest_all")),
]
errors = [f"{idea / name}: missing" for name in expected if not (idea / name).is_file()]
for path in sorted(idea.rglob("*.xml")) + sorted(idea.glob("*.iml")):
    text = path.read_text()
    try:
        root = ET.fromstring(text)
    except ET.ParseError as err:
        errors.append(f"{path}: malformed XML: {err}")
        continue
    if ABSOLUTE_PATH.search(text):
        errors.append(f"{path}: contains an absolute path")
    for option in root.iter("option"):
        if option.get("name") == "SDK_HOME" and option.get("value"):
            errors.append(f"{path}: SDK_HOME has a value")
    if root.find(".//orderEntry[@type='jdk']") is not None:
        errors.append(f"{path}: pins an interpreter (orderEntry type=jdk)")
if errors:
    sys.exit("\n".join(errors))
EOF
}

smoke() {
  local project_type="$1"
  local name="demo-$project_type"
  local project="$OUT_DIR/$name"
  local package="${name//-/_}"

  step "[$project_type] copier copy -> $project"
  (cd "$TEMPLATE_DIR" && "$COPIER" copy --trust --defaults --vcs-ref HEAD \
    --data project_type="$project_type" \
    --data project_name="$name" \
    --data author_name="Smoke Test" \
    --data author_email="smoke@example.com" \
    --data github_repository="example/$name" \
    ${PYTHON_VERSION:+--data python_version="$PYTHON_VERSION"} \
    . "$project")

  step "[$project_type] environment"
  test -d "$project/.venv" || { echo ".venv/ is missing"; exit 1; }
  test -f "$project/poetry.lock" || { echo "poetry.lock is missing"; exit 1; }

  step "[$project_type] example module and test (imports through pythonpath)"
  cat > "$project/src/$package/greeting.py" <<EOF
def greet(name: str) -> str:
    return f"Hello, {name}!"
EOF
  cat > "$project/tests/test_greeting.py" <<EOF
from $package.greeting import greet


def test_greet() -> None:
    assert greet("world") == "Hello, world!"
EOF

  step "[$project_type] checks"
  (
    cd "$project"
    poetry run ruff check
    poetry run ruff format --check
    poetry run mypy
    poetry run pytest
    if [[ "$project_type" == lib ]]; then
      poetry run nox -s ruff mypy pytest
    fi
  )

  step "[$project_type] .idea files"
  check_idea "$project"

  rm "$project/src/$package/greeting.py" "$project/tests/test_greeting.py"
}

smoke app
smoke lib
step "OK: smoke tests passed ($OUT_DIR)"
