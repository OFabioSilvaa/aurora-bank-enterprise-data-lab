"""
Aurora Bank Enterprise Data Lab
Patch 03B — Registrar Bronze e criar Silver/SDX/Gold de Contas e Transações

Execute dentro da pasta do projeto:

    python .\scripts\04_create_bronze_silver_contas_transacoes.py

Pré-requisitos:
    python .\scripts\02_create_bronze_silver_clientes.py
    python .\scripts\03_generate_bronze_contas_transacoes.py --mode dev --overwrite

Este script:
    1. Registra raw_contas e raw_transacoes como views Bronze
    2. Cria silver.contas e silver.transacoes
    3. Cria sdx.atividade_cliente
    4. Cria gold.kpi_transacoes_mensal
    5. Enriquece sdx.cliente_360 com atividade financeira
    6. Cria checks de qualidade
"""

from __future__ import annotations

from pathlib import Path
import sys
import duckdb


DB_PATH = Path("database/aurora_bank.duckdb")

BRONZE_TABLES = {
    "raw_contas": Path("data/bronze/raw_contas"),
    "raw_transacoes": Path("data/bronze/raw_transacoes"),
}


def assert_project_root() -> None:
    if not Path("README.md").exists() or not Path("scripts").exists():
        print("ERRO: execute este script dentro da pasta raiz do projeto aurora_bank_enterprise_v1.")
        sys.exit(1)


def ensure_files() -> None:
    missing = []
    for table, folder in BRONZE_TABLES.items():
        if not list(folder.glob("*.parquet")):
            missing.append((table, folder))
    if missing:
        print("ERRO: não encontrei arquivos de contas/transações.")
        print("Rode antes:")
        print(r"python .\scripts\03_generate_bronze_contas_transacoes.py --mode dev --overwrite")
        print("\nPastas sem arquivos:")
        for table, folder in missing:
            print(f"- {table}: {folder}")
        sys.exit(1)


def path_glob(folder: Path) -> str:
    return (folder / "*.parquet").as_posix()


def create_schemas(con: duckdb.DuckDBPyConnection) -> None:
    for schema in ["bronze", "silver", "sdx", "gold", "meta"]:
        con.execute(f"CREATE SCHEMA IF NOT EXISTS {schema};")


def create_bronze_views(con: duckdb.DuckDBPyConnection) -> None:
    for table, folder in BRONZE_TABLES.items():
        con.execute(f"""
            CREATE OR REPLACE VIEW bronze.{table} AS
            SELECT *
            FROM read_parquet('{path_glob(folder)}', union_by_name = true);
        """)


def require_clientes(con: duckdb.DuckDBPyConnection) -> None:
    exists = con.execute("""
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'silver'
          AND table_name = 'clientes';
    """).fetchone()[0]
    if exists == 0:
        print("ERRO: silver.clientes não existe.")
        print("Rode antes:")
        print(r"python .\scripts\02_create_bronze_silver_clientes.py")
        sys.exit(1)


