# Patch 05 — Crédito

Este patch adiciona o domínio de crédito ao Aurora Bank.

## Scripts adicionados

```text
scripts/07_generate_bronze_credito.py
scripts/08_create_bronze_silver_credito.py
```

## Como aplicar

1. Extraia o ZIP.
2. Copie as pastas `scripts`, `sql` e `docs` para dentro da pasta do projeto.
3. Aceite mesclar/substituir.

## Ordem de execução

Dentro da pasta do projeto:

```powershell
python .\scripts\07_generate_bronze_credito.py --mode dev --overwrite
```

Depois:

```powershell
python .\scripts\08_create_bronze_silver_credito.py
```

Depois teste:

```powershell
python .\scripts\run_sql_file.py .\sql\06_studies\consultas_credito.sql
```

## O que será criado

### Bronze

```text
bronze.raw_propostas_credito
bronze.raw_contratos_credito
bronze.raw_parcelas_credito
bronze.raw_pagamentos_credito
bronze.raw_politicas_credito
bronze.raw_politicas_precificacao
bronze.raw_renegociacoes
```

### Silver

```text
silver.propostas_credito
silver.contratos_credito
silver.parcelas_credito
silver.pagamentos_credito
silver.politicas_credito
silver.politicas_precificacao
silver.renegociacoes
```

### SDX

```text
sdx.funil_credito
sdx.precificacao_credito
sdx.risco_credito_cliente
sdx.cliente_360_v3
```

### Gold

```text
gold.kpi_carteira_credito_mensal
gold.kpi_inadimplencia_credito_mensal
```

### Meta

```text
meta.quality_credito
```

## Problemas de dados simulados

- proposta com score nulo;
- proposta com data futura;
- contrato com data de contratação antes da proposta;
- contrato com saldo negativo;
- parcela sem contrato;
- pagamento maior que parcela;
- contrato renegociado;
- inadimplência e NPL 90+.

## Primeiras análises possíveis

- funil de crédito;
- taxa de aprovação;
- motivo de recusa;
- carteira por produto;
- inadimplência;
- NPL 90+;
- análise por safra;
- aderência de taxa à política;
- Cliente 360 com crédito.
