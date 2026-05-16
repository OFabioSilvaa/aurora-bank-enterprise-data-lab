# Patch 10 — Cobrança

Este patch cria o domínio de cobrança no Aurora Bank V1.

## Tabelas criadas

### Silver

```text
silver.acionamentos_cobranca
silver.acordos_cobranca
silver.pagamentos_acordo
```

### SDX

```text
sdx.cobranca_cliente
sdx.cliente_360_v7
```

### Gold

```text
gold.kpi_cobranca_mensal
gold.dw_cobranca
```

### Meta

```text
meta.quality_cobranca
```

## Como executar

No VSCode conectado ao PostgreSQL `aurora_bank`, rode:

```text
sql/postgres/09_create_cobranca.sql
```

Depois teste:

```text
sql/postgres/10_test_cobranca.sql
```

## Análises possíveis

- Acionamentos por carteira
- Eficiência de cobrança por canal
- Acordos gerados
- Acordos cumpridos e quebrados
- Recuperação financeira
- Clientes difíceis de contato
- Cliente 360 com cobrança
- Risco de cobrança

## Próxima etapa

Depois deste patch:

```text
Patch 11 — Churn
Patch 12 — Gold Executivo
Patch 13 — Teste Geral e Documentação V1
```
