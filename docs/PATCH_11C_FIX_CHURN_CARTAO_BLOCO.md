# Patch 11C — Correção completa do bloco de Cartão no Churn

Este patch corrige o Churn para buscar informações de cartão na fonte correta:

```text
sdx.comportamento_cartao
```

## Problema

A query anterior buscava algumas colunas diretamente em:

```text
sdx.cliente_360_v7
```

Mas parte dos campos de cartão estão em:

```text
sdx.comportamento_cartao
```

Campos ajustados:

```text
qtd_cartoes_ativos
qtd_cartoes_cancelados
qtd_compras_validas
data_ultima_compra
dias_desde_ultima_compra
cluster_cartao
flag_risco_cartao
```

## Como aplicar

Extraia este ZIP e copie a pasta `sql` para dentro do projeto:

```text
D:\aurora_bank\aurora_bank_enterprise_v1
```

Substitua o arquivo existente.

## Como executar

Rode novamente:

```text
sql/postgres/11_create_churn.sql
```

Depois rode:

```text
sql/postgres/12_test_churn.sql
```

Se ainda aparecer erro, copie exatamente a linha do erro, principalmente a parte que diz `coluna ... não existe`.
