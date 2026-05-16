"""
Aurora Bank Enterprise Data Lab
Patch 02 — Registrar Bronze e criar Silver Clientes

Execute dentro da pasta do projeto:

    python .\scripts\02_create_bronze_silver_clientes.py

Pré-requisito:
    Ter rodado antes:
    python .\scripts\01_generate_bronze_clientes.py --mode dev --overwrite

Este script:
    1. Cria/valida o banco database/aurora_bank.duckdb
    2. Cria schemas: bronze, silver, sdx, gold, meta
    3. Registra os arquivos Parquet da camada Bronze como views
    4. Cria tabelas Silver tratadas para Clientes
    5. Cria uma primeira sdx.cliente_360_base
    6. Cria checks de qualidade e contagens
"""

from __future__ import annotations

from pathlib import Path
import sys
import duckdb


DB_PATH = Path("database/aurora_bank.duckdb")

BRONZE_TABLES = {
    "raw_clientes_core": Path("data/bronze/raw_clientes_core"),
    "raw_clientes_app": Path("data/bronze/raw_clientes_app"),
    "raw_enderecos": Path("data/bronze/raw_enderecos"),
    "raw_contatos": Path("data/bronze/raw_contatos"),
    "raw_scores_cliente": Path("data/bronze/raw_scores_cliente"),
    "raw_segmentos_cliente": Path("data/bronze/raw_segmentos_cliente"),
}


def assert_project_root() -> None:
    if not Path("README.md").exists() or not Path("scripts").exists():
        print("ERRO: execute este script dentro da pasta raiz do projeto aurora_bank_enterprise_v1.")
        print("Exemplo:")
        print(r'cd "D:\Banco de dados\aurora_bank_enterprise_v1_scaffold\aurora_bank_enterprise_v1"')
        sys.exit(1)


def ensure_bronze_files() -> None:
    missing = []
    for table_name, folder in BRONZE_TABLES.items():
        files = list(folder.glob("*.parquet"))
        if not files:
            missing.append((table_name, folder))
    if missing:
        print("ERRO: não encontrei arquivos Parquet da camada Bronze.")
        print("Rode antes:")
        print(r"python .\scripts\01_generate_bronze_clientes.py --mode dev --overwrite")
        print("\nPastas sem arquivos:")
        for table_name, folder in missing:
            print(f"- {table_name}: {folder}")
        sys.exit(1)


def path_glob(folder: Path) -> str:
    return (folder / "*.parquet").as_posix()


def create_schemas(con: duckdb.DuckDBPyConnection) -> None:
    for schema in ["bronze", "silver", "sdx", "gold", "meta"]:
        con.execute(f"CREATE SCHEMA IF NOT EXISTS {schema};")


def create_bronze_views(con: duckdb.DuckDBPyConnection) -> None:
    for table_name, folder in BRONZE_TABLES.items():
        glob_path = path_glob(folder)
        con.execute(f"""
            CREATE OR REPLACE VIEW bronze.{table_name} AS
            SELECT *
            FROM read_parquet('{glob_path}', union_by_name = true);
        """)


