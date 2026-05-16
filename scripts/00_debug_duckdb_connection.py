"""
Aurora Bank Enterprise Data Lab
Debug de conexão DuckDB

Execute dentro da pasta do projeto:

    python .\scripts\00_debug_duckdb_connection.py

Este script verifica:
1. Se você está na pasta correta do projeto
2. Se o arquivo database/aurora_bank.duckdb existe
3. Se o DuckDB consegue abrir o banco
4. Quais schemas/tabelas existem
5. Algumas contagens básicas
"""

from pathlib import Path
import sys

try:
    import duckdb
except Exception as e:
    print("ERRO: DuckDB não está instalado ou não foi encontrado.")
    print("Detalhe:", e)
    print("\nRode:")
    print("python -m pip install duckdb")
    sys.exit(1)


DB_PATH = Path("database") / "aurora_bank.duckdb"


def print_header(title: str) -> None:
    print("\n" + "=" * 70)
    print(title)
    print("=" * 70)


def main() -> None:
    print_header("Aurora Bank — Debug de Conexão DuckDB")

    print("Pasta atual:")
    print(Path.cwd())

    print("\nVerificando arquivos principais:")
    checks = [
        Path("README.md"),
        Path("requirements.txt"),
        Path("scripts"),
        Path("database"),
        DB_PATH,
    ]

    for item in checks:
        status = "OK" if item.exists() else "NÃO ENCONTRADO"
        print(f"- {item}: {status}")

    if not Path("README.md").exists() or not Path("scripts").exists():
        print("\nERRO: você provavelmente não está dentro da pasta raiz do projeto.")
        print("Entre nesta pasta antes de rodar:")
        print(r'D:\Banco de dados\aurora_bank_enterprise_v1_scaffold\aurora_bank_enterprise_v1')
        sys.exit(1)

    if not DB_PATH.exists():
        print("\nERRO: o arquivo do banco ainda não existe:")
        print(DB_PATH)
        print("\nTente rodar:")
        print(r"python .\scripts\02_create_bronze_silver_clientes.py")
        print("\nOu:")
        print(r"python .\scripts\02_create_database_placeholder.py")
        sys.exit(1)

    print_header("Abrindo banco DuckDB")

    try:
        con = duckdb.connect(str(DB_PATH))
    except Exception as e:
        print("ERRO ao abrir o banco DuckDB.")
        print("Detalhe:", e)
        sys.exit(1)

    print("Conexão aberta com sucesso.")
    print("DuckDB version:", duckdb.__version__)

    print_header("Schemas e tabelas existentes")

    try:
        tables = con.execute("""
            SELECT
                table_schema,
                table_name,
                table_type
            FROM information_schema.tables
            WHERE table_schema IN ('bronze', 'silver', 'sdx', 'gold', 'meta')
            ORDER BY table_schema, table_name;
        """).fetchall()

        if not tables:
            print("Nenhuma tabela encontrada nos schemas bronze/silver/sdx/gold/meta.")
            print("Isso indica que o banco existe, mas as camadas ainda não foram criadas.")
        else:
            for schema, table, table_type in tables:
                print(f"- {schema}.{table} ({table_type})")

    except Exception as e:
        print("ERRO ao listar tabelas.")
        print("Detalhe:", e)

    print_header("Contagens rápidas")

    candidate_tables = [
        "silver.clientes",
        "silver.contas",
        "silver.transacoes",
        "sdx.cliente_360",
        "sdx.cliente_360_base",
        "gold.kpi_transacoes_mensal",
        "meta.quality_clientes",
        "meta.quality_contas_transacoes",
    ]

    for table in candidate_tables:
        try:
            qtd = con.execute(f"SELECT COUNT(*) FROM {table};").fetchone()[0]
            print(f"- {table}: {qtd:,}".replace(",", "."))
        except Exception:
            print(f"- {table}: não existe ainda")

    print_header("Teste final")

    try:
        result = con.execute("SELECT 'conexao_ok' AS status;").fetchall()
        print(result)
        print("\nTudo certo: o Python conseguiu abrir o banco.")
        print("Se a extensão do VSCode ainda não conectar, o problema está na configuração da extensão/caminho do arquivo.")
    finally:
        con.close()


if __name__ == "__main__":
    main()
