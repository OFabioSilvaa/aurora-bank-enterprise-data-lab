# Placeholder de criação do banco DuckDB

from pathlib import Path
import duckdb

DB_PATH = "database/aurora_bank.duckdb"

def main():
    Path("database").mkdir(exist_ok=True)
    con = duckdb.connect(DB_PATH)

    for schema in ["bronze", "silver", "sdx", "gold", "meta"]:
        con.execute(f"CREATE SCHEMA IF NOT EXISTS {schema};")

    con.close()
    print(f"Banco criado/validado em: {DB_PATH}")

if __name__ == "__main__":
    main()
