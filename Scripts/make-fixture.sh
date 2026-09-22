#!/bin/bash
# Rebuilds the fictional test fixture from Scripts/fixture.sql.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/KeystripCore/Tests/KeystripCoreTests/Fixtures/sample.dsi"
rm -f "$OUT"
sqlite3 "$OUT" < "$ROOT/Scripts/fixture.sql"
[ "$(sqlite3 "$OUT" 'PRAGMA integrity_check;')" = "ok" ]
[ "$(sqlite3 "$OUT" 'PRAGMA encoding;')" = "UTF-16le" ]
echo "wrote $OUT"
