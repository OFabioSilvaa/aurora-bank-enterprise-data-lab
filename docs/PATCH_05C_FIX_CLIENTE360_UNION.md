# Patch 05C — Correção Cliente 360 V3

Este patch corrige o erro:

```text
Binder Error: Set operations can only apply to expressions with the same number of result columns
```

## Causa

O script tentou fazer `UNION ALL` entre:

```text
sdx.cliente_360_v2
sdx.cliente_360
```

Mas essas tabelas não têm exatamente o mesmo número de colunas.

## Correção

Agora o script verifica automaticamente se existe `sdx.cliente_360_v2`.

- Se existir, usa `sdx.cliente_360_v2`.
- Se não existir, usa `sdx.cliente_360`.

Sem `UNION ALL`.

## Como aplicar

1. Extraia este ZIP.
2. Copie a pasta `scripts` para dentro da pasta do projeto:

```text
D:\Banco de dados\aurora_bank_enterprise_v1_scaffold\aurora_bank_enterprise_v1
```

3. Quando o Windows perguntar, escolha **Substituir o arquivo no destino**.

Arquivo corrigido:

```text
scripts\08_create_bronze_silver_credito.py
```

## Rode novamente

```powershell
python .\scripts\08_create_bronze_silver_credito.py
```

Depois:

```powershell
python .\scripts\run_sql_file.py .\sql\06_studies\consultas_credito.sql
```
