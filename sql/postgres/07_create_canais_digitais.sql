-- ============================================================
-- Aurora Bank Enterprise Data Lab
-- Patch 09 — Canais Digitais
-- Banco destino: PostgreSQL
-- ============================================================
--
-- Objetivo:
-- Criar o domínio de canais digitais no Aurora Bank V1.
--
-- Tabelas criadas:
-- - silver.sessoes_digitais
-- - silver.eventos_digitais
-- - silver.erros_app
-- - sdx.comportamento_digital_cliente
-- - sdx.funil_digital
-- - sdx.cliente_360_v6
-- - gold.kpi_canais_digitais_mensal
-- - gold.dw_canais_digitais
-- - meta.quality_canais_digitais
--
-- Execute no PostgreSQL conectado ao banco aurora_bank.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS sdx;
CREATE SCHEMA IF NOT EXISTS gold;
CREATE SCHEMA IF NOT EXISTS meta;

-- ============================================================
-- Limpeza controlada
-- ============================================================

DROP TABLE IF EXISTS gold.dw_canais_digitais;
DROP TABLE IF EXISTS gold.kpi_canais_digitais_mensal;
DROP TABLE IF EXISTS sdx.cliente_360_v6;
DROP TABLE IF EXISTS sdx.funil_digital;
DROP TABLE IF EXISTS sdx.comportamento_digital_cliente;
DROP TABLE IF EXISTS silver.erros_app;
DROP TABLE IF EXISTS silver.eventos_digitais;
DROP TABLE IF EXISTS silver.sessoes_digitais;
DROP TABLE IF EXISTS meta.quality_canais_digitais;

-- ============================================================
-- 1. Sessões digitais
-- ============================================================
--
-- Geração baseada em clientes existentes no Cliente 360 V5.
-- Cada cliente elegível pode ter de 1 a 5 sessões simuladas.
-- ============================================================

CREATE TABLE silver.sessoes_digitais AS
WITH clientes_digitais AS (
    SELECT
        c.cliente_id AS num_pes,
        c.segmento,
        c.rating_cliente,
        c.score_credito,
        c.flag_cliente_ativo,
        c.cluster_atividade_financeira,
        c.cluster_crm,
        c.proxima_melhor_acao
    FROM sdx.cliente_360_v5 c
    WHERE c.flag_cliente_ativo = TRUE
       OR c.cluster_crm IN ('CONVERTIDO', 'RESPONSIVO', 'INTERESSADO')
       OR c.cluster_atividade_financeira IN ('ALTA_ATIVIDADE', 'ATIVIDADE_MEDIA')
),

base_sessoes AS (
    SELECT
        cd.*,
        gs.n AS seq_sessao
    FROM clientes_digitais cd
    CROSS JOIN generate_series(1, 5) AS gs(n)
    WHERE random() < CASE
        WHEN cd.cluster_atividade_financeira = 'ALTA_ATIVIDADE' THEN 0.70
        WHEN cd.cluster_atividade_financeira = 'ATIVIDADE_MEDIA' THEN 0.48
        WHEN cd.flag_cliente_ativo = TRUE THEN 0.32
        ELSE 0.18
    END
),