def create_silver(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("""
        CREATE OR REPLACE TABLE silver.contas AS
        SELECT
            c.conta_id,
            c.cliente_id,
            UPPER(TRIM(c.tipo_conta)) AS tipo_conta,
            TRIM(c.agencia) AS agencia,
            TRIM(c.numero_conta) AS numero_conta,
            TRY_CAST(c.data_abertura AS DATE) AS data_abertura,
            TRY_CAST(c.data_encerramento AS DATE) AS data_encerramento,
            UPPER(TRIM(c.status_conta)) AS status_conta,
            CASE
                WHEN TRY_CAST(c.saldo_atual AS DOUBLE) IS NULL THEN NULL
                WHEN TRY_CAST(c.saldo_atual AS DOUBLE) > 250000 THEN NULL
                ELSE ROUND(TRY_CAST(c.saldo_atual AS DOUBLE), 2)
            END AS saldo_atual_tratado,
            TRY_CAST(c.saldo_atual AS DOUBLE) AS saldo_atual_original,
            UPPER(TRIM(c.canal_abertura)) AS canal_abertura,
            TRY_CAST(c.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            c.origem_sistema,
            c.arquivo_origem,
            CASE WHEN cli.cliente_id IS NULL THEN TRUE ELSE FALSE END AS flag_cliente_orfao,
            CASE WHEN TRY_CAST(c.saldo_atual AS DOUBLE) IS NULL THEN TRUE ELSE FALSE END AS flag_saldo_nulo,
            CASE WHEN TRY_CAST(c.saldo_atual AS DOUBLE) > 250000 THEN TRUE ELSE FALSE END AS flag_saldo_outlier,
            CASE
                WHEN TRY_CAST(c.data_encerramento AS DATE) IS NOT NULL
                 AND TRY_CAST(c.data_abertura AS DATE) IS NOT NULL
                 AND TRY_CAST(c.data_encerramento AS DATE) < TRY_CAST(c.data_abertura AS DATE)
                THEN TRUE ELSE FALSE
            END AS flag_data_inconsistente
        FROM bronze.raw_contas c
        LEFT JOIN silver.clientes cli
            ON c.cliente_id = cli.cliente_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.transacoes AS
        WITH tx_base AS (
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY transacao_id
                    ORDER BY TRY_CAST(dt_ingestao AS TIMESTAMP) DESC NULLS LAST
                ) AS rn_transacao
            FROM bronze.raw_transacoes
            WHERE transacao_id IS NOT NULL
        )

        SELECT
            t.transacao_id,
            t.conta_id,
            t.cliente_id,
            TRY_CAST(t.data_transacao AS TIMESTAMP) AS data_transacao,
            TRY_CAST(t.data_transacao AS DATE) AS data_ref,
            STRFTIME(TRY_CAST(t.data_transacao AS DATE), '%Y-%m') AS ano_mes,
            UPPER(TRIM(t.tipo_transacao)) AS tipo_transacao,
            UPPER(TRIM(t.canal)) AS canal,
            UPPER(TRIM(t.categoria_transacao)) AS categoria_transacao,
            CASE
                WHEN TRY_CAST(t.valor AS DOUBLE) IS NULL THEN NULL
                WHEN TRY_CAST(t.valor AS DOUBLE) < 0 THEN NULL
                WHEN TRY_CAST(t.valor AS DOUBLE) > 200000 THEN NULL
                ELSE ROUND(TRY_CAST(t.valor AS DOUBLE), 2)
            END AS valor_tratado,
            TRY_CAST(t.valor AS DOUBLE) AS valor_original,
            UPPER(TRIM(t.status_transacao)) AS status_transacao,
            t.descricao,
            TRY_CAST(t.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            t.origem_sistema,
            t.arquivo_origem,

            CASE WHEN t.rn_transacao > 1 THEN TRUE ELSE FALSE END AS flag_transacao_duplicada_removida,
            CASE WHEN c.conta_id IS NULL THEN TRUE ELSE FALSE END AS flag_conta_orfa,
            CASE WHEN cli.cliente_id IS NULL THEN TRUE ELSE FALSE END AS flag_cliente_orfao,
            CASE WHEN TRY_CAST(t.valor AS DOUBLE) IS NULL THEN TRUE ELSE FALSE END AS flag_valor_nulo,
            CASE WHEN TRY_CAST(t.valor AS DOUBLE) < 0 THEN TRUE ELSE FALSE END AS flag_valor_negativo,
            CASE WHEN TRY_CAST(t.valor AS DOUBLE) > 200000 THEN TRUE ELSE FALSE END AS flag_valor_outlier,
            CASE
                WHEN TRY_CAST(t.data_transacao AS DATE) > DATE '2026-12-31'
                THEN TRUE ELSE FALSE
            END AS flag_data_futura,
            CASE
                WHEN UPPER(TRIM(t.status_transacao)) = 'EFETIVADA'
                 AND TRY_CAST(t.valor AS DOUBLE) > 0
                 AND TRY_CAST(t.valor AS DOUBLE) <= 200000
                 AND TRY_CAST(t.data_transacao AS DATE) <= DATE '2026-12-31'
                THEN TRUE ELSE FALSE
            END AS flag_transacao_valida_financeira

        FROM tx_base t
        LEFT JOIN silver.contas c
            ON t.conta_id = c.conta_id
        LEFT JOIN silver.clientes cli
            ON t.cliente_id = cli.cliente_id
        WHERE t.rn_transacao = 1;
    """)


def create_sdx_gold(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("""
        CREATE OR REPLACE TABLE sdx.atividade_cliente AS
        WITH contas AS (
            SELECT
                cliente_id,
                COUNT(DISTINCT conta_id) AS qtd_contas,
                SUM(CASE WHEN status_conta = 'ATIVA' THEN 1 ELSE 0 END) AS qtd_contas_ativas,
                MIN(data_abertura) AS primeira_conta,
                MAX(data_abertura) AS ultima_conta,
                SUM(COALESCE(saldo_atual_tratado, 0)) AS saldo_total_contas
            FROM silver.contas
            WHERE flag_cliente_orfao = FALSE
            GROUP BY cliente_id
        ),

        tx AS (
            SELECT
                cliente_id,
                COUNT(*) AS qtd_transacoes_total,
                SUM(CASE WHEN flag_transacao_valida_financeira THEN 1 ELSE 0 END) AS qtd_transacoes_validas,
                SUM(CASE WHEN flag_transacao_valida_financeira THEN valor_tratado ELSE 0 END) AS valor_transacionado,
                AVG(CASE WHEN flag_transacao_valida_financeira THEN valor_tratado ELSE NULL END) AS ticket_medio,
                MAX(CASE WHEN flag_transacao_valida_financeira THEN data_ref ELSE NULL END) AS data_ultima_transacao,
                COUNT(DISTINCT CASE WHEN flag_transacao_valida_financeira THEN ano_mes ELSE NULL END) AS meses_com_transacao,
                SUM(CASE WHEN flag_transacao_valida_financeira AND tipo_transacao = 'PIX_ENVIADO' THEN 1 ELSE 0 END) AS qtd_pix_enviado,
                SUM(CASE WHEN flag_transacao_valida_financeira AND tipo_transacao = 'PIX_RECEBIDO' THEN 1 ELSE 0 END) AS qtd_pix_recebido
            FROM silver.transacoes
            WHERE flag_cliente_orfao = FALSE
            GROUP BY cliente_id
        )

        SELECT
            COALESCE(c.cliente_id, t.cliente_id) AS cliente_id,
            COALESCE(c.qtd_contas, 0) AS qtd_contas,
            COALESCE(c.qtd_contas_ativas, 0) AS qtd_contas_ativas,
            c.primeira_conta,
            c.ultima_conta,
            COALESCE(c.saldo_total_contas, 0) AS saldo_total_contas,
            COALESCE(t.qtd_transacoes_total, 0) AS qtd_transacoes_total,
            COALESCE(t.qtd_transacoes_validas, 0) AS qtd_transacoes_validas,
            COALESCE(t.valor_transacionado, 0) AS valor_transacionado,
            COALESCE(t.ticket_medio, 0) AS ticket_medio,
            t.data_ultima_transacao,
            DATE_DIFF('day', t.data_ultima_transacao, DATE '2026-12-31') AS dias_desde_ultima_transacao,
            COALESCE(t.meses_com_transacao, 0) AS meses_com_transacao,
            COALESCE(t.qtd_pix_enviado, 0) AS qtd_pix_enviado,
            COALESCE(t.qtd_pix_recebido, 0) AS qtd_pix_recebido,
            CASE
                WHEN COALESCE(t.qtd_transacoes_validas, 0) = 0 THEN 'SEM_MOVIMENTO'
                WHEN DATE_DIFF('day', t.data_ultima_transacao, DATE '2026-12-31') > 180 THEN 'INATIVO_TRANSACIONAL'
                WHEN DATE_DIFF('day', t.data_ultima_transacao, DATE '2026-12-31') > 90 THEN 'BAIXA_ATIVIDADE'
                WHEN COALESCE(t.qtd_transacoes_validas, 0) >= 100 THEN 'ALTA_ATIVIDADE'
                ELSE 'ATIVIDADE_MEDIA'
            END AS cluster_atividade_financeira
        FROM contas c
        FULL OUTER JOIN tx t
            ON c.cliente_id = t.cliente_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE sdx.cliente_360 AS
        SELECT
            cb.*,
            COALESCE(a.qtd_contas, 0) AS qtd_contas,
            COALESCE(a.qtd_contas_ativas, 0) AS qtd_contas_ativas,
            COALESCE(a.saldo_total_contas, 0) AS saldo_total_contas,
            COALESCE(a.qtd_transacoes_validas, 0) AS qtd_transacoes_validas,
            COALESCE(a.valor_transacionado, 0) AS valor_transacionado,
            COALESCE(a.ticket_medio, 0) AS ticket_medio,
            a.data_ultima_transacao,
            a.dias_desde_ultima_transacao,
            COALESCE(a.meses_com_transacao, 0) AS meses_com_transacao,
            a.cluster_atividade_financeira,
            CASE
                WHEN cb.flag_cliente_ativo = FALSE THEN TRUE
                WHEN COALESCE(a.qtd_transacoes_validas, 0) = 0 AND cb.dias_desde_ultimo_login > 90 THEN TRUE
                WHEN a.dias_desde_ultima_transacao > 120 AND cb.dias_desde_ultimo_login > 90 THEN TRUE
                ELSE FALSE
            END AS flag_risco_churn_inicial
        FROM sdx.cliente_360_base cb
        LEFT JOIN sdx.atividade_cliente a
            ON cb.cliente_id = a.cliente_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE gold.kpi_transacoes_mensal AS
        SELECT
            ano_mes,
            tipo_transacao,
            canal,
            categoria_transacao,
            COUNT(*) AS qtd_transacoes,
            SUM(CASE WHEN flag_transacao_valida_financeira THEN 1 ELSE 0 END) AS qtd_transacoes_validas,
            ROUND(SUM(CASE WHEN flag_transacao_valida_financeira THEN valor_tratado ELSE 0 END), 2) AS valor_transacionado,
            ROUND(AVG(CASE WHEN flag_transacao_valida_financeira THEN valor_tratado ELSE NULL END), 2) AS ticket_medio,
            SUM(CASE WHEN status_transacao = 'CANCELADA' THEN 1 ELSE 0 END) AS qtd_canceladas,
            SUM(CASE WHEN status_transacao = 'NEGADA' THEN 1 ELSE 0 END) AS qtd_negadas,
            SUM(CASE WHEN flag_valor_nulo OR flag_valor_negativo OR flag_data_futura THEN 1 ELSE 0 END) AS qtd_inconsistencias
        FROM silver.transacoes
        GROUP BY
            ano_mes,
            tipo_transacao,
            canal,
            categoria_transacao;
    """)


def create_quality(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("""
        CREATE OR REPLACE TABLE meta.quality_contas_transacoes AS
        SELECT 'raw_contas' AS check_name, COUNT(*) AS qtd FROM bronze.raw_contas
        UNION ALL SELECT 'raw_transacoes', COUNT(*) FROM bronze.raw_transacoes
        UNION ALL SELECT 'silver_contas', COUNT(*) FROM silver.contas
        UNION ALL SELECT 'silver_transacoes', COUNT(*) FROM silver.transacoes
        UNION ALL SELECT 'contas_orfas', COUNT(*) FROM silver.contas WHERE flag_cliente_orfao = TRUE
        UNION ALL SELECT 'contas_saldo_nulo', COUNT(*) FROM silver.contas WHERE flag_saldo_nulo = TRUE
        UNION ALL SELECT 'contas_saldo_outlier', COUNT(*) FROM silver.contas WHERE flag_saldo_outlier = TRUE
        UNION ALL SELECT 'transacoes_conta_orfa', COUNT(*) FROM silver.transacoes WHERE flag_conta_orfa = TRUE
        UNION ALL SELECT 'transacoes_cliente_orfao', COUNT(*) FROM silver.transacoes WHERE flag_cliente_orfao = TRUE
        UNION ALL SELECT 'transacoes_valor_nulo', COUNT(*) FROM silver.transacoes WHERE flag_valor_nulo = TRUE
        UNION ALL SELECT 'transacoes_valor_negativo', COUNT(*) FROM silver.transacoes WHERE flag_valor_negativo = TRUE
        UNION ALL SELECT 'transacoes_data_futura', COUNT(*) FROM silver.transacoes WHERE flag_data_futura = TRUE
        UNION ALL SELECT 'transacoes_validas_financeiras', COUNT(*) FROM silver.transacoes WHERE flag_transacao_valida_financeira = TRUE
        UNION ALL SELECT 'clientes_com_conta', COUNT(DISTINCT cliente_id) FROM silver.contas WHERE flag_cliente_orfao = FALSE
        UNION ALL SELECT 'clientes_com_transacao', COUNT(DISTINCT cliente_id) FROM silver.transacoes WHERE flag_transacao_valida_financeira = TRUE;
    """)


def print_summary(con: duckdb.DuckDBPyConnection) -> None:
    print("\nChecks de qualidade:")
    rows = con.execute("""
        SELECT check_name, qtd
        FROM meta.quality_contas_transacoes
        ORDER BY check_name;
    """).fetchall()

    for check_name, qtd in rows:
        print(f"- {check_name}: {qtd:,}".replace(",", "."))

    print("\nAmostra silver.contas:")
    print(con.execute("""
        SELECT conta_id, cliente_id, tipo_conta, status_conta, saldo_atual_tratado, canal_abertura
        FROM silver.contas
        ORDER BY conta_id
        LIMIT 5;
    """).fetchdf().to_string(index=False))

    print("\nAmostra silver.transacoes:")
    print(con.execute("""
        SELECT transacao_id, conta_id, cliente_id, data_ref, tipo_transacao, canal, valor_tratado, status_transacao
        FROM silver.transacoes
        ORDER BY transacao_id
        LIMIT 5;
    """).fetchdf().to_string(index=False))

    print("\nKPIs mensais - top 5:")
    print(con.execute("""
        SELECT ano_mes, tipo_transacao, canal, qtd_transacoes_validas, valor_transacionado
        FROM gold.kpi_transacoes_mensal
        ORDER BY valor_transacionado DESC
        LIMIT 5;
    """).fetchdf().to_string(index=False))


def main() -> None:
    assert_project_root()
    ensure_files()

    con = duckdb.connect(str(DB_PATH))
    print("Aurora Bank — Bronze -> Silver Contas e Transações")
    print("=" * 70)
    print(f"Banco: {DB_PATH}")

    print("Criando schemas...")
    create_schemas(con)

    print("Validando silver.clientes...")
    require_clientes(con)

    print("Registrando views Bronze...")
    create_bronze_views(con)

    print("Criando Silver...")
    create_silver(con)

    print("Criando SDX e Gold...")
    create_sdx_gold(con)

    print("Criando checks...")
    create_quality(con)

    print_summary(con)
    con.close()

    print("\nProcesso concluído com sucesso.")
    print("Agora você já pode consultar:")
    print("- silver.contas")
    print("- silver.transacoes")
    print("- sdx.atividade_cliente")
    print("- sdx.cliente_360")
    print("- gold.kpi_transacoes_mensal")
    print("- meta.quality_contas_transacoes")


if __name__ == "__main__":
    main()
