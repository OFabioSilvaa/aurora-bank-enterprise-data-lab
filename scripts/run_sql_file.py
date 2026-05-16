"""
Aurora Bank Enterprise Data Lab
Executor SQL com saída formatada em tabela

Uso básico:

    python .\scripts\run_sql_file.py .\sql\06_studies\meu_select.sql

Opções úteis:

    python .\scripts\run_sql_file.py .\sql\06_studies\meu_select.sql --limit-display 50
    python .\scripts\run_sql_file.py .\sql\06_studies\meu_select.sql --max-col-width 40
    python .\scripts\run_sql_file.py .\sql\06_studies\meu_select.sql --csv resultado.csv
    python .\scripts\run_sql_file.py .\sql\06_studies\meu_select.sql --excel resultado.xlsx
"""

from __future__ import annotations

from pathlib import Path
import argparse
import sys
import textwrap
import math

import duckdb
import pandas as pd


DB_PATH = Path("database") / "aurora_bank.duckdb"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Executa arquivo SQL no DuckDB do Aurora Bank.")
    parser.add_argument("sql_file", help="Caminho do arquivo .sql")
    parser.add_argument("--limit-display", type=int, default=50, help="Quantidade máxima de linhas exibidas no terminal.")
    parser.add_argument("--max-col-width", type=int, default=36, help="Largura máxima de cada coluna.")
    parser.add_argument("--csv", default=None, help="Exporta o último resultado tabular para CSV.")
    parser.add_argument("--excel", default=None, help="Exporta o último resultado tabular para Excel.")
    parser.add_argument("--plain", action="store_true", help="Usa saída simples do Pandas.")
    return parser.parse_args()


def split_sql_statements(sql: str) -> list[str]:
    """
    Separador simples por ponto e vírgula.
    Para nosso uso de estudos SQL, é suficiente.
    """
    statements = []
    current = []
    in_single_quote = False
    in_double_quote = False

    for char in sql:
        if char == "'" and not in_double_quote:
            in_single_quote = not in_single_quote
        elif char == '"' and not in_single_quote:
            in_double_quote = not in_double_quote

        if char == ";" and not in_single_quote and not in_double_quote:
            statement = "".join(current).strip()
            if statement:
                statements.append(statement)
            current = []
        else:
            current.append(char)

    tail = "".join(current).strip()
    if tail:
        statements.append(tail)

    return statements


def clean_value(value, max_width: int) -> str:
    if value is None:
        text = "NULL"
    elif isinstance(value, float):
        if math.isnan(value):
            text = "NULL"
        else:
            text = f"{value:,.4f}".rstrip("0").rstrip(".")
    else:
        text = str(value)

    text = text.replace("\n", " ").replace("\r", " ")
    if len(text) > max_width:
        return text[: max_width - 1] + "…"
    return text


def is_numeric_series(series: pd.Series) -> bool:
    return pd.api.types.is_numeric_dtype(series)


def make_table(df: pd.DataFrame, limit_display: int = 50, max_col_width: int = 36) -> str:
    if df.empty:
        return "Resultado vazio: 0 linhas."

    display_df = df.head(limit_display).copy()
    columns = list(display_df.columns)

    formatted_rows = []
    for _, row in display_df.iterrows():
        formatted_rows.append([clean_value(row[col], max_col_width) for col in columns])

    formatted_headers = [clean_value(col, max_col_width) for col in columns]

    widths = []
    for idx, header in enumerate(formatted_headers):
        max_cell = max([len(r[idx]) for r in formatted_rows], default=0)
        widths.append(min(max(len(header), max_cell), max_col_width))

    def fmt_cell(text: str, width: int, align_right: bool = False) -> str:
        if align_right:
            return text.rjust(width)
        return text.ljust(width)

    numeric_cols = [is_numeric_series(display_df[col]) for col in columns]

    top = "╭" + "┬".join("─" * (w + 2) for w in widths) + "╮"
    sep = "├" + "┼".join("─" * (w + 2) for w in widths) + "┤"
    bottom = "╰" + "┴".join("─" * (w + 2) for w in widths) + "╯"

    header_line = "│" + "│".join(f" {fmt_cell(h, widths[i])} " for i, h in enumerate(formatted_headers)) + "│"

    lines = [top, header_line, sep]

    for row in formatted_rows:
        line = "│" + "│".join(
            f" {fmt_cell(row[i], widths[i], align_right=numeric_cols[i])} "
            for i in range(len(columns))
        ) + "│"
        lines.append(line)

    lines.append(bottom)

    total_rows = len(df)
    shown_rows = len(display_df)
    lines.append(f"Linhas exibidas: {shown_rows} de {total_rows} | Colunas: {len(columns)}")

    if total_rows > shown_rows:
        lines.append(f"Dica: use --limit-display {total_rows} para exibir mais linhas, ou exporte para CSV/Excel.")

    return "\n".join(lines)


def print_query_header(index: int, statement: str) -> None:
    print("\n" + "═" * 100)
    print(f"QUERY {index}")
    print("═" * 100)

    preview = " ".join(statement.split())
    if len(preview) > 240:
        preview = preview[:237] + "..."
    print(preview)
    print("─" * 100)


def main() -> None:
    args = parse_args()

    sql_path = Path(args.sql_file)

    if not DB_PATH.exists():
        print(f"ERRO: Banco não encontrado: {DB_PATH}")
        print("Verifique se você está na pasta raiz do projeto.")
        sys.exit(1)

    if not sql_path.exists():
        print(f"ERRO: Arquivo SQL não encontrado: {sql_path}")
        sys.exit(1)

    sql = sql_path.read_text(encoding="utf-8")
    statements = split_sql_statements(sql)

    if not statements:
        print("Nenhuma query encontrada no arquivo SQL.")
        sys.exit(0)

    print("Aurora Bank — Executor SQL")
    print(f"Banco: {DB_PATH}")
    print(f"Arquivo SQL: {sql_path}")
    print(f"Queries encontradas: {len(statements)}")

    con = duckdb.connect(str(DB_PATH), read_only=False)
    last_df = None

    try:
        for idx, statement in enumerate(statements, start=1):
            print_query_header(idx, statement)

            try:
                result = con.execute(statement)

                try:
                    df = result.fetchdf()
                    last_df = df

                    if args.plain:
                        print(df.head(args.limit_display).to_string(index=False))
                        print(f"\nLinhas exibidas: {min(len(df), args.limit_display)} de {len(df)} | Colunas: {len(df.columns)}")
                    else:
                        print(make_table(df, limit_display=args.limit_display, max_col_width=args.max_col_width))

                except Exception:
                    print("Query executada com sucesso, sem retorno tabular.")

            except Exception as e:
                print("ERRO AO EXECUTAR QUERY:")
                print(e)
                print("\nA query com erro foi:")
                print(statement)
                sys.exit(1)

        if last_df is not None:
            if args.csv:
                out = Path(args.csv)
                out.parent.mkdir(parents=True, exist_ok=True) if out.parent != Path(".") else None
                last_df.to_csv(out, index=False, encoding="utf-8-sig")
                print(f"\nCSV exportado: {out}")

            if args.excel:
                out = Path(args.excel)
                out.parent.mkdir(parents=True, exist_ok=True) if out.parent != Path(".") else None
                last_df.to_excel(out, index=False)
                print(f"\nExcel exportado: {out}")

    finally:
        con.close()


if __name__ == "__main__":
    main()
