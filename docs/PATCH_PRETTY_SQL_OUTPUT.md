# Patch — Saída SQL Formatada

Este patch substitui o arquivo:

```text
scripts\run_sql_file.py
```

Agora o resultado das consultas aparece em uma tabela com bordas, alinhamento e limite de largura.

## Como aplicar

1. Extraia este ZIP.
2. Copie a pasta `scripts` para dentro do projeto:

```text
D:\aurora_bank\aurora_bank_enterprise_v1
```

3. Quando o Windows perguntar, escolha substituir o arquivo.

## Como usar

Execute normalmente:

```powershell
python .\scripts\run_sql_file.py .\sql\06_studies\meu_select.sql
```

Ou pelo VSCode:

```text
Ctrl + Shift + B
```

## Opções úteis

Exibir mais linhas:

```powershell
python .\scripts\run_sql_file.py .\sql\06_studies\meu_select.sql --limit-display 100
```

Aumentar largura das colunas:

```powershell
python .\scripts\run_sql_file.py .\sql\06_studies\meu_select.sql --max-col-width 60
```

Exportar último resultado para CSV:

```powershell
python .\scripts\run_sql_file.py .\sql\06_studies\meu_select.sql --csv data\exports_excel\resultado.csv
```

Exportar último resultado para Excel:

```powershell
python .\scripts\run_sql_file.py .\sql\06_studies\meu_select.sql --excel data\exports_excel\resultado.xlsx
```
