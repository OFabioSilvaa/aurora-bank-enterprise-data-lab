# Patch 02 — Bronze para Silver Clientes

Este patch adiciona o script:

```text
scripts/02_create_bronze_silver_clientes.py
```

Ele faz o primeiro fluxo analítico real do projeto:

```text
Parquet Bronze -> DuckDB views Bronze -> tabelas Silver -> SDX cliente_360_base -> checks de qualidade
```

## Como aplicar

1. Baixe e extraia este ZIP.
2. Copie as pastas `scripts` e `sql` para dentro da pasta do projeto.
3. Aceite mesclar/substituir se o Windows perguntar.

## Como executar

Dentro da pasta do projeto:

```powershell
cd "D:\Banco de dados\aurora_bank_enterprise_v1_scaffold\aurora_bank_enterprise_v1"
```

Execute:

```powershell
python .\scripts\02_create_bronze_silver_clientes.py
```

## O que será criado

No banco:

```text
database/aurora_bank.duckdb
```

Serão criadas/atualizadas:

```text
bronze.raw_clientes_core
bronze.raw_clientes_app
bronze.raw_enderecos
bronze.raw_contatos
bronze.raw_scores_cliente
bronze.raw_segmentos_cliente

silver.clientes
silver.enderecos
silver.contatos
silver.scores_cliente_historico
silver.segmentos_cliente_historico

sdx.cliente_360_base

meta.contagem_tabelas_clientes
meta.quality_clientes
```

## Primeiras consultas

Depois de rodar o script, você poderá abrir o DuckDB no VSCode/DBeaver e consultar:

```sql
SELECT * FROM silver.clientes LIMIT 10;

SELECT * FROM sdx.cliente_360_base LIMIT 10;

SELECT * FROM meta.quality_clientes;
```
