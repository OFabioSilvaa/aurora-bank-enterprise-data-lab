# Patch Debug — Conexão DuckDB

Este patch adiciona scripts simples para validar o banco sem depender da extensão do VSCode.

## Arquivos adicionados

```text
scripts/00_debug_duckdb_connection.py
scripts/run_sql_file.py
sql/06_studies/teste_conexao.sql
```

## Como aplicar

1. Extraia este ZIP.
2. Copie as pastas `scripts` e `sql` para dentro da pasta do projeto:

```text
D:\Banco de dados\aurora_bank_enterprise_v1_scaffold\aurora_bank_enterprise_v1
```

3. Aceite mesclar/substituir se o Windows perguntar.

## Como testar

Dentro da pasta do projeto, rode:

```powershell
python .\scripts\00_debug_duckdb_connection.py
```

Se funcionar, rode:

```powershell
python .\scripts\run_sql_file.py .\sql\06_studies\teste_conexao.sql
```
