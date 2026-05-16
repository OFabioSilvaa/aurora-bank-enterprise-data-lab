# Patch 02B — Correção INITCAP DuckDB

Este patch corrige o erro:

```text
Catalog Error: Scalar Function with name initcap does not exist
```

O problema aconteceu porque a função `INITCAP()` não está disponível na sua versão/instalação atual do DuckDB.

## Como aplicar

1. Extraia este ZIP.
2. Copie a pasta `scripts` para dentro da pasta do projeto:

```text
D:\Banco de dados\aurora_bank_enterprise_v1_scaffold\aurora_bank_enterprise_v1
```

3. Quando o Windows perguntar, escolha **Substituir o arquivo no destino**.

Arquivo corrigido:

```text
scripts\02_create_bronze_silver_clientes.py
```

## Rode novamente

Dentro da pasta do projeto:

```powershell
python .\scripts\02_create_bronze_silver_clientes.py
```
