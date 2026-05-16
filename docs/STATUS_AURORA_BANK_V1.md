# Aurora Bank Enterprise Data Lab — Status da V1

## Status geral

A **V1 do Aurora Bank Enterprise Data Lab** está funcional.

Esta versão simula um ambiente analítico bancário com foco em:

- SQL
- Excel
- Power BI
- Engenharia de Dados
- Ciência de Dados
- Regras de negócio bancário
- Cliente 360
- Análise executiva

## Banco principal de consulta

A partir da migração, o banco principal para consulta é:

```text
PostgreSQL
Database: aurora_bank
Schemas: silver, sdx, gold, meta
```

O DuckDB permanece como origem/gerador/lakehouse local.

## Domínios construídos

```text
Clientes
Contas
Transações
Cartões
Crédito
DW Contratação
Portabilidade
CRM e Campanhas
Canais Digitais
Cobrança
Churn
Gold Executivo
```

## Camadas

### Silver

Camada tratada e padronizada.

Principais tabelas:

```text
silver.clientes
silver.contas
silver.transacoes
silver.cartoes
silver.compras_cartao
silver.faturas_cartao
silver.propostas_credito
silver.contratos_credito
silver.parcelas_credito
silver.propostas_portabilidade
silver.campanhas_crm
silver.ofertas_crm
silver.sessoes_digitais
silver.acionamentos_cobranca
```

### SDX

Camada semântica/analítica.

Principais tabelas:

```text
sdx.cliente_360_v8
sdx.funil_credito
sdx.precificacao_credito
sdx.risco_credito_cliente
sdx.portabilidade_cliente
sdx.crm_cliente
sdx.segmentacao_crm
sdx.comportamento_digital_cliente
sdx.cobranca_cliente
sdx.churn_features
```

### Gold

Camada de consumo e BI.

Principais tabelas:

```text
gold.dw_contratacao
gold.dw_portabilidade
gold.dw_crm
gold.dw_canais_digitais
gold.dw_cobranca
gold.dw_churn
gold.kpi_executivo_banco
gold.visao_executiva_cliente
gold.dashboard_base_executiva
gold.kpi_produtos_executivo
gold.kpi_risco_executivo
```

### Meta

Camada de qualidade.

Principais tabelas:

```text
meta.quality_clientes
meta.quality_contas_transacoes
meta.quality_cartoes
meta.quality_credito
meta.quality_dw_contratacao
meta.quality_portabilidade
meta.quality_crm
meta.quality_canais_digitais
meta.quality_cobranca
meta.quality_churn
meta.quality_gold_executivo
```

## Tabela principal para análise

A tabela mais completa para análise geral é:

```text
gold.visao_executiva_cliente
```

Ela consolida:

- dados cadastrais
- relacionamento
- conta/transações
- cartão
- crédito
- portabilidade
- CRM
- canais digitais
- cobrança
- churn
- risco

## Tabela principal para visão Cliente 360

```text
sdx.cliente_360_v8
```

## Tabela principal para dashboard executivo

```text
gold.dashboard_base_executiva
```

## Tabela principal para KPIs gerais

```text
gold.kpi_executivo_banco
```

## Próximos passos pós-V1

```text
1. Rodar teste geral da V1
2. Criar dashboards Power BI
3. Criar exportações Excel
4. Criar demandas simuladas de gestor
5. Criar automações de relatório
6. Evoluir para V2 com investimentos, seguros, consórcio, imobiliário e fraude/KYC
```
