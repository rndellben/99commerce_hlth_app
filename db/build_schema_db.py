"""Build an empty inspection .db from schema.sql.

Run from this directory:
    python build_schema_db.py

Produces hlth_app_schema.db — an empty SQLite file with every table and
index defined. Open it in DB Browser for SQLite to inspect the schema
visually. The file contains NO user data — it's a structural mirror.

The runtime database that the app actually uses is the drift-managed
file at the platform-specific application-support directory (named
`hlth_app.sqlite`), created on first access by
lib/core/database/app_database.dart. The Dart code is the source of
truth; this file is just a read-friendly mirror.
"""

import os
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA_SQL = os.path.join(HERE, "schema.sql")
OUT_DB = os.path.join(HERE, "hlth_app_schema.db")


def main() -> int:
    if not os.path.exists(SCHEMA_SQL):
        print(f"missing {SCHEMA_SQL}", file=sys.stderr)
        return 1

    # Start clean so the build is reproducible.
    if os.path.exists(OUT_DB):
        os.remove(OUT_DB)

    with open(SCHEMA_SQL, "r", encoding="utf-8") as f:
        sql = f.read()

    conn = sqlite3.connect(OUT_DB)
    try:
        conn.executescript(sql)
        conn.commit()
    finally:
        conn.close()

    # Report what landed.
    conn = sqlite3.connect(OUT_DB)
    cur = conn.execute(
        "SELECT type, name FROM sqlite_master "
        "WHERE name NOT LIKE 'sqlite_%' "
        "ORDER BY type, name"
    )
    tables, indices = [], []
    for kind, name in cur:
        (tables if kind == "table" else indices).append(name)
    conn.close()

    print(f"Built {OUT_DB}")
    print(f"  {len(tables)} tables: {', '.join(tables)}")
    print(f"  {len(indices)} indices: {', '.join(indices)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