sessoes_calc AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY num_pes, seq_sessao) AS sessao_id,
        num_pes,
        seq_sessao,

        CASE
            WHEN random() < 0.78 THEN 'APP'
            ELSE 'WEB'
        END AS canal_digital,

        CASE
            WHEN random() < 0.58 THEN 'ANDROID'
            WHEN random() < 0.86 THEN 'IOS'
            ELSE 'WEB'
        END AS device,

        CASE
            WHEN random() < 0.58 THEN 'Android'
            WHEN random() < 0.86 THEN 'iOS'
            ELSE 'Windows'
        END AS sistema_operacional,

        CASE
            WHEN proxima_melhor_acao = 'OFERTA_CREDITO' THEN 'SIMULACAO_CREDITO'
            WHEN proxima_melhor_acao = 'OFERTA_CARTAO' THEN 'SOLICITACAO_CARTAO'
            WHEN proxima_melhor_acao = 'OFERTA_PORTABILIDADE' THEN 'PORTABILIDADE'
            WHEN proxima_melhor_acao = 'RETENCAO' THEN 'ATENDIMENTO_RETENCAO'
            WHEN random() < 0.22 THEN 'PAGAMENTO_FATURA'
            WHEN random() < 0.42 THEN 'PIX'
            WHEN random() < 0.62 THEN 'CONSULTA_SALDO'
            WHEN random() < 0.80 THEN 'CONTRATACAO_CREDITO'
            ELSE 'LOGIN'
        END AS jornada,

        (
            DATE '2026-01-01'
            + ((random() * 364)::INTEGER)
            + ((random() * 86400)::INTEGER * INTERVAL '1 second')
        ) AS data_inicio_sessao,

        (60 + random() * 1800)::INTEGER AS duracao_segundos,

        CASE
            WHEN random() < 0.72 THEN 'CONCLUIDA'
            WHEN random() < 0.86 THEN 'ABANDONADA'
            WHEN random() < 0.94 THEN 'ERRO'
            ELSE 'EXPIRADA'
        END AS status_sessao,

        CASE
            WHEN random() < 0.48 THEN 'ORGANICO'
            WHEN random() < 0.66 THEN 'CRM'
            WHEN random() < 0.78 THEN 'PUSH'
            WHEN random() < 0.88 THEN 'MIDIA_PAGA'
            ELSE 'OPEN_FINANCE'
        END AS origem_trafego,

        CASE
            WHEN random() < 0.25 THEN '6.0.0'
            WHEN random() < 0.50 THEN '6.1.2'
            WHEN random() < 0.75 THEN '6.2.0'
            ELSE '6.3.1'
        END AS app_version,

        segmento,
        rating_cliente,
        score_credito,
        cluster_atividade_financeira,
        cluster_crm,
        proxima_melhor_acao

    FROM base_sessoes
)

SELECT
    sessao_id,
    num_pes,
    canal_digital,
    device,
    sistema_operacional,
    jornada,
    data_inicio_sessao,
    data_inicio_sessao + (duracao_segundos * INTERVAL '1 second') AS data_fim_sessao,
    data_inicio_sessao::DATE AS data_sessao,
    TO_CHAR(data_inicio_sessao::DATE, 'YYYY-MM') AS safra_sessao,
    duracao_segundos,
    status_sessao,
    origem_trafego,
    app_version,
    segmento,
    rating_cliente,
    score_credito,
    cluster_atividade_financeira,
    cluster_crm,
    proxima_melhor_acao,
    CASE WHEN status_sessao = 'CONCLUIDA' THEN 1 ELSE 0 END AS flg_sessao_concluida,
    CASE WHEN status_sessao = 'ABANDONADA' THEN 1 ELSE 0 END AS flg_sessao_abandonada,
    CASE WHEN status_sessao = 'ERRO' THEN 1 ELSE 0 END AS flg_sessao_erro,
    CURRENT_TIMESTAMP AS dt_processamento
FROM sessoes_calc;

-- ============================================================
-- 2. Eventos digitais
-- ============================================================

