from __future__ import annotations

import argparse
import getpass
import os
import shutil
import sys
import time
from pathlib import Path

import duckdb
import psycopg

DUCKDB_PATH = Path("database") / "aurora_bank.duckdb"
EXPORT_DIR = Path("data") / "postgres_exports"
DEFAULT_SCHEMAS = ["silver", "sdx", "gold", "meta"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Migra tabelas do Aurora Bank DuckDB para PostgreSQL.")
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--user", default="postgres")
    parser.add_argument("--password", default=None)
    parser.add_argument("--database", default="aurora_bank")
    parser.add_argument("--create-db", action="store_true")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--include-bronze", action="store_true")
    parser.add_argument("--schemas", nargs="*", default=None)
    parser.add_argument("--keep-csv", action="store_true")
    return parser.parse_args()


def quote_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def get_password(args: argparse.Namespace) -> str:
    password = args.password or os.environ.get("PGPASSWORD")
    if password is None:
        password = getpass.getpass(f"Senha do PostgreSQL para usuário '{args.user}': ")
    return password


def pg_conn_kwargs(args: argparse.Namespace, database: str | None = None) -> dict:
    return {
        "host": args.host,
        "port": args.port,
        "user": args.user,
        "password": get_password(args),
        "dbname": database or args.database,
    }


def ensure_project_root() -> None:
    if not Path("README.md").exists() or not Path("scripts").exists():
        print("ERRO: execute dentro da pasta raiz do projeto.")
        print(r"Exemplo: cd D:\aurora_bank\aurora_bank_enterprise_v1")
        sys.exit(1)
    if not DUCKDB_PATH.exists():
        print(f"ERRO: banco DuckDB não encontrado: {DUCKDB_PATH}")
        sys.exit(1)


def create_database_if_needed(args: argparse.Namespace) -> None:
    if not args.create_db:
        return

    kwargs = pg_conn_kwargs(args, database="postgres")
    print(f"Verificando banco PostgreSQL '{args.database}'...")

    with psycopg.connect(**kwargs, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM pg_database WHERE datname = %s;", (args.database,))
            exists = cur.fetchone() is not None
            if exists:
                print(f"Banco '{args.database}' já existe.")
            else:
                cur.execute(f"CREATE DATABASE {quote_ident(args.database)};")
                print(f"Banco '{args.database}' criado.")


def map_duckdb_to_postgres(duck_type: str) -> str:
    t = (duck_type or "").upper()

    if "HUGEINT" in t or "UBIGINT" in t:
        return "NUMERIC"
    if "BIGINT" in t:
        return "BIGINT"
    if "INTEGER" in t or t == "INT":
        return "INTEGER"
    if "SMALLINT" in t or "TINYINT" in t:
        return "SMALLINT"
    if "DOUBLE" in t:
        return "DOUBLE PRECISION"
    if "FLOAT" in t or "REAL" in t:
        return "REAL"
    if "DECIMAL" in t or "NUMERIC" in t:
        return "NUMERIC"
    if "BOOLEAN" in t or t == "BOOL":
        return "BOOLEAN"
    if t == "DATE":
        return "DATE"
    if "TIMESTAMP" in t or "DATETIME" in t:
        return "TIMESTAMP"
    return "TEXT"


def get_duckdb_tables(con: duckdb.DuckDBPyConnection, schemas: list[str]) -> list[tuple[str, str, str]]:
    placeholders = ",".join(["?"] * len(schemas))
    rows = con.execute(
        f"""
        SELECT table_schema, table_name, table_type
        FROM information_schema.tables
        WHERE table_schema IN ({placeholders})
        ORDER BY table_schema, table_name;
        """,
        schemas,
    ).fetchall()
    return [(str(s), str(t), str(tt)) for s, t, tt in rows]


def get_duckdb_columns(con: duckdb.DuckDBPyConnection, schema: str, table: str) -> list[tuple[str, str]]:
    rows = con.execute(
        """
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = ?
          AND table_name = ?
        ORDER BY ordinal_position;
        """,
        [schema, table],
    ).fetchall()
    return [(str(c), str(t)) for c, t in rows]


def create_pg_schema(conn: psycopg.Connection, schema: str) -> None:
    with conn.cursor() as cur:
        cur.execute(f"CREATE SCHEMA IF NOT EXISTS {quote_ident(schema)};")


def create_pg_table(conn: psycopg.Connection, schema: str, table: str, columns: list[tuple[str, str]], overwrite: bool) -> None:
    full_name = f"{quote_ident(schema)}.{quote_ident(table)}"
    defs = [f"{quote_ident(col)} {map_duckdb_to_postgres(dtype)}" for col, dtype in columns]
    ddl = f"CREATE TABLE {full_name} (\n    " + ",\n    ".join(defs) + "\n);"

    with conn.cursor() as cur:
        if overwrite:
            cur.execute(f"DROP TABLE IF EXISTS {full_name} CASCADE;")
        cur.execute(ddl)


def export_duckdb_table_to_csv(con: duckdb.DuckDBPyConnection, schema: str, table: str, out_file: Path) -> None:
    out_file.parent.mkdir(parents=True, exist_ok=True)
    safe_path = out_file.as_posix().replace("'", "''")
    con.execute(f"""
        COPY (
            SELECT *
            FROM {quote_ident(schema)}.{quote_ident(table)}
        )
        TO '{safe_path}'
        WITH (HEADER, DELIMITER ',', QUOTE '"', ESCAPE '"');
    """)


def copy_csv_to_postgres(conn: psycopg.Connection, schema: str, table: str, csv_file: Path) -> int:
    full_name = f"{quote_ident(schema)}.{quote_ident(table)}"
    copy_sql = f"""
        COPY {full_name}
        FROM STDIN
        WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', QUOTE '"', ESCAPE '"', NULL '')
    """

    with conn.cursor() as cur:
        with cur.copy(copy_sql) as copy:
            with csv_file.open("rb") as f:
                while True:
                    data = f.read(1024 * 1024)
                    if not data:
                        break
                    copy.write(data)
        cur.execute(f"SELECT COUNT(*) FROM {full_name};")
        return int(cur.fetchone()[0])


def main() -> None:
    args = parse_args()
    ensure_project_root()

    schemas = args.schemas if args.schemas else DEFAULT_SCHEMAS.copy()
    if args.include_bronze and "bronze" not in schemas:
        schemas.insert(0, "bronze")

    print("Aurora Bank — Migração DuckDB -> PostgreSQL")
    print("=" * 80)
    print(f"DuckDB origem: {DUCKDB_PATH}")
    print(f"PostgreSQL destino: {args.host}:{args.port}/{args.database}")
    print(f"Schemas: {', '.join(schemas)}")
    print(f"Overwrite: {args.overwrite}")
    print("=" * 80)

    create_database_if_needed(args)

    duck = duckdb.connect(str(DUCKDB_PATH), read_only=True)
    pg_kwargs = pg_conn_kwargs(args)

    try:
        tables = get_duckdb_tables(duck, schemas)
        if not tables:
            print("Nenhuma tabela encontrada para migrar.")
            sys.exit(1)

        print("\nTabelas encontradas:")
        for schema, table, table_type in tables:
            print(f"- {schema}.{table} ({table_type})")

        if EXPORT_DIR.exists() and not args.keep_csv:
            shutil.rmtree(EXPORT_DIR)
        EXPORT_DIR.mkdir(parents=True, exist_ok=True)

        with psycopg.connect(**pg_kwargs) as pg:
            with pg.cursor() as cur:
                cur.execute("SET client_encoding TO 'UTF8';")

            for schema in schemas:
                create_pg_schema(pg, schema)
            pg.commit()

            for idx, (schema, table, table_type) in enumerate(tables, start=1):
                started = time.time()
                print("\n" + "-" * 80)
                print(f"[{idx}/{len(tables)}] Migrando {schema}.{table}")

                columns = get_duckdb_columns(duck, schema, table)
                create_pg_table(pg, schema, table, columns, overwrite=args.overwrite)
                pg.commit()

                csv_file = EXPORT_DIR / schema / f"{table}.csv"
                print("  Exportando DuckDB -> CSV...")
                export_duckdb_table_to_csv(duck, schema, table, csv_file)

                print("  Importando CSV -> PostgreSQL...")
                qtd = copy_csv_to_postgres(pg, schema, table, csv_file)
                pg.commit()

                with pg.cursor() as cur:
                    cur.execute(f"ANALYZE {quote_ident(schema)}.{quote_ident(table)};")
                pg.commit()

                elapsed = time.time() - started
                print(f"  OK: {qtd:,} linhas migradas em {elapsed:.1f}s".replace(",", "."))

                if not args.keep_csv:
                    try:
                        csv_file.unlink()
                    except FileNotFoundError:
                        pass

            print("\nMigração concluída com sucesso.")
            print("\nTeste rápido no PostgreSQL:")
            with pg.cursor() as cur:
                cur.execute("""
                    SELECT table_schema, table_name
                    FROM information_schema.tables
                    WHERE table_schema IN ('silver','sdx','gold','meta')
                    ORDER BY table_schema, table_name
                    LIMIT 30;
                """)
                for schema, table in cur.fetchall():
                    print(f"- {schema}.{table}")

    finally:
        duck.close()


if __name__ == "__main__":
    main()
