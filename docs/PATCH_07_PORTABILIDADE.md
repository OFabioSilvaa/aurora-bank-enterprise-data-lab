# Patch 07 — Portabilidade

Este patch cria o domínio de Portabilidade no Aurora Bank V1, já no PostgreSQL.

## Tabelas criadas

### Silver

```text
silver.bancos_origem
silver.propostas_portabilidade
silver.contratos_portados
```

### SDX

```text
sdx.funil_portabilidade
sdx.portabilidade_cliente
sdx.cliente_360_v4
```

### Gold

```text
gold.kpi_portabilidade_mensal
gold.dw_portabilidade
```

### Meta

```text
meta.quality_portabilidade
```

## Como executar

No VSCode conectado ao PostgreSQL `aurora_bank`, rode:

```text
sql/postgres/03_create_portabilidade.sql
```

Depois teste:

```text
sql/postgres/04_test_portabilidade.sql
```

## Análises possíveis

- Conversão por banco de origem
- Taxa origem x taxa ofertada
- Ganho de taxa
- Troco liberado
- Motivo de perda
- Retenção pelo banco origem
- Portabilidade por canal
- Portabilidade por safra
- Cliente 360 com portabilidade

## Próxima etapa

Depois deste patch, seguimos para:

```text
Patch 08 — CRM e Campanhas
Patch 09 — Canais Digitais
Patch 10 — Cobrança
Patch 11 — Churn
Patch 12 — Gold Executivo
```