CREATE TABLE silver.eventos_digitais AS
WITH eventos_base AS (
    -- evento obrigatório: login/início
    SELECT
        sessao_id,
        num_pes,
        canal_digital,
        jornada,
        data_inicio_sessao AS data_evento,
        'LOGIN' AS evento,
        1 AS ordem_evento,
        status_sessao
    FROM silver.sessoes_digitais

    UNION ALL

    SELECT
        sessao_id,
        num_pes,
        canal_digital,
        jornada,
        data_inicio_sessao + INTERVAL '10 seconds',
        'INICIO_JORNADA',
        2,
        status_sessao
    FROM silver.sessoes_digitais

    UNION ALL

    SELECT
        sessao_id,
        num_pes,
        canal_digital,
        jornada,
        data_inicio_sessao + ((30 + random() * 120)::INTEGER * INTERVAL '1 second'),
        'VISUALIZOU_OFERTA',
        3,
        status_sessao
    FROM silver.sessoes_digitais
    WHERE jornada IN ('SIMULACAO_CREDITO', 'SOLICITACAO_CARTAO', 'PORTABILIDADE', 'CONTRATACAO_CREDITO')
      AND random() < 0.82

    UNION ALL

    SELECT
        sessao_id,
        num_pes,
        canal_digital,
        jornada,
        data_inicio_sessao + ((90 + random() * 220)::INTEGER * INTERVAL '1 second'),
        'SIMULOU_PRODUTO',
        4,
        status_sessao
    FROM silver.sessoes_digitais
    WHERE jornada IN ('SIMULACAO_CREDITO', 'SOLICITACAO_CARTAO', 'PORTABILIDADE', 'CONTRATACAO_CREDITO')
      AND random() < 0.64

    UNION ALL

    SELECT
        sessao_id,
        num_pes,
        canal_digital,
        jornada,
        data_inicio_sessao + ((160 + random() * 360)::INTEGER * INTERVAL '1 second'),
        'ENVIOU_DADOS',
        5,
        status_sessao
    FROM silver.sessoes_digitais
    WHERE jornada IN ('SIMULACAO_CREDITO', 'SOLICITACAO_CARTAO', 'PORTABILIDADE', 'CONTRATACAO_CREDITO')
      AND status_sessao IN ('CONCLUIDA', 'ABANDONADA')
      AND random() < 0.46

    UNION ALL

    SELECT
        sessao_id,
        num_pes,
        canal_digital,
        jornada,
        data_fim_sessao,
        'CONCLUIU_JORNADA',
        6,
        status_sessao
    FROM silver.sessoes_digitais
    WHERE status_sessao = 'CONCLUIDA'

    UNION ALL

    SELECT
        sessao_id,
        num_pes,
        canal_digital,
        jornada,
        data_fim_sessao,
        'ABANDONOU_JORNADA',
        7,
        status_sessao
    FROM silver.sessoes_digitais
    WHERE status_sessao = 'ABANDONADA'

    UNION ALL

    SELECT
        sessao_id,
        num_pes,
        canal_digital,
        jornada,
        data_fim_sessao,
        'ERRO_APP',
        8,
        status_sessao
    FROM silver.sessoes_digitais
    WHERE status_sessao = 'ERRO'
)

SELECT
    ROW_NUMBER() OVER (ORDER BY sessao_id, ordem_evento, data_evento) AS evento_id,
    sessao_id,
    num_pes,
    canal_digital,
    jornada,
    evento,
    data_evento,
    data_evento::DATE AS data_ref,
    TO_CHAR(data_evento::DATE, 'YYYY-MM') AS safra_evento,
    ordem_evento,
    CASE WHEN evento = 'CONCLUIU_JORNADA' THEN 1 ELSE 0 END AS flg_conclusao,
    CASE WHEN evento = 'ABANDONOU_JORNADA' THEN 1 ELSE 0 END AS flg_abandono,
    CASE WHEN evento = 'ERRO_APP' THEN 1 ELSE 0 END AS flg_erro,
    CURRENT_TIMESTAMP AS dt_processamento
FROM eventos_base;

-- ============================================================
-- 3. Erros de app
-- ============================================================