def create_silver_tables(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("""
        CREATE OR REPLACE TABLE silver.scores_cliente_historico AS
        SELECT
            score_hist_id,
            cliente_id,
            TRY_CAST(data_referencia AS DATE) AS data_referencia,
            TRY_CAST(score_credito AS INTEGER) AS score_credito,
            fonte_score,
            TRY_CAST(dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            origem_sistema
        FROM bronze.raw_scores_cliente;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.segmentos_cliente_historico AS
        SELECT
            segmento_hist_id,
            cliente_id,
            TRY_CAST(data_inicio_vigencia AS DATE) AS data_inicio_vigencia,
            TRY_CAST(data_fim_vigencia AS DATE) AS data_fim_vigencia,
            UPPER(TRIM(segmento)) AS segmento,
            UPPER(TRIM(motivo_segmentacao)) AS motivo_segmentacao,
            TRY_CAST(dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            origem_sistema
        FROM bronze.raw_segmentos_cliente;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.enderecos AS
        SELECT
            endereco_id,
            cliente_id,
            UPPER(TRIM(tipo_endereco)) AS tipo_endereco,
            UPPER(TRIM(cidade)) AS cidade,
            UPPER(TRIM(uf)) AS uf,
            UPPER(TRIM(regiao)) AS regiao,
            cep_prefixo,
            TRY_CAST(flag_endereco_principal AS BOOLEAN) AS flag_endereco_principal,
            TRY_CAST(data_atualizacao AS DATE) AS data_atualizacao,
            TRY_CAST(dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            origem_sistema
        FROM bronze.raw_enderecos;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.contatos AS
        SELECT
            contato_id,
            cliente_id,
            LOWER(TRIM(email)) AS email,
            REGEXP_REPLACE(CAST(telefone_celular AS VARCHAR), '[^0-9]', '', 'g') AS telefone_celular,
            TRY_CAST(flag_email_validado AS BOOLEAN) AS flag_email_validado,
            TRY_CAST(flag_telefone_validado AS BOOLEAN) AS flag_telefone_validado,
            TRY_CAST(aceita_marketing AS BOOLEAN) AS aceita_marketing,
            TRY_CAST(data_atualizacao AS DATE) AS data_atualizacao,
            TRY_CAST(dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            origem_sistema
        FROM bronze.raw_contatos;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE silver.clientes AS
        WITH core_base AS (
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cpf_hash
                    ORDER BY
                        TRY_CAST(data_ultima_atualizacao_cadastral AS DATE) DESC NULLS LAST,
                        cliente_id DESC
                ) AS rn_cpf
            FROM bronze.raw_clientes_core
            WHERE cliente_id IS NOT NULL
              AND cpf_hash IS NOT NULL
        ),

        core_dedup AS (
            SELECT *
            FROM core_base
            WHERE rn_cpf = 1
        ),

        score_atual AS (
            SELECT
                cliente_id,
                score_credito AS score_credito_atual_hist,
                data_referencia AS data_referencia_score,
                fonte_score,
                ROW_NUMBER() OVER (
                    PARTITION BY cliente_id
                    ORDER BY data_referencia DESC NULLS LAST
                ) AS rn
            FROM silver.scores_cliente_historico
        ),

        segmento_atual AS (
            SELECT
                cliente_id,
                segmento AS segmento_atual_hist,
                motivo_segmentacao,
                data_inicio_vigencia,
                ROW_NUMBER() OVER (
                    PARTITION BY cliente_id
                    ORDER BY data_inicio_vigencia DESC NULLS LAST
                ) AS rn
            FROM silver.segmentos_cliente_historico
        ),

        app_atual AS (
            SELECT
                cliente_id,
                status_app,
                TRY_CAST(data_primeiro_login AS DATE) AS data_primeiro_login,
                TRY_CAST(data_ultimo_login AS DATE) AS data_ultimo_login,
                UPPER(TRIM(canal_preferido)) AS canal_preferido,
                TRY_CAST(flag_push_ativo AS BOOLEAN) AS flag_push_ativo,
                UPPER(TRIM(device_principal)) AS device_principal,
                app_version,
                ROW_NUMBER() OVER (
                    PARTITION BY cliente_id
                    ORDER BY TRY_CAST(data_ultimo_login AS DATE) DESC NULLS LAST
                ) AS rn
            FROM bronze.raw_clientes_app
        ),

        endereco_atual AS (
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cliente_id
                    ORDER BY data_atualizacao DESC NULLS LAST
                ) AS rn
            FROM silver.enderecos
        ),

        contato_atual AS (
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cliente_id
                    ORDER BY data_atualizacao DESC NULLS LAST
                ) AS rn
            FROM silver.contatos
        )

        SELECT
            c.cliente_id,
            c.cpf_hash,
            TRIM(c.nome) AS nome,
            TRY_CAST(c.data_nascimento AS DATE) AS data_nascimento,

            CASE
                WHEN TRY_CAST(c.data_nascimento AS DATE) IS NOT NULL
                    THEN DATE_DIFF('year', TRY_CAST(c.data_nascimento AS DATE), DATE '2026-12-31')
                ELSE TRY_CAST(c.idade_aproximada AS INTEGER)
            END AS idade_atual,

            CASE
                WHEN
                    CASE
                        WHEN TRY_CAST(c.data_nascimento AS DATE) IS NOT NULL
                            THEN DATE_DIFF('year', TRY_CAST(c.data_nascimento AS DATE), DATE '2026-12-31')
                        ELSE TRY_CAST(c.idade_aproximada AS INTEGER)
                    END < 25 THEN '18-24'
                WHEN
                    CASE
                        WHEN TRY_CAST(c.data_nascimento AS DATE) IS NOT NULL
                            THEN DATE_DIFF('year', TRY_CAST(c.data_nascimento AS DATE), DATE '2026-12-31')
                        ELSE TRY_CAST(c.idade_aproximada AS INTEGER)
                    END BETWEEN 25 AND 34 THEN '25-34'
                WHEN
                    CASE
                        WHEN TRY_CAST(c.data_nascimento AS DATE) IS NOT NULL
                            THEN DATE_DIFF('year', TRY_CAST(c.data_nascimento AS DATE), DATE '2026-12-31')
                        ELSE TRY_CAST(c.idade_aproximada AS INTEGER)
                    END BETWEEN 35 AND 44 THEN '35-44'
                WHEN
                    CASE
                        WHEN TRY_CAST(c.data_nascimento AS DATE) IS NOT NULL
                            THEN DATE_DIFF('year', TRY_CAST(c.data_nascimento AS DATE), DATE '2026-12-31')
                        ELSE TRY_CAST(c.idade_aproximada AS INTEGER)
                    END BETWEEN 45 AND 54 THEN '45-54'
                WHEN
                    CASE
                        WHEN TRY_CAST(c.data_nascimento AS DATE) IS NOT NULL
                            THEN DATE_DIFF('year', TRY_CAST(c.data_nascimento AS DATE), DATE '2026-12-31')
                        ELSE TRY_CAST(c.idade_aproximada AS INTEGER)
                    END BETWEEN 55 AND 64 THEN '55-64'
                ELSE '65+'
            END AS faixa_etaria,

            UPPER(TRIM(c.genero)) AS genero,
            COALESCE(UPPER(TRIM(c.estado_civil)), 'NAO_INFORMADO') AS estado_civil,

            COALESCE(e.cidade, UPPER(TRIM(c.cidade))) AS cidade,
            COALESCE(e.uf, UPPER(TRIM(c.uf))) AS uf,
            COALESCE(e.regiao, UPPER(TRIM(c.regiao))) AS regiao,

            CASE
                WHEN TRY_CAST(c.renda_mensal AS DOUBLE) <= 0 THEN NULL
                WHEN TRY_CAST(c.renda_mensal AS DOUBLE) > 250000 THEN NULL
                ELSE ROUND(TRY_CAST(c.renda_mensal AS DOUBLE), 2)
            END AS renda_mensal_tratada,

            TRY_CAST(c.renda_mensal AS DOUBLE) AS renda_mensal_original,

            CASE
                WHEN TRY_CAST(c.renda_mensal AS DOUBLE) IS NULL THEN 'NAO_INFORMADO'
                WHEN TRY_CAST(c.renda_mensal AS DOUBLE) <= 0 THEN 'SEM_RENDA'
                WHEN TRY_CAST(c.renda_mensal AS DOUBLE) <= 1412 THEN 'ATE_1_SM'
                WHEN TRY_CAST(c.renda_mensal AS DOUBLE) <= 3000 THEN '1_A_3K'
                WHEN TRY_CAST(c.renda_mensal AS DOUBLE) <= 6000 THEN '3K_A_6K'
                WHEN TRY_CAST(c.renda_mensal AS DOUBLE) <= 10000 THEN '6K_A_10K'
                WHEN TRY_CAST(c.renda_mensal AS DOUBLE) <= 20000 THEN '10K_A_20K'
                WHEN TRY_CAST(c.renda_mensal AS DOUBLE) <= 250000 THEN '20K_PLUS'
                ELSE 'OUTLIER'
            END AS faixa_renda,

            UPPER(TRIM(c.profissao)) AS profissao,
            UPPER(TRIM(c.tipo_ocupacao)) AS tipo_ocupacao,
            COALESCE(UPPER(TRIM(c.escolaridade)), 'NAO_INFORMADO') AS escolaridade,

            COALESCE(s.score_credito_atual_hist, TRY_CAST(c.score_credito AS INTEGER)) AS score_credito,

            CASE
                WHEN COALESCE(s.score_credito_atual_hist, TRY_CAST(c.score_credito AS INTEGER)) IS NULL THEN 'SEM_SCORE'
                WHEN COALESCE(s.score_credito_atual_hist, TRY_CAST(c.score_credito AS INTEGER)) >= 760 THEN 'A'
                WHEN COALESCE(s.score_credito_atual_hist, TRY_CAST(c.score_credito AS INTEGER)) >= 650 THEN 'B'
                WHEN COALESCE(s.score_credito_atual_hist, TRY_CAST(c.score_credito AS INTEGER)) >= 520 THEN 'C'
                ELSE 'D'
            END AS rating_cliente,

            COALESCE(seg.segmento_atual_hist, UPPER(TRIM(c.segmento_core)), 'NAO_INFORMADO') AS segmento,

            UPPER(TRIM(c.canal_aquisicao)) AS canal_aquisicao,
            TRY_CAST(c.data_cadastro AS DATE) AS data_cadastro,
            TRY_CAST(c.data_inicio_relacionamento AS DATE) AS data_inicio_relacionamento,
            TRY_CAST(c.data_ultima_atualizacao_cadastral AS DATE) AS data_ultima_atualizacao_cadastral,

            UPPER(TRIM(c.status_cliente_core)) AS status_cliente_core,
            COALESCE(UPPER(TRIM(app.status_app)), 'SEM_APP') AS status_app,

            CASE
                WHEN UPPER(TRIM(c.status_cliente_core)) IN ('ATIVO', 'EM_ANALISE')
                  OR UPPER(TRIM(app.status_app)) = 'ATIVO'
                THEN TRUE
                ELSE FALSE
            END AS flag_cliente_ativo,

            app.data_primeiro_login,
            app.data_ultimo_login,
            DATE_DIFF('day', app.data_ultimo_login, DATE '2026-12-31') AS dias_desde_ultimo_login,
            app.canal_preferido,
            app.flag_push_ativo,
            app.device_principal,
            app.app_version,

            ct.email,
            ct.telefone_celular,
            ct.flag_email_validado,
            ct.flag_telefone_validado,
            ct.aceita_marketing,

            DATE_DIFF('day', TRY_CAST(c.data_cadastro AS DATE), DATE '2026-12-31') AS dias_desde_cadastro,
            DATE_DIFF('day', TRY_CAST(c.data_inicio_relacionamento AS DATE), DATE '2026-12-31') AS dias_relacionamento,

            -- Flags de qualidade
            CASE WHEN c.rn_cpf > 1 THEN TRUE ELSE FALSE END AS flag_cpf_duplicado_removido,
            CASE WHEN TRY_CAST(c.renda_mensal AS DOUBLE) IS NULL THEN TRUE ELSE FALSE END AS flag_renda_nula,
            CASE WHEN TRY_CAST(c.renda_mensal AS DOUBLE) <= 0 THEN TRUE ELSE FALSE END AS flag_renda_zero_ou_negativa,
            CASE WHEN TRY_CAST(c.renda_mensal AS DOUBLE) > 250000 THEN TRUE ELSE FALSE END AS flag_renda_outlier,
            CASE WHEN COALESCE(s.score_credito_atual_hist, TRY_CAST(c.score_credito AS INTEGER)) IS NULL THEN TRUE ELSE FALSE END AS flag_score_ausente,
            CASE WHEN TRY_CAST(c.data_nascimento AS DATE) IS NULL THEN TRUE ELSE FALSE END AS flag_data_nascimento_ausente,
            CASE WHEN COALESCE(e.uf, UPPER(TRIM(c.uf))) IS NULL THEN TRUE ELSE FALSE END AS flag_uf_ausente,

            TRY_CAST(c.dt_ingestao AS TIMESTAMP) AS dt_ingestao,
            c.origem_sistema,
            c.arquivo_origem

        FROM core_dedup c
        LEFT JOIN score_atual s
            ON c.cliente_id = s.cliente_id
           AND s.rn = 1
        LEFT JOIN segmento_atual seg
            ON c.cliente_id = seg.cliente_id
           AND seg.rn = 1
        LEFT JOIN app_atual app
            ON c.cliente_id = app.cliente_id
           AND app.rn = 1
        LEFT JOIN endereco_atual e
            ON c.cliente_id = e.cliente_id
           AND e.rn = 1
        LEFT JOIN contato_atual ct
            ON c.cliente_id = ct.cliente_id
           AND ct.rn = 1;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE sdx.cliente_360_base AS
        SELECT
            cliente_id,
            cpf_hash,
            nome,
            idade_atual,
            faixa_etaria,
            genero,
            estado_civil,
            cidade,
            uf,
            regiao,
            renda_mensal_tratada AS renda_mensal,
            faixa_renda,
            profissao,
            tipo_ocupacao,
            escolaridade,
            score_credito,
            rating_cliente,
            segmento,
            canal_aquisicao,
            data_cadastro,
            data_inicio_relacionamento,
            dias_desde_cadastro,
            dias_relacionamento,
            data_ultimo_login,
            dias_desde_ultimo_login,
            canal_preferido,
            device_principal,
            status_cliente_core,
            status_app,
            flag_cliente_ativo,
            aceita_marketing,
            CASE
                WHEN flag_cliente_ativo = FALSE THEN 'INATIVO'
                WHEN dias_desde_ultimo_login IS NULL THEN 'SEM_APP'
                WHEN dias_desde_ultimo_login > 180 THEN 'BAIXO_ENGAJAMENTO'
                WHEN dias_desde_ultimo_login > 90 THEN 'ENGAJAMENTO_MEDIO'
                ELSE 'ENGAJADO'
            END AS cluster_engajamento_digital,
            CASE
                WHEN rating_cliente IN ('A', 'B') AND renda_mensal_tratada >= 6000 THEN 'ALTO_POTENCIAL'
                WHEN rating_cliente IN ('A', 'B', 'C') AND renda_mensal_tratada >= 3000 THEN 'MEDIO_POTENCIAL'
                WHEN rating_cliente = 'D' OR score_credito IS NULL THEN 'RISCO/SEM_SCORE'
                ELSE 'BAIXO_POTENCIAL'
            END AS cluster_potencial_credito
        FROM silver.clientes;
    """)


def create_quality_tables(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("""
        CREATE OR REPLACE TABLE meta.contagem_tabelas_clientes AS
        SELECT 'bronze.raw_clientes_core' AS tabela, COUNT(*) AS qtd_linhas FROM bronze.raw_clientes_core
        UNION ALL SELECT 'bronze.raw_clientes_app', COUNT(*) FROM bronze.raw_clientes_app
        UNION ALL SELECT 'bronze.raw_enderecos', COUNT(*) FROM bronze.raw_enderecos
        UNION ALL SELECT 'bronze.raw_contatos', COUNT(*) FROM bronze.raw_contatos
        UNION ALL SELECT 'bronze.raw_scores_cliente', COUNT(*) FROM bronze.raw_scores_cliente
        UNION ALL SELECT 'bronze.raw_segmentos_cliente', COUNT(*) FROM bronze.raw_segmentos_cliente
        UNION ALL SELECT 'silver.clientes', COUNT(*) FROM silver.clientes
        UNION ALL SELECT 'silver.enderecos', COUNT(*) FROM silver.enderecos
        UNION ALL SELECT 'silver.contatos', COUNT(*) FROM silver.contatos
        UNION ALL SELECT 'silver.scores_cliente_historico', COUNT(*) FROM silver.scores_cliente_historico
        UNION ALL SELECT 'silver.segmentos_cliente_historico', COUNT(*) FROM silver.segmentos_cliente_historico
        UNION ALL SELECT 'sdx.cliente_360_base', COUNT(*) FROM sdx.cliente_360_base;
    """)

    con.execute("""
        CREATE OR REPLACE TABLE meta.quality_clientes AS
        SELECT 'clientes_bronze_core' AS check_name, COUNT(*) AS qtd FROM bronze.raw_clientes_core
        UNION ALL SELECT 'clientes_silver', COUNT(*) FROM silver.clientes
        UNION ALL SELECT 'clientes_com_renda_nula', COUNT(*) FROM silver.clientes WHERE flag_renda_nula = TRUE
        UNION ALL SELECT 'clientes_com_renda_zero_ou_negativa', COUNT(*) FROM silver.clientes WHERE flag_renda_zero_ou_negativa = TRUE
        UNION ALL SELECT 'clientes_com_renda_outlier', COUNT(*) FROM silver.clientes WHERE flag_renda_outlier = TRUE
        UNION ALL SELECT 'clientes_sem_score', COUNT(*) FROM silver.clientes WHERE flag_score_ausente = TRUE
        UNION ALL SELECT 'clientes_sem_data_nascimento', COUNT(*) FROM silver.clientes WHERE flag_data_nascimento_ausente = TRUE
        UNION ALL SELECT 'clientes_sem_uf', COUNT(*) FROM silver.clientes WHERE flag_uf_ausente = TRUE
        UNION ALL SELECT 'clientes_sem_app', COUNT(*) FROM silver.clientes WHERE status_app = 'SEM_APP'
        UNION ALL SELECT 'clientes_ativos', COUNT(*) FROM silver.clientes WHERE flag_cliente_ativo = TRUE
        UNION ALL SELECT 'clientes_inativos', COUNT(*) FROM silver.clientes WHERE flag_cliente_ativo = FALSE;
    """)


def print_summary(con: duckdb.DuckDBPyConnection) -> None:
    print("\nContagem de tabelas:")
    rows = con.execute("""
        SELECT tabela, qtd_linhas
        FROM meta.contagem_tabelas_clientes
        ORDER BY tabela;
    """).fetchall()

    for tabela, qtd in rows:
        print(f"- {tabela}: {qtd:,}".replace(",", "."))

    print("\nChecks de qualidade:")
    checks = con.execute("""
        SELECT check_name, qtd
        FROM meta.quality_clientes
        ORDER BY check_name;
    """).fetchall()

    for check_name, qtd in checks:
        print(f"- {check_name}: {qtd:,}".replace(",", "."))

    print("\nAmostra da Silver:")
    sample = con.execute("""
        SELECT
            cliente_id,
            nome,
            idade_atual,
            faixa_etaria,
            uf,
            renda_mensal_tratada,
            score_credito,
            rating_cliente,
            segmento,
            flag_cliente_ativo
        FROM silver.clientes
        ORDER BY cliente_id
        LIMIT 5;
    """).fetchdf()

    print(sample.to_string(index=False))


def main() -> None:
    assert_project_root()
    ensure_bronze_files()

    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB_PATH))

    print("Aurora Bank — Bronze -> Silver Clientes")
    print("=" * 70)
    print(f"Banco: {DB_PATH}")
    print("Criando schemas...")
    create_schemas(con)

    print("Registrando views Bronze...")
    create_bronze_views(con)

    print("Criando tabelas Silver e SDX...")
    create_silver_tables(con)

    print("Criando checks de qualidade...")
    create_quality_tables(con)

    print_summary(con)

    con.close()

    print("\nProcesso concluído com sucesso.")
    print("Agora você já pode consultar:")
    print("- bronze.raw_clientes_core")
    print("- silver.clientes")
    print("- sdx.cliente_360_base")
    print("- meta.quality_clientes")


if __name__ == "__main__":
    main()
