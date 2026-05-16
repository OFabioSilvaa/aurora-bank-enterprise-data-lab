from pathlib import Path
import sys

try:
    import duckdb
    import pandas as pd
    import pyarrow
    import yaml
    import faker
except Exception as e:
    print("Erro ao importar dependências:")
    print(e)
    print("\nRode: pip install -r requirements.txt")
    sys.exit(1)

required_dirs = [
    "data/bronze",
    "data/silver",
    "data/sdx",
    "data/gold",
    "data/exports_excel",
    "database",
    "sql",
    "docs",
    "tasks",
]

print("Aurora Bank Enterprise Data Lab — Check do ambiente")
print("=" * 60)

for d in required_dirs:
    path = Path(d)
    print(f"{'OK' if path.exists() else 'FALTANDO'} - {d}")

print("\nDependências principais importadas com sucesso.")
print(f"DuckDB version: {duckdb.__version__}")
print(f"Pandas version: {pd.__version__}")
print("\nAmbiente pronto para iniciar a construção.")
