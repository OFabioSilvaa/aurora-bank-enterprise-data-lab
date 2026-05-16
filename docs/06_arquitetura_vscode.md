# Ambiente de Trabalho no VSCode

## Objetivo

Usar o VSCode como ambiente principal para SQL, Python, documentação e demandas simuladas.

## Extensões recomendadas

- Python
- Jupyter
- SQLTools
- DuckDB
- Markdown Preview
- Excel Viewer
- GitLens

## Fluxo de trabalho

```text
1. Escrever SQL em /sql
2. Executar consultas no DuckDB
3. Gerar tabelas Silver/SDX/Gold
4. Exportar bases para Excel
5. Documentar conclusões em /tasks
6. Criar dashboards no Power BI
```

## Organização

- `scripts/`: rotinas Python
- `sql/`: consultas e transformações
- `docs/`: documentação do banco
- `tasks/`: demandas simuladas
- `data/`: dados em Parquet
- `database/`: arquivo DuckDB
- `excel/`: modelos de entrega em Excel
- `powerbi/`: orientações e ideias de dashboards
