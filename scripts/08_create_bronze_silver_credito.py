"""
Aurora Bank Enterprise Data Lab
Patch 05B — Registrar Bronze e criar Silver/SDX/Gold de Crédito

Execute dentro da pasta do projeto:

    python .\scripts\08_create_bronze_silver_credito.py

Pré-requisitos:
    python .\scripts\02_create_bronze_silver_clientes.py
    python .\scripts\07_generate_bronze_credito.py --mode dev --overwrite
"""

from __future__ import annotations

from pathlib import Path
import sys
import duckdb


DB_PATH = Path("database/aurora_bank.duckdb")

BRONZE_TABLES = {
    "raw_propostas_credito": Path("data/bronze/raw_propostas_credito"),
    "raw_contratos_credito": Path("data/bronze/raw_contratos_credito"),
    "raw_parcelas_credito": Path("data/bronze/raw_parcelas_credito"),
    "raw_pagamentos_credito": Path("data/bronze/raw_pagamentos_credito"),
    "raw_politicas_credito": Path("data/bronze/raw_politicas_credito"),
    "raw_politicas_precificacao": Path("data/bronze/raw_politicas_precificacao"),
    "raw_renegociacoes": Path("data/bronze/raw_renegociacoes"),
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
        print("ERRO: não encontrei arquivos Bronze de crédito.")
        print("Rode antes:")
        print(r"python .\scripts\07_generate_bronze_credito.py --mode dev --overwrite")
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
        CREATE OR REPLACE TABLE silver.politicas_credito AS
        SELECT
            politica_credito_id,
            UPPER(TRIM(produto_credito)) AS produto_credito,
            UPPER(TRIM(segmento)) AS segmento,
            UPPER(TRIM(rating)) AS rating,
            TRY_CAST(score_min AS INTEGER) AS score_min,
            TRY_CAST(score_max AS INTEGER) AS score_max,
            TRY_CAST(renda_minima AS DOUBLE) AS renda_minima,
            TRY_CAST(prazo_min AS INTEGER) AS prazo_min,
            TRY_CAST(prazo_max AS INTEGER) AS prazo_max,
            TRY_CAST(valor_min AS DOUBLE) AS valor_min,
            TRY_CAST(valor_max AS DOUBLE) AS valor_max,
            TRY_CAST(comprometimento_renda_max AS DOUBLE) AS comprometimento_renda_max,
            TRY_CAST(vigencia_inicio AS DATE) AS vigencia_inicio,
            TRY_CAST(vigencia_fim AS DATE) AS vigencia_fim,
            TRY_CAST(flag_ativa AS BOOLEAN) AS flag_ativa,
            TRY_CAST(dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            origem_sistema
        FROM bronze.raw_politicas_credito;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.politicas_precificacao AS
        SELECT
            politica_precificacao_id,
            UPPER(TRIM(produto_credito)) AS produto_credito,
            UPPER(TRIM(segmento)) AS segmento,
            UPPER(TRIM(rating)) AS rating,
            TRY_CAST(taxa_min AS DOUBLE) AS taxa_min,
            TRY_CAST(taxa_max AS DOUBLE) AS taxa_max,
            TRY_CAST(spread_alvo AS DOUBLE) AS spread_alvo,
            TRY_CAST(custo_funding AS DOUBLE) AS custo_funding,
            TRY_CAST(vigencia_inicio AS DATE) AS vigencia_inicio,
            TRY_CAST(vigencia_fim AS DATE) AS vigencia_fim,
            TRY_CAST(flag_ativa AS BOOLEAN) AS flag_ativa,
            TRY_CAST(dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            origem_sistema
        FROM bronze.raw_politicas_precificacao;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.propostas_credito AS
        SELECT
            p.proposta_id,
            p.cliente_id,
            UPPER(TRIM(p.produto_credito)) AS produto_credito,
            UPPER(TRIM(p.canal_proposta)) AS canal_proposta,
            TRY_CAST(p.data_proposta AS DATE) AS data_proposta,
            STRFTIME(TRY_CAST(p.data_proposta AS DATE), '%Y-%m') AS safra_proposta,
            TRY_CAST(p.valor_solicitado AS DOUBLE) AS valor_solicitado,
            TRY_CAST(p.prazo_meses AS INTEGER) AS prazo_meses,
            TRY_CAST(p.taxa_ofertada AS DOUBLE) AS taxa_ofertada,
            TRY_CAST(p.parcela_estimada AS DOUBLE) AS parcela_estimada,
            TRY_CAST(p.renda_mensal_informada AS DOUBLE) AS renda_mensal_informada,
            TRY_CAST(p.comprometimento_renda_estimado AS DOUBLE) AS comprometimento_renda_estimado,
            TRY_CAST(p.score_motor AS INTEGER) AS score_motor,
            UPPER(TRIM(p.rating_motor)) AS rating_motor,
            UPPER(TRIM(p.status_proposta)) AS status_proposta,
            UPPER(TRIM(p.motivo_recusa)) AS motivo_recusa,
            TRY_CAST(p.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            p.origem_sistema,
            p.arquivo_origem,
            CASE WHEN cli.cliente_id IS NULL THEN TRUE ELSE FALSE END AS flag_cliente_orfao,
            CASE WHEN TRY_CAST(p.score_motor AS INTEGER) IS NULL THEN TRUE ELSE FALSE END AS flag_score_motor_nulo,
            CASE WHEN TRY_CAST(p.data_proposta AS DATE) > DATE '2026-12-31' THEN TRUE ELSE FALSE END AS flag_data_futura,
            CASE WHEN TRY_CAST(p.valor_solicitado AS DOUBLE) <= 0 THEN TRUE ELSE FALSE END AS flag_valor_invalido
        FROM bronze.raw_propostas_credito p
        LEFT JOIN silver.clientes cli
            ON p.cliente_id = cli.cliente_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.contratos_credito AS
        SELECT
            c.contrato_id,
            c.proposta_id,
            c.cliente_id,
            UPPER(TRIM(c.produto_credito)) AS produto_credito,
            UPPER(TRIM(c.canal_contratacao)) AS canal_contratacao,
            TRY_CAST(c.data_proposta AS DATE) AS data_proposta,
            TRY_CAST(c.data_contratacao AS DATE) AS data_contratacao,
            STRFTIME(TRY_CAST(c.data_contratacao AS DATE), '%Y-%m') AS safra_contratacao,
            TRY_CAST(c.data_liberacao_credito AS DATE) AS data_liberacao_credito,
            TRY_CAST(c.data_primeiro_vencimento AS DATE) AS data_primeiro_vencimento,
            TRY_CAST(c.valor_contratado AS DOUBLE) AS valor_contratado,
            TRY_CAST(c.valor_liberado AS DOUBLE) AS valor_liberado,
            TRY_CAST(c.prazo_meses AS INTEGER) AS prazo_meses,
            TRY_CAST(c.taxa_mensal AS DOUBLE) AS taxa_mensal,
            TRY_CAST(c.parcela AS DOUBLE) AS parcela,
            CASE
                WHEN TRY_CAST(c.saldo_devedor AS DOUBLE) < 0 THEN NULL
                ELSE TRY_CAST(c.saldo_devedor AS DOUBLE)
            END AS saldo_devedor_tratado,
            TRY_CAST(c.saldo_devedor AS DOUBLE) AS saldo_devedor_original,
            TRY_CAST(c.dias_atraso_atual AS INTEGER) AS dias_atraso_atual,
            UPPER(TRIM(c.status_contrato)) AS status_contrato,
            CASE
                WHEN TRY_CAST(c.dias_atraso_atual AS INTEGER) = 0 THEN 'ADIMPLENTE'
                WHEN TRY_CAST(c.dias_atraso_atual AS INTEGER) BETWEEN 1 AND 30 THEN 'ATRASO_1_30'
                WHEN TRY_CAST(c.dias_atraso_atual AS INTEGER) BETWEEN 31 AND 60 THEN 'ATRASO_31_60'
                WHEN TRY_CAST(c.dias_atraso_atual AS INTEGER) BETWEEN 61 AND 90 THEN 'ATRASO_61_90'
                ELSE 'NPL_90_PLUS'
            END AS bucket_atraso,
            TRY_CAST(c.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            c.origem_sistema,
            c.arquivo_origem,
            CASE WHEN cli.cliente_id IS NULL THEN TRUE ELSE FALSE END AS flag_cliente_orfao,
            CASE WHEN p.proposta_id IS NULL THEN TRUE ELSE FALSE END AS flag_proposta_orfa,
            CASE WHEN TRY_CAST(c.saldo_devedor AS DOUBLE) < 0 THEN TRUE ELSE FALSE END AS flag_saldo_negativo,
            CASE
                WHEN TRY_CAST(c.data_contratacao AS DATE) < TRY_CAST(c.data_proposta AS DATE)
                THEN TRUE ELSE FALSE
            END AS flag_data_contratacao_inconsistente
        FROM bronze.raw_contratos_credito c
        LEFT JOIN silver.clientes cli
            ON c.cliente_id = cli.cliente_id
        LEFT JOIN silver.propostas_credito p
            ON c.proposta_id = p.proposta_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.parcelas_credito AS
        SELECT
            p.parcela_id,
            p.contrato_id,
            p.cliente_id,
            TRY_CAST(p.numero_parcela AS INTEGER) AS numero_parcela,
            TRY_CAST(p.data_vencimento AS DATE) AS data_vencimento,
            STRFTIME(TRY_CAST(p.data_vencimento AS DATE), '%Y-%m') AS competencia_vencimento,
            TRY_CAST(p.data_pagamento AS DATE) AS data_pagamento,
            STRFTIME(TRY_CAST(p.data_pagamento AS DATE), '%Y-%m') AS competencia_pagamento,
            TRY_CAST(p.valor_parcela AS DOUBLE) AS valor_parcela,
            TRY_CAST(p.valor_pago AS DOUBLE) AS valor_pago,
            TRY_CAST(p.valor_juros AS DOUBLE) AS valor_juros,
            TRY_CAST(p.valor_multa AS DOUBLE) AS valor_multa,
            TRY_CAST(p.dias_atraso AS INTEGER) AS dias_atraso,
            UPPER(TRIM(p.status_parcela)) AS status_parcela,
            TRY_CAST(p.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            p.origem_sistema,
            p.arquivo_origem,
            CASE WHEN c.contrato_id IS NULL THEN TRUE ELSE FALSE END AS flag_contrato_orfao,
            CASE WHEN cli.cliente_id IS NULL THEN TRUE ELSE FALSE END AS flag_cliente_orfao,
            CASE WHEN TRY_CAST(p.valor_pago AS DOUBLE) > TRY_CAST(p.valor_parcela AS DOUBLE) * 1.5 THEN TRUE ELSE FALSE END AS flag_pagamento_maior_que_parcela,
            CASE
                WHEN TRY_CAST(p.data_pagamento AS DATE) IS NOT NULL
                 AND TRY_CAST(p.data_pagamento AS DATE) < TRY_CAST(p.data_vencimento AS DATE) - INTERVAL 60 DAY
                THEN TRUE ELSE FALSE
            END AS flag_data_pagamento_inconsistente
        FROM bronze.raw_parcelas_credito p
        LEFT JOIN silver.contratos_credito c
            ON p.contrato_id = c.contrato_id
        LEFT JOIN silver.clientes cli
            ON p.cliente_id = cli.cliente_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.pagamentos_credito AS
        SELECT
            pg.pagamento_credito_id,
            pg.parcela_id,
            pg.contrato_id,
            pg.cliente_id,
            TRY_CAST(pg.data_pagamento AS DATE) AS data_pagamento,
            TRY_CAST(pg.valor_pagamento AS DOUBLE) AS valor_pagamento,
            UPPER(TRIM(pg.canal_pagamento)) AS canal_pagamento,
            UPPER(TRIM(pg.status_pagamento)) AS status_pagamento,
            TRY_CAST(pg.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            pg.origem_sistema,
            pg.arquivo_origem,
            CASE WHEN p.parcela_id IS NULL THEN TRUE ELSE FALSE END AS flag_parcela_orfa,
            CASE WHEN c.contrato_id IS NULL THEN TRUE ELSE FALSE END AS flag_contrato_orfao,
            CASE WHEN cli.cliente_id IS NULL THEN TRUE ELSE FALSE END AS flag_cliente_orfao
        FROM bronze.raw_pagamentos_credito pg
        LEFT JOIN silver.parcelas_credito p
            ON pg.parcela_id = p.parcela_id
        LEFT JOIN silver.contratos_credito c
            ON pg.contrato_id = c.contrato_id
        LEFT JOIN silver.clientes cli
            ON pg.cliente_id = cli.cliente_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.renegociacoes AS
        SELECT
            r.renegociacao_id,
            r.contrato_id,
            r.cliente_id,
            TRY_CAST(r.data_renegociacao AS DATE) AS data_renegociacao,
            TRY_CAST(r.saldo_renegociado AS DOUBLE) AS saldo_renegociado,
            TRY_CAST(r.novo_prazo_meses AS INTEGER) AS novo_prazo_meses,
            TRY_CAST(r.nova_taxa_mensal AS DOUBLE) AS nova_taxa_mensal,
            UPPER(TRIM(r.motivo_renegociacao)) AS motivo_renegociacao,
            UPPER(TRIM(r.status_renegociacao)) AS status_renegociacao,
            TRY_CAST(r.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            r.origem_sistema,
            r.arquivo_origem,
            CASE WHEN c.contrato_id IS NULL THEN TRUE ELSE FALSE END AS flag_contrato_orfao,
            CASE WHEN cli.cliente_id IS NULL THEN TRUE ELSE FALSE END AS flag_cliente_orfao
        FROM bronze.raw_renegociacoes r
        LEFT JOIN silver.contratos_credito c
            ON r.contrato_id = c.contrato_id
        LEFT JOIN silver.clientes cli
            ON r.cliente_id = cli.cliente_id;
    """)


def create_sdx_gold(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("""
        CREATE OR REPLACE TABLE sdx.funil_credito AS
        SELECT
            safra_proposta,
            produto_credito,
            canal_proposta,
            COUNT(*) AS qtd_propostas,
            SUM(CASE WHEN status_proposta = 'APROVADA' THEN 1 ELSE 0 END) AS qtd_aprovadas,
            SUM(CASE WHEN status_proposta = 'REPROVADA' THEN 1 ELSE 0 END) AS qtd_reprovadas,
            SUM(CASE WHEN status_proposta = 'CANCELADA' THEN 1 ELSE 0 END) AS qtd_canceladas,
            SUM(valor_solicitado) AS valor_solicitado,
            AVG(taxa_ofertada) AS taxa_media_ofertada,
            AVG(comprometimento_renda_estimado) AS comprometimento_medio,
            ROUND(SUM(CASE WHEN status_proposta = 'APROVADA' THEN 1 ELSE 0 END)::DOUBLE / NULLIF(COUNT(*), 0), 4) AS taxa_aprovacao
        FROM silver.propostas_credito
        WHERE flag_cliente_orfao = FALSE
          AND flag_data_futura = FALSE
        GROUP BY safra_proposta, produto_credito, canal_proposta;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE sdx.precificacao_credito AS
        SELECT
            p.proposta_id,
            p.cliente_id,
            p.produto_credito,
            cli.segmento,
            p.rating_motor,
            p.data_proposta,
            p.valor_solicitado,
            p.prazo_meses,
            p.taxa_ofertada,
            pp.taxa_min,
            pp.taxa_max,
            pp.spread_alvo,
            pp.custo_funding,
            CASE
                WHEN pp.taxa_min IS NULL THEN 'SEM_POLITICA'
                WHEN p.taxa_ofertada < pp.taxa_min THEN 'ABAIXO_POLITICA'
                WHEN p.taxa_ofertada > pp.taxa_max THEN 'ACIMA_POLITICA'
                ELSE 'DENTRO_POLITICA'
            END AS aderencia_precificacao,
            p.status_proposta
        FROM silver.propostas_credito p
        LEFT JOIN silver.clientes cli
            ON p.cliente_id = cli.cliente_id
        LEFT JOIN silver.politicas_precificacao pp
            ON p.produto_credito = pp.produto_credito
           AND cli.segmento = pp.segmento
           AND p.rating_motor = pp.rating
           AND p.data_proposta BETWEEN pp.vigencia_inicio AND pp.vigencia_fim
           AND pp.flag_ativa = TRUE;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE sdx.risco_credito_cliente AS
        WITH contratos AS (
            SELECT
                cliente_id,
                COUNT(DISTINCT contrato_id) AS qtd_contratos_credito,
                SUM(valor_contratado) AS valor_total_contratado,
                SUM(COALESCE(saldo_devedor_tratado, 0)) AS saldo_devedor_total,
                AVG(taxa_mensal) AS taxa_media_credito,
                MAX(dias_atraso_atual) AS maior_atraso_credito,
                SUM(CASE WHEN bucket_atraso = 'NPL_90_PLUS' THEN COALESCE(saldo_devedor_tratado, 0) ELSE 0 END) AS saldo_npl_90,
                SUM(CASE WHEN status_contrato = 'RENEGOCIADO' THEN 1 ELSE 0 END) AS qtd_contratos_renegociados,
                MAX(data_contratacao) AS data_ultimo_contrato
            FROM silver.contratos_credito
            WHERE flag_cliente_orfao = FALSE
            GROUP BY cliente_id
        ),

        parcelas AS (
            SELECT
                cliente_id,
                COUNT(*) AS qtd_parcelas,
                SUM(CASE WHEN status_parcela IN ('EM_ATRASO', 'PAGA_EM_ATRASO') THEN 1 ELSE 0 END) AS qtd_parcelas_com_atraso,
                SUM(CASE WHEN status_parcela = 'EM_ATRASO' THEN valor_parcela ELSE 0 END) AS valor_parcelas_em_atraso,
                AVG(COALESCE(dias_atraso, 0)) AS media_dias_atraso_parcelas
            FROM silver.parcelas_credito
            WHERE flag_cliente_orfao = FALSE
            GROUP BY cliente_id
        )

        SELECT
            COALESCE(c.cliente_id, p.cliente_id) AS cliente_id,
            COALESCE(c.qtd_contratos_credito, 0) AS qtd_contratos_credito,
            COALESCE(c.valor_total_contratado, 0) AS valor_total_contratado,
            COALESCE(c.saldo_devedor_total, 0) AS saldo_devedor_total,
            COALESCE(c.taxa_media_credito, 0) AS taxa_media_credito,
            COALESCE(c.maior_atraso_credito, 0) AS maior_atraso_credito,
            COALESCE(c.saldo_npl_90, 0) AS saldo_npl_90,
            COALESCE(c.qtd_contratos_renegociados, 0) AS qtd_contratos_renegociados,
            c.data_ultimo_contrato,
            COALESCE(p.qtd_parcelas, 0) AS qtd_parcelas,
            COALESCE(p.qtd_parcelas_com_atraso, 0) AS qtd_parcelas_com_atraso,
            COALESCE(p.valor_parcelas_em_atraso, 0) AS valor_parcelas_em_atraso,
            COALESCE(p.media_dias_atraso_parcelas, 0) AS media_dias_atraso_parcelas,
            CASE
                WHEN COALESCE(c.maior_atraso_credito, 0) >= 90 THEN 'RISCO_ALTO_CREDITO'
                WHEN COALESCE(c.maior_atraso_credito, 0) >= 30 THEN 'RISCO_MEDIO_CREDITO'
                WHEN COALESCE(c.qtd_contratos_credito, 0) >= 3 AND COALESCE(c.maior_atraso_credito, 0) = 0 THEN 'BOM_TOMADOR'
                WHEN COALESCE(c.qtd_contratos_credito, 0) = 0 THEN 'SEM_CREDITO'
                ELSE 'RISCO_BAIXO_CREDITO'
            END AS cluster_risco_credito
        FROM contratos c
        FULL OUTER JOIN parcelas p
            ON c.cliente_id = p.cliente_id;
    """)

    # Usa a visão Cliente 360 mais nova disponível.
    # Evita UNION entre tabelas com números de colunas diferentes.
    cliente_360_v2_exists = con.execute("""
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'sdx'
          AND table_name = 'cliente_360_v2';
    """).fetchone()[0] > 0

    source_cliente_360 = "sdx.cliente_360_v2" if cliente_360_v2_exists else "sdx.cliente_360"

    con.execute(f"""
        CREATE OR REPLACE TABLE sdx.cliente_360_v3 AS
        SELECT
            c360.*,
            COALESCE(rc.qtd_contratos_credito, 0) AS qtd_contratos_credito,
            COALESCE(rc.valor_total_contratado, 0) AS valor_total_contratado_credito,
            COALESCE(rc.saldo_devedor_total, 0) AS saldo_devedor_credito,
            COALESCE(rc.taxa_media_credito, 0) AS taxa_media_credito,
            COALESCE(rc.maior_atraso_credito, 0) AS maior_atraso_credito,
            COALESCE(rc.saldo_npl_90, 0) AS saldo_npl_90,
            COALESCE(rc.qtd_contratos_renegociados, 0) AS qtd_contratos_renegociados,
            rc.data_ultimo_contrato,
            COALESCE(rc.qtd_parcelas_com_atraso, 0) AS qtd_parcelas_credito_com_atraso,
            COALESCE(rc.valor_parcelas_em_atraso, 0) AS valor_parcelas_credito_em_atraso,
            COALESCE(rc.cluster_risco_credito, 'SEM_CREDITO') AS cluster_risco_credito,
            CASE
                WHEN COALESCE(rc.maior_atraso_credito, 0) >= 90 THEN TRUE
                WHEN COALESCE(rc.saldo_npl_90, 0) > 0 THEN TRUE
                ELSE FALSE
            END AS flag_risco_credito
        FROM {source_cliente_360} c360
        LEFT JOIN sdx.risco_credito_cliente rc
            ON c360.cliente_id = rc.cliente_id;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE gold.kpi_carteira_credito_mensal AS
        SELECT
            safra_contratacao,
            produto_credito,
            canal_contratacao,
            COUNT(DISTINCT contrato_id) AS qtd_contratos,
            ROUND(SUM(valor_contratado), 2) AS valor_contratado,
            ROUND(SUM(valor_liberado), 2) AS valor_liberado,
            ROUND(SUM(COALESCE(saldo_devedor_tratado, 0)), 2) AS saldo_devedor,
            ROUND(AVG(taxa_mensal), 4) AS taxa_media,
            ROUND(SUM(CASE WHEN bucket_atraso = 'NPL_90_PLUS' THEN COALESCE(saldo_devedor_tratado, 0) ELSE 0 END), 2) AS saldo_npl_90,
            ROUND(SUM(CASE WHEN bucket_atraso = 'NPL_90_PLUS' THEN COALESCE(saldo_devedor_tratado, 0) ELSE 0 END) / NULLIF(SUM(COALESCE(saldo_devedor_tratado, 0)), 0), 4) AS perc_npl_90
        FROM silver.contratos_credito
        WHERE flag_cliente_orfao = FALSE
          AND flag_data_contratacao_inconsistente = FALSE
        GROUP BY safra_contratacao, produto_credito, canal_contratacao;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE gold.kpi_inadimplencia_credito_mensal AS
        SELECT
            competencia_vencimento,
            status_parcela,
            COUNT(*) AS qtd_parcelas,
            ROUND(SUM(valor_parcela), 2) AS valor_parcelas,
            ROUND(SUM(valor_pago), 2) AS valor_pago,
            ROUND(SUM(CASE WHEN dias_atraso > 0 THEN valor_parcela ELSE 0 END), 2) AS valor_em_atraso,
            ROUND(AVG(dias_atraso), 2) AS media_dias_atraso
        FROM silver.parcelas_credito
        WHERE flag_contrato_orfao = FALSE
        GROUP BY competencia_vencimento, status_parcela;
    """)


def create_quality(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("""
        CREATE OR REPLACE TABLE meta.quality_credito AS
        SELECT 'raw_propostas_credito' AS check_name, COUNT(*) AS qtd FROM bronze.raw_propostas_credito
        UNION ALL SELECT 'raw_contratos_credito', COUNT(*) FROM bronze.raw_contratos_credito
        UNION ALL SELECT 'raw_parcelas_credito', COUNT(*) FROM bronze.raw_parcelas_credito
        UNION ALL SELECT 'raw_pagamentos_credito', COUNT(*) FROM bronze.raw_pagamentos_credito
        UNION ALL SELECT 'silver_propostas_credito', COUNT(*) FROM silver.propostas_credito
        UNION ALL SELECT 'silver_contratos_credito', COUNT(*) FROM silver.contratos_credito
        UNION ALL SELECT 'silver_parcelas_credito', COUNT(*) FROM silver.parcelas_credito
        UNION ALL SELECT 'silver_pagamentos_credito', COUNT(*) FROM silver.pagamentos_credito
        UNION ALL SELECT 'propostas_cliente_orfao', COUNT(*) FROM silver.propostas_credito WHERE flag_cliente_orfao = TRUE
        UNION ALL SELECT 'propostas_score_motor_nulo', COUNT(*) FROM silver.propostas_credito WHERE flag_score_motor_nulo = TRUE
        UNION ALL SELECT 'propostas_data_futura', COUNT(*) FROM silver.propostas_credito WHERE flag_data_futura = TRUE
        UNION ALL SELECT 'contratos_cliente_orfao', COUNT(*) FROM silver.contratos_credito WHERE flag_cliente_orfao = TRUE
        UNION ALL SELECT 'contratos_proposta_orfa', COUNT(*) FROM silver.contratos_credito WHERE flag_proposta_orfa = TRUE
        UNION ALL SELECT 'contratos_saldo_negativo', COUNT(*) FROM silver.contratos_credito WHERE flag_saldo_negativo = TRUE
        UNION ALL SELECT 'contratos_data_inconsistente', COUNT(*) FROM silver.contratos_credito WHERE flag_data_contratacao_inconsistente = TRUE
        UNION ALL SELECT 'parcelas_contrato_orfao', COUNT(*) FROM silver.parcelas_credito WHERE flag_contrato_orfao = TRUE
        UNION ALL SELECT 'parcelas_pagamento_maior_que_parcela', COUNT(*) FROM silver.parcelas_credito WHERE flag_pagamento_maior_que_parcela = TRUE
        UNION ALL SELECT 'clientes_com_contrato_credito', COUNT(DISTINCT cliente_id) FROM silver.contratos_credito WHERE flag_cliente_orfao = FALSE
        UNION ALL SELECT 'clientes_com_npl_90', COUNT(DISTINCT cliente_id) FROM silver.contratos_credito WHERE bucket_atraso = 'NPL_90_PLUS';
    """)


def print_summary(con: duckdb.DuckDBPyConnection) -> None:
    print("\nChecks de qualidade:")
    rows = con.execute("""
        SELECT check_name, qtd
        FROM meta.quality_credito
        ORDER BY check_name;
    """).fetchall()

    for check_name, qtd in rows:
        print(f"- {check_name}: {qtd:,}".replace(",", "."))

    print("\nAmostra silver.propostas_credito:")
    print(con.execute("""
        SELECT proposta_id, cliente_id, produto_credito, data_proposta, valor_solicitado, taxa_ofertada, status_proposta, motivo_recusa
        FROM silver.propostas_credito
        ORDER BY proposta_id
        LIMIT 5;
    """).fetchdf().to_string(index=False))

    print("\nAmostra silver.contratos_credito:")
    print(con.execute("""
        SELECT contrato_id, cliente_id, produto_credito, safra_contratacao, valor_contratado, saldo_devedor_tratado, bucket_atraso, status_contrato
        FROM silver.contratos_credito
        ORDER BY contrato_id
        LIMIT 5;
    """).fetchdf().to_string(index=False))

    print("\nKPIs carteira crédito - top 5:")
    print(con.execute("""
        SELECT safra_contratacao, produto_credito, qtd_contratos, valor_contratado, saldo_devedor, perc_npl_90
        FROM gold.kpi_carteira_credito_mensal
        ORDER BY valor_contratado DESC
        LIMIT 5;
    """).fetchdf().to_string(index=False))


def main() -> None:
    assert_project_root()
    ensure_files()

    con = duckdb.connect(str(DB_PATH))
    print("Aurora Bank — Bronze -> Silver Crédito")
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
    print("- silver.propostas_credito")
    print("- silver.contratos_credito")
    print("- silver.parcelas_credito")
    print("- sdx.funil_credito")
    print("- sdx.risco_credito_cliente")
    print("- sdx.cliente_360_v3")
    print("- gold.kpi_carteira_credito_mensal")
    print("- meta.quality_credito")


if __name__ == "__main__":
    main()