CREATE TABLE silver.erros_app AS
SELECT
    ROW_NUMBER() OVER (ORDER BY e.evento_id) AS erro_id,
    e.evento_id,
    e.sessao_id,
    e.num_pes,
    e.canal_digital,
    e.jornada,
    e.data_evento AS data_erro,
    e.safra_evento AS safra_erro,
    CASE
        WHEN random() < 0.25 THEN 'TIMEOUT_API'
        WHEN random() < 0.45 THEN 'ERRO_AUTENTICACAO'
        WHEN random() < 0.62 THEN 'FALHA_PAGAMENTO'
        WHEN random() < 0.78 THEN 'ERRO_CADASTRAL'
        WHEN random() < 0.90 THEN 'FALHA_CONEXAO'
        ELSE 'ERRO_GENERICO'
    END AS tipo_erro,
    CASE
        WHEN random() < 0.58 THEN 'BAIXA'
        WHEN random() < 0.86 THEN 'MEDIA'
        ELSE 'ALTA'
    END AS severidade,
    CASE WHEN random() < 0.64 THEN 1 ELSE 0 END AS flg_erro_resolvido,
    CURRENT_TIMESTAMP AS dt_processamento
FROM silver.eventos_digitais e
WHERE e.evento = 'ERRO_APP';

-- ============================================================
-- 4. SDX — Comportamento digital por cliente
-- ============================================================

CREATE TABLE sdx.comportamento_digital_cliente AS
WITH sessoes AS (
    SELECT
        num_pes,
        COUNT(*) AS qtd_sessoes_digitais,
        SUM(flg_sessao_concluida) AS qtd_sessoes_concluidas,
        SUM(flg_sessao_abandonada) AS qtd_sessoes_abandonadas,
        SUM(flg_sessao_erro) AS qtd_sessoes_com_erro,
        AVG(duracao_segundos) AS duracao_media_sessao,
        MAX(data_sessao) AS data_ultima_sessao,
        COUNT(DISTINCT safra_sessao) AS meses_com_sessao,
        SUM(CASE WHEN canal_digital = 'APP' THEN 1 ELSE 0 END) AS qtd_sessoes_app,
        SUM(CASE WHEN canal_digital = 'WEB' THEN 1 ELSE 0 END) AS qtd_sessoes_web
    FROM silver.sessoes_digitais
    GROUP BY num_pes
),

eventos AS (
    SELECT
        num_pes,
        COUNT(*) AS qtd_eventos_digitais,
        SUM(flg_conclusao) AS qtd_conclusoes_jornada,
        SUM(flg_abandono) AS qtd_abandonos_jornada,
        SUM(flg_erro) AS qtd_erros_evento
    FROM silver.eventos_digitais
    GROUP BY num_pes
),

erros AS (
    SELECT
        num_pes,
        COUNT(*) AS qtd_erros_app,
        SUM(CASE WHEN severidade = 'ALTA' THEN 1 ELSE 0 END) AS qtd_erros_alta_severidade,
        SUM(CASE WHEN flg_erro_resolvido = 1 THEN 1 ELSE 0 END) AS qtd_erros_resolvidos
    FROM silver.erros_app
    GROUP BY num_pes
)

SELECT
    COALESCE(s.num_pes, e.num_pes, er.num_pes) AS num_pes,
    COALESCE(s.qtd_sessoes_digitais, 0) AS qtd_sessoes_digitais,
    COALESCE(s.qtd_sessoes_concluidas, 0) AS qtd_sessoes_concluidas,
    COALESCE(s.qtd_sessoes_abandonadas, 0) AS qtd_sessoes_abandonadas,
    COALESCE(s.qtd_sessoes_com_erro, 0) AS qtd_sessoes_com_erro,
    ROUND(COALESCE(s.duracao_media_sessao, 0)::NUMERIC, 2) AS duracao_media_sessao,
    s.data_ultima_sessao,
    CASE
        WHEN s.data_ultima_sessao IS NOT NULL THEN DATE '2026-12-31' - s.data_ultima_sessao
        ELSE NULL
    END AS dias_desde_ultima_sessao,
    COALESCE(s.meses_com_sessao, 0) AS meses_com_sessao,
    COALESCE(s.qtd_sessoes_app, 0) AS qtd_sessoes_app,
    COALESCE(s.qtd_sessoes_web, 0) AS qtd_sessoes_web,
    COALESCE(e.qtd_eventos_digitais, 0) AS qtd_eventos_digitais,
    COALESCE(e.qtd_conclusoes_jornada, 0) AS qtd_conclusoes_jornada,
    COALESCE(e.qtd_abandonos_jornada, 0) AS qtd_abandonos_jornada,
    COALESCE(e.qtd_erros_evento, 0) AS qtd_erros_evento,
    COALESCE(er.qtd_erros_app, 0) AS qtd_erros_app,
    COALESCE(er.qtd_erros_alta_severidade, 0) AS qtd_erros_alta_severidade,
    COALESCE(er.qtd_erros_resolvidos, 0) AS qtd_erros_resolvidos,

    CASE
        WHEN COALESCE(s.qtd_sessoes_digitais, 0) = 0 THEN 'SEM_DIGITAL'
        WHEN COALESCE(s.qtd_sessoes_concluidas, 0) >= 3 AND COALESCE(s.qtd_sessoes_com_erro, 0) = 0 THEN 'DIGITAL_ENGAJADO'
        WHEN COALESCE(s.qtd_sessoes_abandonadas, 0) >= 2 THEN 'ABANDONO_RECORRENTE'
        WHEN COALESCE(s.qtd_sessoes_com_erro, 0) >= 2 THEN 'FRICCAO_DIGITAL'
        ELSE 'DIGITAL_MODERADO'
    END AS cluster_digital

