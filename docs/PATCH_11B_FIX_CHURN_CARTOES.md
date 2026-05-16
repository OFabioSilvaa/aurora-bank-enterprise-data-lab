# Patch 11B — Correção Churn

Este patch corrige o erro:

```text
coluna c.qtd_cartoes_cancelados não existe
```

## Causa

A query de churn estava tentando buscar `qtd_cartoes_cancelados` diretamente da tabela:

```text
sdx.cliente_360_v7
```

Mas essa coluna está disponível na tabela:

```text
sdx.comportamento_cartao
```

## Correção

O script `11_create_churn.sql` agora faz `LEFT JOIN` com:

```text
sdx.comportamento_cartao
```

e usa:

```sql
COALESCE(cc.qtd_cartoes_cancelados, 0) AS qtd_cartoes_cancelados
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
