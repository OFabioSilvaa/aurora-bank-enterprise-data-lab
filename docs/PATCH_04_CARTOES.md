# Patch 04 — Cartões, Compras, Faturas e Pagamentos

Este patch adiciona o domínio de cartão de crédito ao Aurora Bank.

## Scripts adicionados

```text
scripts/05_generate_bronze_cartoes.py
scripts/06_create_bronze_silver_cartoes.py
```

## Como aplicar

1. Extraia o ZIP.
2. Copie as pastas `scripts`, `sql` e `docs` para dentro da pasta do projeto.
3. Aceite mesclar/substituir.

## Ordem de execução

Dentro da pasta do projeto:

```powershell
python .\scripts\05_generate_bronze_cartoes.py --mode dev --overwrite
```

Depois:

```powershell
python .\scripts\06_create_bronze_silver_cartoes.py
```

## O que será criado

### Bronze

```text
bronze.raw_cartoes
bronze.raw_limites_cartao_historico
bronze.raw_compras_cartao
bronze.raw_faturas_cartao
bronze.raw_pagamentos_fatura
```

### Silver

```text
silver.cartoes
silver.limites_cartao_historico
silver.compras_cartao
silver.faturas_cartao
silver.pagamentos_fatura
```

### SDX

```text
sdx.comportamento_cartao
sdx.cliente_360_v2
```

### Gold

```text
gold.kpi_cartoes_mensal
gold.kpi_compras_cartao_mensal
```

### Meta

```text
meta.quality_cartoes
```

## Problemas de dados simulados

- cartão com limite nulo;
- limite outlier;
- compra duplicada por reprocessamento;
- compra com valor nulo;
- compra com valor negativo;
- fatura sem cartão;
- valor pago maior que fatura;
- pagamento mínimo;
- uso do rotativo;
- atraso de fatura.

## Primeiras análises possíveis

- limite concedido por produto;
- compras por categoria;
- faturas em atraso;
- uso do rotativo;
- pagamento mínimo;
- risco de cartão;
- Cliente 360 com comportamento de cartão;
- KPIs mensais para Power BI.
