# Patch 11 — Churn

Este patch cria a camada de churn/risco de evasão do Aurora Bank V1.

## Tabelas criadas

### SDX

```text
sdx.churn_features
sdx.cliente_360_v8
```

### Gold

```text
gold.dw_churn
gold.kpi_churn_mensal
```

### Meta

```text
meta.quality_churn
```

## Como executar

No VSCode conectado ao PostgreSQL `aurora_bank`, rode:

```text
sql/postgres/11_create_churn.sql
```

Depois teste:

```text
sql/postgres/12_test_churn.sql
```

## Regras consideradas

O score de churn combina:

- inatividade transacional
- inatividade digital
- cancelamento/risco em cartão
- atraso e risco de crédito
- cobrança e acordo quebrado
- fricção digital
- baixo engajamento em CRM
- status de cliente
- força de relacionamento

## Análises possíveis

- clientes com risco de churn
- churn por segmento
- churn por faixa de risco
- ações recomendadas de retenção
- clientes críticos
- churn cruzado com cobrança, digital e CRM

## Próxima etapa

Depois deste patch:

```text
Patch 12 — Gold Executivo
Patch 13 — Teste Geral e Documentação V1
```
