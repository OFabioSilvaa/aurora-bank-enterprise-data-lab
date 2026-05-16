# Patch 12 — Gold Executivo

Este patch cria a camada executiva final da V1 do Aurora Bank.

## Tabelas criadas

```text
gold.kpi_executivo_banco
gold.visao_executiva_cliente
gold.dashboard_base_executiva
gold.kpi_produtos_executivo
gold.kpi_risco_executivo
meta.quality_gold_executivo
```

## Como executar

No VSCode conectado ao PostgreSQL `aurora_bank`, rode:

```text
sql/postgres/13_create_gold_executivo.sql
```

Depois teste:

```text
sql/postgres/14_test_gold_executivo.sql
```

## Objetivo

Consolidar a V1 em tabelas de consumo executivo para:

- Power BI
- Excel
- análise gerencial
- demandas simuladas
- visão 360 por cliente
- KPIs de banco
- risco, churn e produtos

## Principais tabelas

### gold.kpi_executivo_banco

Uma linha com os principais KPIs do banco.

### gold.visao_executiva_cliente

Uma linha por cliente com dados consolidados de:

- contas
- transações
- cartões
- crédito
- portabilidade
- CRM
- digital
- cobrança
- churn

### gold.dashboard_base_executiva

Base agregada para dashboard executivo.

### gold.kpi_produtos_executivo

KPIs por domínio/produto.

### gold.kpi_risco_executivo

KPIs por risco, churn, cobrança, digital e CRM.

## Próxima etapa

Depois deste patch:

```text
Patch 13 — Teste Geral e Documentação V1
Primeira demanda simulada de gestor
```