FROM sessoes s
FULL OUTER JOIN eventos e
    ON s.num_pes = e.num_pes
FULL OUTER JOIN erros er
    ON COALESCE(s.num_pes, e.num_pes) = er.num_pes;

-- ============================================================
-- 5. SDX — Funil digital
-- ============================================================

CREATE TABLE sdx.funil_digital AS
SELECT
    s.safra_sessao,
    s.canal_digital,
    s.jornada,
    s.device,
    COUNT(DISTINCT s.sessao_id) AS qtd_sessoes,
    COUNT(DISTINCT s.num_pes) AS qtd_clientes,
    SUM(CASE WHEN e.evento = 'LOGIN' THEN 1 ELSE 0 END) AS qtd_login,
    SUM(CASE WHEN e.evento = 'INICIO_JORNADA' THEN 1 ELSE 0 END) AS qtd_inicio_jornada,
    SUM(CASE WHEN e.evento = 'VISUALIZOU_OFERTA' THEN 1 ELSE 0 END) AS qtd_visualizou_oferta,
    SUM(CASE WHEN e.evento = 'SIMULOU_PRODUTO' THEN 1 ELSE 0 END) AS qtd_simulou_produto,
    SUM(CASE WHEN e.evento = 'ENVIOU_DADOS' THEN 1 ELSE 0 END) AS qtd_enviou_dados,
    SUM(CASE WHEN e.evento = 'CONCLUIU_JORNADA' THEN 1 ELSE 0 END) AS qtd_concluiu_jornada,
    SUM(CASE WHEN e.evento = 'ABANDONOU_JORNADA' THEN 1 ELSE 0 END) AS qtd_abandonou_jornada,
    SUM(CASE WHEN e.evento = 'ERRO_APP' THEN 1 ELSE 0 END) AS qtd_erros,
    ROUND(
        SUM(CASE WHEN e.evento = 'CONCLUIU_JORNADA' THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(DISTINCT s.sessao_id), 0),
        4
    ) AS taxa_conclusao,
    ROUND(
        SUM(CASE WHEN e.evento = 'ABANDONOU_JORNADA' THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(DISTINCT s.sessao_id), 0),
        4
    ) AS taxa_abandono,
    ROUND(
        SUM(CASE WHEN e.evento = 'ERRO_APP' THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(DISTINCT s.sessao_id), 0),
        4
    ) AS taxa_erro
FROM silver.sessoes_digitais s
LEFT JOIN silver.eventos_digitais e
    ON s.sessao_id = e.sessao_id
GROUP BY
    s.safra_sessao,
    s.canal_digital,
    s.jornada,
    s.device;

-- ============================================================
-- 6. Cliente 360 V6
-- ============================================================

