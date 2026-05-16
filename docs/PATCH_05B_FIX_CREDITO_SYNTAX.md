# Patch 05B — Correção de Sintaxe no Gerador de Crédito

Este patch corrige o erro:

```text
SyntaxError: '(' was never closed
```

O problema estava na linha que calcula `parcelas_pagas_estimadas`.

## Como aplicar

1. Extraia este ZIP.
2. Copie a pasta `scripts` para dentro da pasta do projeto:

```text
D:\Banco de dados\aurora_bank_enterprise_v1_scaffold\aurora_bank_enterprise_v1
```

3. Quando o Windows perguntar, escolha **Substituir o arquivo no destino**.

Arquivo corrigido:

```text
scripts\07_generate_bronze_credito.py
```

## Rode novamente

```powershell
python .\scripts\07_generate_bronze_credito.py --mode dev --overwrite
```

Depois, se a geração terminar com sucesso:

```powershell
python .\scripts\08_create_bronze_silver_credito.py
```

E por fim:

```powershell
python .\scripts\run_sql_file.py .\sql\06_studies\consultas_credito.sql
```
