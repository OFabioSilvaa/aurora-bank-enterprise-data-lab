# Patch — Executar SQL direto do arquivo no VSCode

Este patch adiciona uma task do VSCode para executar o arquivo SQL aberto usando o banco DuckDB do projeto.

## Arquivos adicionados

```text
.vscode/tasks.json
sql/06_studies/00_teste_rodar_sql_vscode.sql
```

## Como aplicar

1. Extraia este ZIP.
2. Copie as pastas `.vscode`, `sql` e `docs` para dentro da pasta do projeto:

```text
D:\aurora_bank\aurora_bank_enterprise_v1
```

3. Se o Windows perguntar se deseja mesclar/substituir, aceite.

## Como usar

1. Abra o VSCode na pasta correta:

```text
D:\aurora_bank\aurora_bank_enterprise_v1
```

2. Abra o arquivo:

```text
sql\06_studies\00_teste_rodar_sql_vscode.sql
```

3. Aperte:

```text
Ctrl + Shift + B
```

Isso executa a task padrão:

```text
DuckDB: Run current SQL file
```

O resultado aparecerá no terminal integrado do VSCode.

## Alternativa

Você também pode ir em:

```text
Terminal > Run Task > DuckDB: Run current SQL file
```

## Observação

Isso não depende do SQLTools. Usa o script Python `scripts\run_sql_file.py`, que já funcionou no seu ambiente.
