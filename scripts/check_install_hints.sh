#!/usr/bin/env bash
# Fail if any pip/pipx install hint names a PyPI project that does not exist.
#
# An install name that nobody owns is a dependency-confusion vector: these hints
# are executed by an agent, so whoever registers the name first runs code on
# every machine that follows the skill. Pin to a git URL when a tool has no
# published release.
set -uo pipefail

ARSENAL="${1:-tools/external_arsenal.sh}"
fail=0

# Capture the token after "pip install" / "pipx install", allowing the full
# git+https://... form so it can be recognised and skipped rather than
# truncated to "git".
names=$(grep -ohE '(pip|pipx) install [^ |"]+' "$ARSENAL" \
          | awk '{print $3}' \
          | grep -v -e '^git+' -e '://' \
          | sort -u)

for n in $names; do
    code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 \
             "https://pypi.org/pypi/${n}/json" || true)
    case "$code" in
        200) printf 'ok         %s\n' "$n" ;;
        404) printf 'UNCLAIMED  %s  <- no such PyPI project; pin to a git URL\n' "$n"; fail=1 ;;
        *)   printf 'skipped    %s  (pypi.org returned %s)\n' "$n" "${code:-no response}" ;;
    esac
done

if [ "$fail" -ne 0 ]; then
    echo
    echo "One or more install hints name an unregistered PyPI project."
    echo "Replace each with 'pipx install git+https://github.com/<owner>/<repo>'"
    echo "or a clone, so the name cannot be claimed by someone else."
    exit 1
fi

echo
echo "All install hints resolve to existing PyPI projects."
