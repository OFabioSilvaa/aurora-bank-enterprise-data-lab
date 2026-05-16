# Patch — Migração DuckDB para PostgreSQL

Este patch espelha as tabelas analíticas do Aurora Bank do DuckDB para PostgreSQL.

## Objetivo

Usar o PostgreSQL como banco principal de trabalho no VSCode, com autocomplete e conexão mais estável.

O DuckDB continua como origem/gerador local.

## Arquivos adicionados

```text
requirements_postgres.txt
scripts/09_migrate_duckdb_to_postgres.py
sql/postgres/teste_postgres.sql
```

## Como aplicar

Extraia este ZIP e copie os arquivos/pastas para:

```text
D:\aurora_bank\aurora_bank_enterprise_v1
```

## Instalar dependência

Dentro da pasta do projeto:

```powershell
python -m pip install -r requirements_postgres.txt
```

## Rodar migração

Use o usuário/senha do PostgreSQL configurado na instalação:

```powershell
python .\scripts\09_migrate_duckdb_to_postgres.py --host localhost --port 5432 --user postgres --database aurora_bank --create-db --overwrite
```

O script pedirá a senha.

## O que será migrado por padrão

```text
silver
sdx
gold
meta
```

A camada `bronze` fica no DuckDB/Parquet por enquanto.

## Se quiser incluir Bronze

```powershell
python .\scripts\09_migrate_duckdb_to_postgres.py --host localhost --port 5432 --user postgres --database aurora_bank --create-db --overwrite --include-bronze
```

## Depois conectar no VSCode

Use uma extensão PostgreSQL/SQLTools:

```text
Host: localhost
Port: 5432
Database: aurora_bank
User: postgres
Password: sua senha
```

Teste:

```sql
SELECT COUNT(*) FROM silver.clientes;
```
