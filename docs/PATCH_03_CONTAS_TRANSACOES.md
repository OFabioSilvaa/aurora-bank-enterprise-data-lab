# Patch 03 — Contas e Transações

Este patch adiciona o primeiro domínio financeiro do Aurora Bank.

## Scripts adicionados

```text
scripts/03_generate_bronze_contas_transacoes.py
scripts/04_create_bronze_silver_contas_transacoes.py
```

## Como aplicar

1. Extraia o ZIP.
2. Copie as pastas `scripts`, `sql` e `docs` para dentro da pasta do projeto.
3. Aceite mesclar/substituir.

## Ordem de execução

Dentro da pasta do projeto:

```powershell
python .\scripts\03_generate_bronze_contas_transacoes.py --mode dev --overwrite
```

Depois:

```powershell
python .\scripts\04_create_bronze_silver_contas_transacoes.py
```

## O que será criado

### Bronze

```text
bronze.raw_contas
bronze.raw_transacoes
```

### Silver

```text
silver.contas
silver.transacoes
```

### SDX

```text
sdx.atividade_cliente
sdx.cliente_360
```

### Gold

```text
gold.kpi_transacoes_mensal
```

### Meta

```text
meta.quality_contas_transacoes
```

## Problemas de dados simulados

- contas sem cliente válido;
- saldos nulos;
- saldos outliers;
- transações duplicadas por reprocessamento;
- transações com valor nulo;
- transações com valor negativo;
- transações com data futura;
- status cancelado/negado/pendente;
- diferenças entre transação bruta e transação válida financeira.

## Primeiras análises possíveis

- clientes ativos transacionais;
- volume por mês;
- volume por canal;
- PIX enviado/recebido;
- contas por tipo;
- saldo por tipo de conta;
- risco inicial de churn;
- qualidade de dados de transações.
