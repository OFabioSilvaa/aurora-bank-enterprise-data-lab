# Patch 03B — Correção de coluna ambígua em silver.contas

Este patch corrige o erro:

```text
Binder Error: Ambiguous reference to column name "cliente_id"
```

O problema aconteceu porque a query de criação da tabela `silver.contas` fazia `JOIN` entre:

```text
bronze.raw_contas c
silver.clientes cli
```

E as duas tabelas possuem `cliente_id`. A correção foi qualificar os campos da conta com `c.`.

## Como aplicar

1. Extraia este ZIP.
2. Copie a pasta `scripts` para dentro da pasta do projeto:

```text
D:\Banco de dados\aurora_bank_enterprise_v1_scaffold\aurora_bank_enterprise_v1
```

3. Quando o Windows perguntar, escolha **Substituir o arquivo no destino**.

Arquivo corrigido:

```text
scripts\04_create_bronze_silver_contas_transacoes.py
```

## Rode novamente

```powershell
python .\scripts\04_create_bronze_silver_contas_transacoes.py
```
