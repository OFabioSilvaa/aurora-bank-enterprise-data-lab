# Patch 09 — Canais Digitais

Este patch cria o domínio de canais digitais no Aurora Bank V1.

## Tabelas criadas

### Silver

```text
silver.sessoes_digitais
silver.eventos_digitais
silver.erros_app
```

### SDX

```text
sdx.comportamento_digital_cliente
sdx.funil_digital
sdx.cliente_360_v6
```

### Gold

```text
gold.kpi_canais_digitais_mensal
gold.dw_canais_digitais
```

### Meta

```text
meta.quality_canais_digitais
```

## Como executar

No VSCode conectado ao PostgreSQL `aurora_bank`, rode:

```text
sql/postgres/07_create_canais_digitais.sql
```

Depois teste:

```text
sql/postgres/08_test_canais_digitais.sql
```

## Análises possíveis

- Sessões digitais por canal
- Funil de jornada digital
- Abandono de jornada
- Erros de app
- Taxa de conclusão
- Taxa de erro
- Clientes com fricção digital
- Cliente 360 com comportamento digital

## Próxima etapa

Depois deste patch:

```text
Patch 10 — Cobrança
Patch 11 — Churn
Patch 12 — Gold Executivo
```