CREATE TABLE sdx.cliente_360_v6 AS
SELECT
    c360.*,
    COALESCE(cd.qtd_sessoes_digitais, 0) AS qtd_sessoes_digitais,
    COALESCE(cd.qtd_sessoes_concluidas, 0) AS qtd_sessoes_concluidas,
    COALESCE(cd.qtd_sessoes_abandonadas, 0) AS qtd_sessoes_abandonadas,
    COALESCE(cd.qtd_sessoes_com_erro, 0) AS qtd_sessoes_com_erro,
    COALESCE(cd.duracao_media_sessao, 0) AS duracao_media_sessao,
    cd.data_ultima_sessao,
    cd.dias_desde_ultima_sessao,
    COALESCE(cd.qtd_eventos_digitais, 0) AS qtd_eventos_digitais,
    COALESCE(cd.qtd_erros_app, 0) AS qtd_erros_app,
    COALESCE(cd.qtd_erros_alta_severidade, 0) AS qtd_erros_alta_severidade,
    COALESCE(cd.cluster_digital, 'SEM_DIGITAL') AS cluster_digital
FROM sdx.cliente_360_v5 c360
LEFT JOIN sdx.comportamento_digital_cliente cd
    ON c360.cliente_id = cd.num_pes;

-- ============================================================
-- 7. Gold — KPI canais digitais mensal
-- ============================================================

CREATE TABLE gold.kpi_canais_digitais_mensal AS
SELECT
    safra_sessao,
    canal_digital,
    jornada,
    device,
    COUNT(*) AS qtd_sessoes,
    COUNT(DISTINCT num_pes) AS qtd_clientes,
    SUM(flg_sessao_concluida) AS qtd_sessoes_concluidas,
    SUM(flg_sessao_abandonada) AS qtd_sessoes_abandonadas,
    SUM(flg_sessao_erro) AS qtd_sessoes_erro,
    ROUND(AVG(duracao_segundos)::NUMERIC, 2) AS duracao_media_segundos,
    ROUND(SUM(flg_sessao_concluida)::NUMERIC / NULLIF(COUNT(*), 0), 4) AS taxa_conclusao,
    ROUND(SUM(flg_sessao_abandonada)::NUMERIC / NULLIF(COUNT(*), 0), 4) AS taxa_abandono,
    ROUND(SUM(flg_sessao_erro)::NUMERIC / NULLIF(COUNT(*), 0), 4) AS taxa_erro
FROM silver.sessoes_digitais
GROUP BY
    safra_sessao,
    canal_digital,
    jornada,
    device;

-- ============================================================
-- 8. Gold — DW Canais Digitais
-- ============================================================

CREATE TABLE gold.dw_canais_digitais AS
SELECT
    e.evento_id,
    e.sessao_id,
    e.num_pes,
    cli.nome,
    cli.segmento,
    cli.rating_cliente,
    cli.score_credito,
    s.canal_digital,
    s.device,
    s.sistema_operacional,
    s.app_version,
    s.jornada,
    s.origem_trafego,
    s.data_inicio_sessao,
    s.data_fim_sessao,
    s.duracao_segundos,
    s.status_sessao,
    e.evento,
    e.data_evento,
    e.data_ref,
    e.safra_evento,
    e.ordem_evento,
    e.flg_conclusao,
    e.flg_abandono,
    e.flg_erro,

    CASE WHEN s.status_sessao = 'CONCLUIDA' THEN 1 ELSE 0 END AS flg_sessao_concluida,
    CASE WHEN s.status_sessao = 'ABANDONADA' THEN 1 ELSE 0 END AS flg_sessao_abandonada,
    CASE WHEN s.status_sessao = 'ERRO' THEN 1 ELSE 0 END AS flg_sessao_erro,
    CASE WHEN e.evento = 'LOGIN' THEN 1 ELSE 0 END AS flg_login,
    CASE WHEN e.evento = 'SIMULOU_PRODUTO' THEN 1 ELSE 0 END AS flg_simulacao,
    CASE WHEN e.evento = 'ENVIOU_DADOS' THEN 1 ELSE 0 END AS flg_envio_dados,

    er.tipo_erro,
    er.severidade,
    COALESCE(er.flg_erro_resolvido, 0) AS flg_erro_resolvido,

    CURRENT_TIMESTAMP AS dt_processamento_dw

