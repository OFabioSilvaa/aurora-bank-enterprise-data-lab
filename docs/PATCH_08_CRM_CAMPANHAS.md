# Patch 08 — CRM e Campanhas

Este patch cria o domínio de CRM e Marketing no Aurora Bank V1.

## Tabelas criadas

### Silver

```text
silver.campanhas_crm
silver.ofertas_crm
silver.interacoes_crm
silver.conversoes_crm
```

### SDX

```text
sdx.crm_cliente
sdx.segmentacao_crm
sdx.cliente_360_v5
```

### Gold

```text
gold.kpi_crm_campanhas
gold.dw_crm
```

### Meta

```text
meta.quality_crm
```

## Como executar

No VSCode conectado ao PostgreSQL `aurora_bank`, rode:

```text
sql/postgres/05_create_crm_campanhas.sql
```

Depois teste:

```text
sql/postgres/06_test_crm_campanhas.sql
```

## Análises possíveis

- ROI de campanha
- Taxa de entrega
- Taxa de abertura
- Taxa de clique
- Taxa de conversão
- Clientes impactados
- Clientes convertidos
- Próxima melhor ação
- Segmentação CRM
- Cliente 360 com CRM

## Próxima etapa

Depois deste patch:

```text
Patch 09 — Canais Digitais
Patch 10 — Cobrança
Patch 11 — Churn
Patch 12 — Gold Executivo
```
