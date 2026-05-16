"""
Aurora Bank Enterprise Data Lab
Patch 04B — Registrar Bronze e criar Silver/SDX/Gold de Cartões

Execute dentro da pasta do projeto:

    python .\scripts\06_create_bronze_silver_cartoes.py

Pré-requisitos:
    python .\scripts\02_create_bronze_silver_clientes.py
    python .\scripts\05_generate_bronze_cartoes.py --mode dev --overwrite

Este script:
    1. Registra Parquets Bronze de cartão como views
    2. Cria Silver de cartões, limites, compras, faturas e pagamentos
    3. Cria SDX de comportamento de cartão
    4. Cria Gold de KPIs mensais de cartão
    5. Cria cliente_360_v2 com dados de cartão
    6. Cria checks de qualidade
"""

from __future__ import annotations

from pathlib import Path
import sys
import duckdb


DB_PATH = Path("database/aurora_bank.duckdb")

BRONZE_TABLES = {
    "raw_cartoes": Path("data/bronze/raw_cartoes"),
    "raw_limites_cartao_historico": Path("data/bronze/raw_limites_cartao_historico"),
    "raw_compras_cartao": Path("data/bronze/raw_compras_cartao"),
    "raw_faturas_cartao": Path("data/bronze/raw_faturas_cartao"),
    "raw_pagamentos_fatura": Path("data/bronze/raw_pagamentos_fatura"),
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
        print("ERRO: não encontrei arquivos Bronze de cartões.")
        print("Rode antes:")
        print(r"python .\scripts\05_generate_bronze_cartoes.py --mode dev --overwrite")
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
        CREATE OR REPLACE TABLE silver.cartoes AS
        SELECT
            c.cartao_id,
            c.cliente_id,
            UPPER(TRIM(c.produto_cartao)) AS produto_cartao,
            UPPER(TRIM(c.bandeira)) AS bandeira,
            CASE
                WHEN TRY_CAST(c.limite_concedido AS DOUBLE) IS NULL THEN NULL
                WHEN TRY_CAST(c.limite_concedido AS DOUBLE) <= 0 THEN NULL
                WHEN TRY_CAST(c.limite_concedido AS DOUBLE) > 250000 THEN NULL
                ELSE ROUND(TRY_CAST(c.limite_concedido AS DOUBLE), 2)
            END AS limite_concedido_tratado,
            TRY_CAST(c.limite_concedido AS DOUBLE) AS limite_concedido_original,
            TRY_CAST(c.data_emissao AS DATE) AS data_emissao,
            TRY_CAST(c.data_ativacao AS DATE) AS data_ativacao,
            TRY_CAST(c.data_cancelamento AS DATE) AS data_cancelamento,
            UPPER(TRIM(c.status_cartao)) AS status_cartao,
            UPPER(TRIM(c.canal_emissao)) AS canal_emissao,
            TRY_CAST(c.taxa_rotativo AS DOUBLE) AS taxa_rotativo,
            TRY_CAST(c.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            c.origem_sistema,
            c.arquivo_origem,
            CASE WHEN cli.cliente_id IS NULL THEN TRUE ELSE FALSE END AS flag_cliente_orfao,
            CASE WHEN TRY_CAST(c.limite_concedido AS DOUBLE) IS NULL THEN TRUE ELSE FALSE END AS flag_limite_nulo,
            CASE WHEN TRY_CAST(c.limite_concedido AS DOUBLE) <= 0 THEN TRUE ELSE FALSE END AS flag_limite_invalido,
            CASE WHEN TRY_CAST(c.limite_concedido AS DOUBLE) > 250000 THEN TRUE ELSE FALSE END AS flag_limite_outlier,
            CASE
                WHEN TRY_CAST(c.data_cancelamento AS DATE) IS NOT NULL
                 AND TRY_CAST(c.data_ativacao AS DATE) IS NOT NULL
                 AND TRY_CAST(c.data_cancelamento AS DATE) < TRY_CAST(c.data_ativacao AS DATE)
                THEN TRUE ELSE FALSE
            END AS flag_data_inconsistente
        FROM bronze.raw_cartoes c
        LEFT JOIN silver.clientes cli
            ON c.cliente_id = cli.cliente_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.limites_cartao_historico AS
        SELECT
            l.limite_hist_id,
            l.cartao_id,
            l.cliente_id,
            TRY_CAST(l.data_referencia AS DATE) AS data_referencia,
            TRY_CAST(l.limite_total AS DOUBLE) AS limite_total,
            TRY_CAST(l.limite_disponivel_estimado AS DOUBLE) AS limite_disponivel_estimado,
            UPPER(TRIM(l.motivo_alteracao)) AS motivo_alteracao,
            TRY_CAST(l.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            l.origem_sistema,
            CASE WHEN c.cartao_id IS NULL THEN TRUE ELSE FALSE END AS flag_cartao_orfao
        FROM bronze.raw_limites_cartao_historico l
        LEFT JOIN silver.cartoes c
            ON l.cartao_id = c.cartao_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.compras_cartao AS
        WITH base AS (
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY compra_id
                    ORDER BY TRY_CAST(dt_ingestao AS TIMESTAMP) DESC NULLS LAST
                ) AS rn_compra
            FROM bronze.raw_compras_cartao
            WHERE compra_id IS NOT NULL
        )

        SELECT
            b.compra_id,
            b.cartao_id,
            b.cliente_id,
            TRY_CAST(b.data_compra AS TIMESTAMP) AS data_compra,
            TRY_CAST(b.data_compra AS DATE) AS data_ref,
            STRFTIME(TRY_CAST(b.data_compra AS DATE), '%Y-%m') AS ano_mes,
            CASE
                WHEN TRY_CAST(b.valor_compra AS DOUBLE) IS NULL THEN NULL
                WHEN TRY_CAST(b.valor_compra AS DOUBLE) < 0 THEN NULL
                WHEN TRY_CAST(b.valor_compra AS DOUBLE) > 100000 THEN NULL
                ELSE ROUND(TRY_CAST(b.valor_compra AS DOUBLE), 2)
            END AS valor_compra_tratado,
            TRY_CAST(b.valor_compra AS DOUBLE) AS valor_compra_original,
            UPPER(TRIM(b.categoria_compra)) AS categoria_compra,
            UPPER(TRIM(b.canal_compra)) AS canal_compra,
            TRY_CAST(b.parcelas_compra AS INTEGER) AS parcelas_compra,
            UPPER(TRIM(b.status_compra)) AS status_compra,
            TRY_CAST(b.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            b.origem_sistema,
            b.arquivo_origem,
            CASE WHEN b.rn_compra > 1 THEN TRUE ELSE FALSE END AS flag_compra_duplicada_removida,
            CASE WHEN c.cartao_id IS NULL THEN TRUE ELSE FALSE END AS flag_cartao_orfao,
            CASE WHEN cli.cliente_id IS NULL THEN TRUE ELSE FALSE END AS flag_cliente_orfao,
            CASE WHEN TRY_CAST(b.valor_compra AS DOUBLE) IS NULL THEN TRUE ELSE FALSE END AS flag_valor_nulo,
            CASE WHEN TRY_CAST(b.valor_compra AS DOUBLE) < 0 THEN TRUE ELSE FALSE END AS flag_valor_negativo,
            CASE WHEN TRY_CAST(b.data_compra AS DATE) > DATE '2026-12-31' THEN TRUE ELSE FALSE END AS flag_data_futura,
            CASE
                WHEN UPPER(TRIM(b.status_compra)) = 'APROVADA'
                 AND TRY_CAST(b.valor_compra AS DOUBLE) > 0
                 AND TRY_CAST(b.valor_compra AS DOUBLE) <= 100000
                 AND TRY_CAST(b.data_compra AS DATE) <= DATE '2026-12-31'
                THEN TRUE ELSE FALSE
            END AS flag_compra_valida_financeira
        FROM base b
        LEFT JOIN silver.cartoes c
            ON b.cartao_id = c.cartao_id
        LEFT JOIN silver.clientes cli
            ON b.cliente_id = cli.cliente_id
        WHERE b.rn_compra = 1;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.faturas_cartao AS
        SELECT
            f.fatura_id,
            f.cartao_id,
            f.cliente_id,
            TRY_CAST(f.competencia AS DATE) AS competencia,
            STRFTIME(TRY_CAST(f.competencia AS DATE), '%Y-%m') AS ano_mes,
            TRY_CAST(f.data_fechamento AS DATE) AS data_fechamento,
            TRY_CAST(f.data_vencimento AS DATE) AS data_vencimento,
            TRY_CAST(f.data_pagamento AS DATE) AS data_pagamento,
            CASE
                WHEN TRY_CAST(f.valor_fatura AS DOUBLE) IS NULL THEN NULL
                WHEN TRY_CAST(f.valor_fatura AS DOUBLE) < 0 THEN NULL
                WHEN TRY_CAST(f.valor_fatura AS DOUBLE) > 250000 THEN NULL
                ELSE ROUND(TRY_CAST(f.valor_fatura AS DOUBLE), 2)
            END AS valor_fatura_tratado,
            TRY_CAST(f.valor_fatura AS DOUBLE) AS valor_fatura_original,
            TRY_CAST(f.valor_pago AS DOUBLE) AS valor_pago,
            TRY_CAST(f.valor_minimo AS DOUBLE) AS valor_minimo,
            TRY_CAST(f.dias_atraso_fatura AS INTEGER) AS dias_atraso_fatura,
            UPPER(TRIM(f.status_fatura)) AS status_fatura,
            TRY_CAST(f.flag_rotativo AS BOOLEAN) AS flag_rotativo,
            TRY_CAST(f.flag_pagamento_minimo AS BOOLEAN) AS flag_pagamento_minimo,
            TRY_CAST(f.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            f.origem_sistema,
            f.arquivo_origem,
            CASE WHEN c.cartao_id IS NULL THEN TRUE ELSE FALSE END AS flag_cartao_orfao,
            CASE WHEN cli.cliente_id IS NULL THEN TRUE ELSE FALSE END AS flag_cliente_orfao,
            CASE WHEN TRY_CAST(f.valor_fatura AS DOUBLE) IS NULL THEN TRUE ELSE FALSE END AS flag_valor_fatura_nulo,
            CASE WHEN TRY_CAST(f.valor_pago AS DOUBLE) > TRY_CAST(f.valor_fatura AS DOUBLE) * 1.15 THEN TRUE ELSE FALSE END AS flag_pagamento_maior_que_fatura,
            CASE
                WHEN TRY_CAST(f.data_pagamento AS DATE) IS NOT NULL
                 AND TRY_CAST(f.data_vencimento AS DATE) IS NOT NULL
                 AND TRY_CAST(f.data_pagamento AS DATE) < TRY_CAST(f.data_fechamento AS DATE)
                THEN TRUE ELSE FALSE
            END AS flag_data_inconsistente
        FROM bronze.raw_faturas_cartao f
        LEFT JOIN silver.cartoes c
            ON f.cartao_id = c.cartao_id
        LEFT JOIN silver.clientes cli
            ON f.cliente_id = cli.cliente_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.pagamentos_fatura AS
        SELECT
            p.pagamento_fatura_id,
            p.fatura_id,
            p.cartao_id,
            p.cliente_id,
            TRY_CAST(p.data_pagamento AS DATE) AS data_pagamento,
            TRY_CAST(p.valor_pagamento AS DOUBLE) AS valor_pagamento,
            UPPER(TRIM(p.canal_pagamento)) AS canal_pagamento,
            UPPER(TRIM(p.status_pagamento)) AS status_pagamento,
            TRY_CAST(p.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            p.origem_sistema,
            p.arquivo_origem,
            CASE WHEN f.fatura_id IS NULL THEN TRUE ELSE FALSE END AS flag_fatura_orfa,
            CASE WHEN c.cartao_id IS NULL THEN TRUE ELSE FALSE END AS flag_cartao_orfao,
            CASE WHEN cli.cliente_id IS NULL THEN TRUE ELSE FALSE END AS flag_cliente_orfao
        FROM bronze.raw_pagamentos_fatura p
        LEFT JOIN silver.faturas_cartao f
            ON p.fatura_id = f.fatura_id
        LEFT JOIN silver.cartoes c
            ON p.cartao_id = c.cartao_id
        LEFT JOIN silver.clientes cli
            ON p.cliente_id = cli.cliente_id;
    """)


def create_sdx_gold(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("""
        CREATE OR REPLACE TABLE sdx.comportamento_cartao AS
        WITH cartoes AS (
            SELECT
                cliente_id,
                COUNT(DISTINCT cartao_id) AS qtd_cartoes,
                SUM(CASE WHEN status_cartao = 'ATIVO' THEN 1 ELSE 0 END) AS qtd_cartoes_ativos,
                SUM(COALESCE(limite_concedido_tratado, 0)) AS limite_total_cartao,
                AVG(COALESCE(limite_concedido_tratado, 0)) AS limite_medio_cartao,
                MAX(data_emissao) AS data_ultimo_cartao,
                SUM(CASE WHEN status_cartao = 'CANCELADO' THEN 1 ELSE 0 END) AS qtd_cartoes_cancelados
            FROM silver.cartoes
            WHERE flag_cliente_orfao = FALSE
            GROUP BY cliente_id
        ),

        compras AS (
            SELECT
                cliente_id,
                COUNT(*) AS qtd_compras_total,
                SUM(CASE WHEN flag_compra_valida_financeira THEN 1 ELSE 0 END) AS qtd_compras_validas,
                SUM(CASE WHEN flag_compra_valida_financeira THEN valor_compra_tratado ELSE 0 END) AS valor_total_compras,
                AVG(CASE WHEN flag_compra_valida_financeira THEN valor_compra_tratado ELSE NULL END) AS ticket_medio_compra,
                MAX(CASE WHEN flag_compra_valida_financeira THEN data_ref ELSE NULL END) AS data_ultima_compra
            FROM silver.compras_cartao
            WHERE flag_cliente_orfao = FALSE
            GROUP BY cliente_id
        ),

        faturas AS (
            SELECT
                cliente_id,
                COUNT(*) AS qtd_faturas,
                SUM(COALESCE(valor_fatura_tratado, 0)) AS valor_total_faturas,
                SUM(COALESCE(valor_pago, 0)) AS valor_total_pago_faturas,
                MAX(COALESCE(dias_atraso_fatura, 0)) AS maior_atraso_fatura,
                SUM(CASE WHEN COALESCE(dias_atraso_fatura, 0) > 0 THEN 1 ELSE 0 END) AS qtd_faturas_atrasadas,
                SUM(CASE WHEN flag_rotativo THEN 1 ELSE 0 END) AS qtd_uso_rotativo,
                SUM(CASE WHEN flag_pagamento_minimo THEN 1 ELSE 0 END) AS qtd_pagamento_minimo
            FROM silver.faturas_cartao
            WHERE flag_cliente_orfao = FALSE
            GROUP BY cliente_id
        )

        SELECT
            COALESCE(c.cliente_id, cp.cliente_id, f.cliente_id) AS cliente_id,
            COALESCE(c.qtd_cartoes, 0) AS qtd_cartoes,
            COALESCE(c.qtd_cartoes_ativos, 0) AS qtd_cartoes_ativos,
            COALESCE(c.limite_total_cartao, 0) AS limite_total_cartao,
            COALESCE(c.limite_medio_cartao, 0) AS limite_medio_cartao,
            c.data_ultimo_cartao,
            COALESCE(c.qtd_cartoes_cancelados, 0) AS qtd_cartoes_cancelados,
            COALESCE(cp.qtd_compras_total, 0) AS qtd_compras_total,
            COALESCE(cp.qtd_compras_validas, 0) AS qtd_compras_validas,
            COALESCE(cp.valor_total_compras, 0) AS valor_total_compras,
            COALESCE(cp.ticket_medio_compra, 0) AS ticket_medio_compra,
            cp.data_ultima_compra,
            DATE_DIFF('day', cp.data_ultima_compra, DATE '2026-12-31') AS dias_desde_ultima_compra,
            COALESCE(f.qtd_faturas, 0) AS qtd_faturas,
            COALESCE(f.valor_total_faturas, 0) AS valor_total_faturas,
            COALESCE(f.valor_total_pago_faturas, 0) AS valor_total_pago_faturas,
            COALESCE(f.maior_atraso_fatura, 0) AS maior_atraso_fatura,
            COALESCE(f.qtd_faturas_atrasadas, 0) AS qtd_faturas_atrasadas,
            COALESCE(f.qtd_uso_rotativo, 0) AS qtd_uso_rotativo,
            COALESCE(f.qtd_pagamento_minimo, 0) AS qtd_pagamento_minimo,
            CASE
                WHEN COALESCE(c.qtd_cartoes_ativos, 0) = 0 THEN 'SEM_CARTAO_ATIVO'
                WHEN COALESCE(f.maior_atraso_fatura, 0) >= 90 THEN 'RISCO_ALTO_CARTAO'
                WHEN COALESCE(f.maior_atraso_fatura, 0) >= 30 THEN 'RISCO_MEDIO_CARTAO'
                WHEN COALESCE(cp.qtd_compras_validas, 0) >= 50 THEN 'ALTO_USO_CARTAO'
                ELSE 'USO_MODERADO_CARTAO'
            END AS cluster_cartao
        FROM cartoes c
        FULL OUTER JOIN compras cp
            ON c.cliente_id = cp.cliente_id
        FULL OUTER JOIN faturas f
            ON COALESCE(c.cliente_id, cp.cliente_id) = f.cliente_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE sdx.cliente_360_v2 AS
        SELECT
            c360.*,
            COALESCE(cc.qtd_cartoes, 0) AS qtd_cartoes,
            COALESCE(cc.qtd_cartoes_ativos, 0) AS qtd_cartoes_ativos,
            COALESCE(cc.limite_total_cartao, 0) AS limite_total_cartao,
            COALESCE(cc.valor_total_compras, 0) AS valor_total_compras_cartao,
            COALESCE(cc.ticket_medio_compra, 0) AS ticket_medio_compra_cartao,
            cc.data_ultima_compra,
            cc.dias_desde_ultima_compra,
            COALESCE(cc.maior_atraso_fatura, 0) AS maior_atraso_fatura,
            COALESCE(cc.qtd_faturas_atrasadas, 0) AS qtd_faturas_atrasadas,
            COALESCE(cc.qtd_uso_rotativo, 0) AS qtd_uso_rotativo,
            COALESCE(cc.qtd_pagamento_minimo, 0) AS qtd_pagamento_minimo,
            COALESCE(cc.cluster_cartao, 'SEM_CARTAO') AS cluster_cartao,
            CASE
                WHEN COALESCE(cc.maior_atraso_fatura, 0) >= 90 THEN TRUE
                WHEN COALESCE(cc.qtd_uso_rotativo, 0) >= 3 THEN TRUE
                WHEN COALESCE(cc.qtd_pagamento_minimo, 0) >= 3 THEN TRUE
                ELSE FALSE
            END AS flag_risco_cartao
        FROM sdx.cliente_360 c360
        LEFT JOIN sdx.comportamento_cartao cc
            ON c360.cliente_id = cc.cliente_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE gold.kpi_cartoes_mensal AS
        SELECT
            ano_mes,
            COUNT(DISTINCT cartao_id) AS qtd_cartoes_com_fatura,
            COUNT(*) AS qtd_faturas,
            ROUND(SUM(COALESCE(valor_fatura_tratado, 0)), 2) AS valor_faturado,
            ROUND(SUM(COALESCE(valor_pago, 0)), 2) AS valor_pago,
            ROUND(SUM(CASE WHEN COALESCE(dias_atraso_fatura, 0) > 0 THEN COALESCE(valor_fatura_tratado, 0) ELSE 0 END), 2) AS valor_em_atraso,
            SUM(CASE WHEN COALESCE(dias_atraso_fatura, 0) > 0 THEN 1 ELSE 0 END) AS qtd_faturas_atrasadas,
            SUM(CASE WHEN flag_rotativo THEN 1 ELSE 0 END) AS qtd_rotativo,
            SUM(CASE WHEN flag_pagamento_minimo THEN 1 ELSE 0 END) AS qtd_pagamento_minimo,
            ROUND(AVG(COALESCE(dias_atraso_fatura, 0)), 2) AS media_dias_atraso
        FROM silver.faturas_cartao
        WHERE flag_cartao_orfao = FALSE
        GROUP BY ano_mes;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE gold.kpi_compras_cartao_mensal AS
        SELECT
            ano_mes,
            categoria_compra,
            canal_compra,
            COUNT(*) AS qtd_compras,
            SUM(CASE WHEN flag_compra_valida_financeira THEN 1 ELSE 0 END) AS qtd_compras_validas,
            ROUND(SUM(CASE WHEN flag_compra_valida_financeira THEN valor_compra_tratado ELSE 0 END), 2) AS valor_compras,
            ROUND(AVG(CASE WHEN flag_compra_valida_financeira THEN valor_compra_tratado ELSE NULL END), 2) AS ticket_medio
        FROM silver.compras_cartao
        GROUP BY ano_mes, categoria_compra, canal_compra;
    """)


def create_quality(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("""
        CREATE OR REPLACE TABLE meta.quality_cartoes AS
        SELECT 'raw_cartoes' AS check_name, COUNT(*) AS qtd FROM bronze.raw_cartoes
        UNION ALL SELECT 'raw_compras_cartao', COUNT(*) FROM bronze.raw_compras_cartao
        UNION ALL SELECT 'raw_faturas_cartao', COUNT(*) FROM bronze.raw_faturas_cartao
        UNION ALL SELECT 'raw_pagamentos_fatura', COUNT(*) FROM bronze.raw_pagamentos_fatura
        UNION ALL SELECT 'silver_cartoes', COUNT(*) FROM silver.cartoes
        UNION ALL SELECT 'silver_compras_cartao', COUNT(*) FROM silver.compras_cartao
        UNION ALL SELECT 'silver_faturas_cartao', COUNT(*) FROM silver.faturas_cartao
        UNION ALL SELECT 'silver_pagamentos_fatura', COUNT(*) FROM silver.pagamentos_fatura
        UNION ALL SELECT 'cartoes_cliente_orfao', COUNT(*) FROM silver.cartoes WHERE flag_cliente_orfao = TRUE
        UNION ALL SELECT 'cartoes_limite_nulo', COUNT(*) FROM silver.cartoes WHERE flag_limite_nulo = TRUE
        UNION ALL SELECT 'cartoes_limite_outlier', COUNT(*) FROM silver.cartoes WHERE flag_limite_outlier = TRUE
        UNION ALL SELECT 'compras_cartao_orfao', COUNT(*) FROM silver.compras_cartao WHERE flag_cartao_orfao = TRUE
        UNION ALL SELECT 'compras_valor_nulo', COUNT(*) FROM silver.compras_cartao WHERE flag_valor_nulo = TRUE
        UNION ALL SELECT 'compras_valor_negativo', COUNT(*) FROM silver.compras_cartao WHERE flag_valor_negativo = TRUE
        UNION ALL SELECT 'compras_validas', COUNT(*) FROM silver.compras_cartao WHERE flag_compra_valida_financeira = TRUE
        UNION ALL SELECT 'faturas_cartao_orfao', COUNT(*) FROM silver.faturas_cartao WHERE flag_cartao_orfao = TRUE
        UNION ALL SELECT 'faturas_valor_nulo', COUNT(*) FROM silver.faturas_cartao WHERE flag_valor_fatura_nulo = TRUE
        UNION ALL SELECT 'faturas_pagamento_maior_que_fatura', COUNT(*) FROM silver.faturas_cartao WHERE flag_pagamento_maior_que_fatura = TRUE
        UNION ALL SELECT 'clientes_com_cartao', COUNT(DISTINCT cliente_id) FROM silver.cartoes WHERE flag_cliente_orfao = FALSE
        UNION ALL SELECT 'clientes_com_cartao_ativo', COUNT(DISTINCT cliente_id) FROM silver.cartoes WHERE flag_cliente_orfao = FALSE AND status_cartao = 'ATIVO';
    """)


def print_summary(con: duckdb.DuckDBPyConnection) -> None:
    print("\nChecks de qualidade:")
    rows = con.execute("""
        SELECT check_name, qtd
        FROM meta.quality_cartoes
        ORDER BY check_name;
    """).fetchall()

    for check_name, qtd in rows:
        print(f"- {check_name}: {qtd:,}".replace(",", "."))

    print("\nAmostra silver.cartoes:")
    print(con.execute("""
        SELECT cartao_id, cliente_id, produto_cartao, bandeira, limite_concedido_tratado, status_cartao
        FROM silver.cartoes
        ORDER BY cartao_id
        LIMIT 5;
    """).fetchdf().to_string(index=False))

    print("\nAmostra silver.faturas_cartao:")
    print(con.execute("""
        SELECT fatura_id, cartao_id, cliente_id, ano_mes, valor_fatura_tratado, valor_pago, dias_atraso_fatura, status_fatura
        FROM silver.faturas_cartao
        ORDER BY fatura_id
        LIMIT 5;
    """).fetchdf().to_string(index=False))

    print("\nKPIs cartão mensal - top 5:")
    print(con.execute("""
        SELECT ano_mes, qtd_faturas, valor_faturado, valor_em_atraso, qtd_rotativo
        FROM gold.kpi_cartoes_mensal
        ORDER BY ano_mes DESC
        LIMIT 5;
    """).fetchdf().to_string(index=False))


def main() -> None:
    assert_project_root()
    ensure_files()

    con = duckdb.connect(str(DB_PATH))
    print("Aurora Bank — Bronze -> Silver Cartões")
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
    print("- silver.cartoes")
    print("- silver.compras_cartao")
    print("- silver.faturas_cartao")
    print("- sdx.comportamento_cartao")
    print("- sdx.cliente_360_v2")
    print("- gold.kpi_cartoes_mensal")
    print("- meta.quality_cartoes")


if __name__ == "__main__":
    main()
