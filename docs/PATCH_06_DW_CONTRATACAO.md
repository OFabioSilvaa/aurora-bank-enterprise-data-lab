# Patch 06 — DW Contratação

Este patch cria a tabela:

```text
gold.dw_contratacao
```

Ela foi desenhada para simular uma tabela corporativa real de contratação usada em banco.

## Por que essa tabela existe

No mundo real, analistas nem sempre trabalham diretamente com tabelas totalmente normalizadas. Muitas vezes existem tabelas flat de DW com campos como:

```text
num_pes
ctr_numero
lc_cod
produto
subproduto
canal
origem
flg_apto_renovacao
flg_renovacao
flg_inadimplente
flg_npl_90
```

A `gold.dw_contratacao` cria esse padrão dentro do Aurora Bank.

## Arquivos

```text
sql/postgres/01_create_dw_contratacao.sql
sql/postgres/02_test_dw_contratacao.sql
docs/PATCH_06_DW_CONTRATACAO.md
```

## Como executar

No VSCode conectado ao PostgreSQL `aurora_bank`, rode primeiro:

```text
sql/postgres/01_create_dw_contratacao.sql
```

Depois rode:

```text
sql/postgres/02_test_dw_contratacao.sql
```

## Tabelas de origem

```text
silver.clientes
silver.propostas_credito
silver.contratos_credito
silver.parcelas_credito
```

## Tabelas criadas

```text
gold.dw_contratacao
meta.quality_dw_contratacao
```

## Uso analítico

A tabela permite responder perguntas como:

- Quantos contratos estão aptos para renovação?
- Qual produto tem maior inadimplência?
- Qual canal gera mais saldo devedor?
- Qual origem concentra contratos NPL 90+?
- Clientes que vieram de renovação têm maior ou menor risco?
- Qual subproduto gera maior carteira ativa?

## Próxima etapa

Depois deste patch, continuamos a V1 com:

```text
Portabilidade
CRM
Canais Digitais
Cobrança
Churn
Gold Executivo
```