FROM silver.eventos_digitais e
LEFT JOIN silver.sessoes_digitais s
    ON e.sessao_id = s.sessao_id
LEFT JOIN sdx.cliente_360_v5 cli
    ON e.num_pes = cli.cliente_id
LEFT JOIN silver.erros_app er
    ON e.evento_id = er.evento_id;

-- ============================================================
-- 9. Índices
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_dw_canais_num_pes
    ON gold.dw_canais_digitais (num_pes);

CREATE INDEX IF NOT EXISTS idx_dw_canais_safra
    ON gold.dw_canais_digitais (safra_evento);

CREATE INDEX IF NOT EXISTS idx_dw_canais_jornada
    ON gold.dw_canais_digitais (jornada);

CREATE INDEX IF NOT EXISTS idx_dw_canais_evento
    ON gold.dw_canais_digitais (evento);

ANALYZE silver.sessoes_digitais;
ANALYZE silver.eventos_digitais;
ANALYZE silver.erros_app;
ANALYZE sdx.comportamento_digital_cliente;
ANALYZE sdx.funil_digital;
ANALYZE sdx.cliente_360_v6;
ANALYZE gold.kpi_canais_digitais_mensal;
ANALYZE gold.dw_canais_digitais;

-- ============================================================
-- 10. Quality checks
-- ============================================================

CREATE TABLE meta.quality_canais_digitais AS
SELECT 'sessoes_digitais' AS check_name, COUNT(*) AS qtd
FROM silver.sessoes_digitais

UNION ALL

SELECT 'eventos_digitais', COUNT(*)
FROM silver.eventos_digitais

UNION ALL

SELECT 'erros_app', COUNT(*)
FROM silver.erros_app

UNION ALL

SELECT 'clientes_com_sessao_digital', COUNT(DISTINCT num_pes)
FROM silver.sessoes_digitais

UNION ALL

SELECT 'sessoes_concluidas', COUNT(*)
FROM silver.sessoes_digitais
WHERE flg_sessao_concluida = 1

UNION ALL

SELECT 'sessoes_abandonadas', COUNT(*)
FROM silver.sessoes_digitais
WHERE flg_sessao_abandonada = 1

UNION ALL

SELECT 'sessoes_com_erro', COUNT(*)
FROM silver.sessoes_digitais
WHERE flg_sessao_erro = 1

UNION ALL

SELECT 'eventos_sem_sessao', COUNT(*)
FROM silver.eventos_digitais e
LEFT JOIN silver.sessoes_digitais s
    ON e.sessao_id = s.sessao_id
WHERE s.sessao_id IS NULL

UNION ALL

SELECT 'dw_canais_digitais_linhas', COUNT(*)
FROM gold.dw_canais_digitais

UNION ALL

SELECT 'cliente_360_v6_linhas', COUNT(*)
FROM sdx.cliente_360_v6;

-- ============================================================
-- 11. Comentários
-- ============================================================

COMMENT ON TABLE gold.dw_canais_digitais IS
'Tabela flat de eventos digitais do Aurora Bank, simulando DW corporativa para análise de app, web, jornadas, abandono, erro e conversão digital.';

COMMENT ON COLUMN gold.dw_canais_digitais.num_pes IS
'Identificador da pessoa/cliente no padrão de DW bancária.';

COMMENT ON COLUMN gold.dw_canais_digitais.jornada IS
'Jornada digital executada pelo cliente, como crédito, portabilidade, cartão, PIX ou atendimento.';

COMMENT ON COLUMN gold.dw_canais_digitais.flg_sessao_abandonada IS
'Flag 1/0 que indica abandono da sessão digital.';
