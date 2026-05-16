# Patch 13B — Correção `valor_total_em_atraso_acionado`

## Erro corrigido

```text
coluna "valor_total_em_atraso_acionado" não existe
```

## Causa

A query da demanda/teste geral usava a coluna:

```text
gold.visao_executiva_cliente.valor_total_em_atraso_acionado
```

Mas a tabela `gold.visao_executiva_cliente`, criada no Patch 12, não tinha recebido essa coluna.

## Correção

O script:

```text
sql/postgres/17_fix_valor_total_em_atraso_acionado.sql
```

adiciona a coluna e preenche com base em:

```text
sdx.cliente_360_v8.valor_total_em_atraso_acionado
```

## Como executar

No VSCode conectado ao PostgreSQL `aurora_bank`, rode:

```text
sql/postgres/17_fix_valor_total_em_atraso_acionado.sql
```

Depois rode novamente:

```text
sql/postgres/15_test_geral_v1.sql
```

e:

```text
sql/postgres/16_demanda_01_visao_executiva.sql
```
