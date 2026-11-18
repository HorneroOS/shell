#!/usr/bin/env bash
# Shell UI translations (docs/I18N.md): refresh or check the Qt Linguist
# catalogs in i18n/ from every qsTr() in the runtime QML/JS tree.
#
#   scripts/i18n_update.sh          # update i18n/hornero_*.ts in place
#   scripts/i18n_update.sh --check  # fail if a catalog is stale (CI)
#
# Uses the Qt 6 lupdate (Qt 5 lupdate cannot parse Qt 6 QML). Locations are
# omitted so unrelated edits do not churn the catalog; the context (file
# name) and the source text identify each message.
set -euo pipefail
cd "$(dirname "$0")/.."

mode="update"
case "${1:-}" in
    "") ;;
    --check) mode="check" ;;
    -h | --help)
        sed -n '2,10p' "$0"
        exit 0
        ;;
    *)
        echo "i18n: unknown argument: $1" >&2
        exit 2
        ;;
esac

override="${LUPDATE:-}"
LUPDATE=""
for cand in "$override" /usr/lib/qt6/bin/lupdate /usr/lib/qt6/libexec/lupdate "$(command -v lupdate6 || true)" "$(command -v lupdate || true)"; do
    if [ -n "$cand" ] && [ -x "$cand" ] && "$cand" -version 2>/dev/null | grep -q 'lupdate version 6\.'; then
        LUPDATE="$cand"
        break
    fi
done
if [ -z "$LUPDATE" ]; then
    echo "i18n: Qt 6 lupdate not found (install qt6-tools / qt6-l10n-tools)" >&2
    exit 2
fi

# Runtime tree only: PluginKit and examples use per-plugin JSON catalogs
# (docs/PLUGINS.md); reloadcover is a separate process without a translator.
sources=(shell.qml lock.qml components config modules services utils)

run_lupdate() {
    "$LUPDATE" -silent -source-language en -extensions qml,js -locations none -no-obsolete "${sources[@]}" -ts "$@"
}

catalogs=(i18n/hornero_*.ts)
if [ ! -e "${catalogs[0]}" ]; then
    echo "i18n: no catalogs in i18n/" >&2
    exit 2
fi

if [ "$mode" = "update" ]; then
    run_lupdate "${catalogs[@]}"
    echo "i18n: updated ${catalogs[*]}"
    exit 0
fi

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
stale=0
for ts in "${catalogs[@]}"; do
    copy="$scratch/$(basename "$ts")"
    cp "$ts" "$copy"
    run_lupdate "$copy"
    # Compare messages, not bytes: lupdate versions differ in formatting.
    if ! python3 - "$ts" "$copy" <<'PY'; then
import sys
import xml.etree.ElementTree as ET


def keys(path):
    out = set()
    for ctx in ET.parse(path).getroot().iter("context"):
        for msg in ctx.iter("message"):
            tr = msg.find("translation")
            if tr is not None and tr.get("type") in ("vanished", "obsolete"):
                continue
            out.add((ctx.findtext("name"), msg.findtext("source"), msg.findtext("comment") or "", msg.get("numerus") == "yes"))
    return out


have, want = keys(sys.argv[1]), keys(sys.argv[2])
for label, items in (("missing", want - have), ("dead", have - want)):
    for item in sorted(items)[:30]:
        print(f"  {label}: {item[0]}: {item[1]!r}", file=sys.stderr)
sys.exit(0 if have == want else 1)
PY
        echo "i18n: $ts is stale; run scripts/i18n_update.sh and translate the new strings (docs/I18N.md)" >&2
        stale=1
    fi
done
if [ "$stale" -ne 0 ]; then
    exit 1
fi
echo "i18n: ${#catalogs[@]} catalog(s) up to date"
