-- ============================================================
-- Aurora Bank Enterprise Data Lab
-- Patch 11 — Churn
-- Banco destino: PostgreSQL
-- ============================================================
--
-- Objetivo:
-- Criar camada analítica de churn/risco de evasão no Aurora Bank V1.
--
-- Tabelas criadas:
-- - sdx.churn_features
-- - sdx.cliente_360_v8
-- - gold.dw_churn
-- - gold.kpi_churn_mensal
-- - meta.quality_churn
--
-- Execute no PostgreSQL conectado ao banco aurora_bank.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS sdx;
CREATE SCHEMA IF NOT EXISTS gold;
CREATE SCHEMA IF NOT EXISTS meta;

-- ============================================================
-- Limpeza controlada
-- ============================================================

DROP TABLE IF EXISTS gold.dw_churn;
DROP TABLE IF EXISTS gold.kpi_churn_mensal;
DROP TABLE IF EXISTS sdx.cliente_360_v8;
DROP TABLE IF EXISTS sdx.churn_features;
DROP TABLE IF EXISTS meta.quality_churn;

-- ============================================================
-- 1. SDX — Features de Churn
-- ============================================================
--
-- A regra combina:
-- - inatividade transacional
-- - inatividade digital
-- - risco/baixo engajamento CRM
-- - cancelamento/baixo uso de cartão
-- - risco de crédito/cobrança
-- - fricção digital
-- - status do cliente
-- ============================================================

CREATE TABLE sdx.churn_features AS
WITH base AS (
    SELECT
        c.cliente_id AS num_pes,
        c.nome,
        c.segmento,
        c.rating_cliente,
        c.score_credito,
        c.renda_mensal,
        c.faixa_etaria,
        c.uf,
        c.regiao,

        c.flag_cliente_ativo,
        c.status_cliente_core,
        c.status_app,

        COALESCE(c.qtd_contas, 0) AS qtd_contas,
        COALESCE(c.qtd_contas_ativas, 0) AS qtd_contas_ativas,
        COALESCE(c.saldo_total_contas, 0) AS saldo_total_contas,

        COALESCE(c.qtd_transacoes_validas, 0) AS qtd_transacoes_validas,
        COALESCE(c.valor_transacionado, 0) AS valor_transacionado,
        c.data_ultima_transacao,
        c.dias_desde_ultima_transacao,
        COALESCE(c.cluster_atividade_financeira, 'NAO_INFORMADO') AS cluster_atividade_financeira,

        c.data_ultimo_login,
        c.dias_desde_ultimo_login,
        COALESCE(c.cluster_engajamento_digital, 'NAO_INFORMADO') AS cluster_engajamento_digital,

        COALESCE(cc.qtd_cartoes_ativos, c.qtd_cartoes_ativos, 0) AS qtd_cartoes_ativos,
        COALESCE(cc.qtd_cartoes_cancelados, 0) AS qtd_cartoes_cancelados,
        COALESCE(cc.qtd_compras_validas, 0) AS qtd_compras_validas,
        COALESCE(cc.data_ultima_compra, c.data_ultima_compra) AS data_ultima_compra,
        COALESCE(cc.dias_desde_ultima_compra, c.dias_desde_ultima_compra) AS dias_desde_ultima_compra,
        COALESCE(cc.cluster_cartao, c.cluster_cartao, 'SEM_CARTAO') AS cluster_cartao,
        CASE
            WHEN COALESCE(cc.maior_atraso_fatura, 0) >= 90 THEN TRUE
            WHEN COALESCE(cc.qtd_uso_rotativo, 0) >= 3 THEN TRUE
            WHEN COALESCE(cc.qtd_pagamento_minimo, 0) >= 3 THEN TRUE
            ELSE FALSE
        END AS flag_risco_cartao,

        COALESCE(c.qtd_contratos_credito, 0) AS qtd_contratos_credito,
        COALESCE(c.saldo_devedor_credito, 0) AS saldo_devedor_credito,
        COALESCE(c.maior_atraso_credito, 0) AS maior_atraso_credito,
        COALESCE(c.saldo_npl_90, 0) AS saldo_npl_90,
        COALESCE(c.cluster_risco_credito, 'SEM_CREDITO') AS cluster_risco_credito,
        COALESCE(c.flag_risco_credito, FALSE) AS flag_risco_credito,

        COALESCE(c.qtd_solicitacoes_portabilidade, 0) AS qtd_solicitacoes_portabilidade,
        COALESCE(c.qtd_portabilidades_pagas, 0) AS qtd_portabilidades_pagas,
        COALESCE(c.cluster_portabilidade, 'SEM_PORTABILIDADE') AS cluster_portabilidade,

        COALESCE(c.qtd_ofertas_crm, 0) AS qtd_ofertas_crm,
        COALESCE(c.qtd_conversoes_crm, 0) AS qtd_conversoes_crm,
        COALESCE(c.cluster_crm, 'SEM_CRM') AS cluster_crm,
        COALESCE(c.proxima_melhor_acao, 'NUTRICAO') AS proxima_melhor_acao,

        COALESCE(c.qtd_sessoes_digitais, 0) AS qtd_sessoes_digitais,
        COALESCE(c.qtd_sessoes_abandonadas, 0) AS qtd_sessoes_abandonadas,
        COALESCE(c.qtd_sessoes_com_erro, 0) AS qtd_sessoes_com_erro,
        c.data_ultima_sessao,
        c.dias_desde_ultima_sessao,
        COALESCE(c.cluster_digital, 'SEM_DIGITAL') AS cluster_digital,

        COALESCE(c.qtd_acionamentos_cobranca, 0) AS qtd_acionamentos_cobranca,
        COALESCE(c.qtd_sem_contato_cobranca, 0) AS qtd_sem_contato_cobranca,
        COALESCE(c.qtd_acordos_quebrados, 0) AS qtd_acordos_quebrados,
        COALESCE(c.valor_total_em_atraso_acionado, 0) AS valor_total_em_atraso_acionado,
        COALESCE(c.valor_recuperado_cobranca, 0) AS valor_recuperado_cobranca,
        COALESCE(c.cluster_cobranca, 'SEM_COBRANCA') AS cluster_cobranca,
        COALESCE(c.flag_risco_cobranca, FALSE) AS flag_risco_cobranca,

        COALESCE(c.flag_risco_churn_inicial, FALSE) AS flag_risco_churn_inicial

    FROM sdx.cliente_360_v7 c
    LEFT JOIN sdx.comportamento_cartao cc
        ON c.cliente_id = cc.cliente_id
),

features AS (
    SELECT
        b.*,

        CASE
            WHEN b.dias_desde_ultima_transacao IS NULL THEN 15
            WHEN b.dias_desde_ultima_transacao > 180 THEN 25
            WHEN b.dias_desde_ultima_transacao > 120 THEN 18
            WHEN b.dias_desde_ultima_transacao > 90 THEN 12
            WHEN b.dias_desde_ultima_transacao > 60 THEN 6
            ELSE 0
        END AS pontos_inatividade_transacional,

        CASE
            WHEN b.dias_desde_ultimo_login IS NULL THEN 10
            WHEN b.dias_desde_ultimo_login > 180 THEN 18
            WHEN b.dias_desde_ultimo_login > 90 THEN 12
            WHEN b.dias_desde_ultimo_login > 45 THEN 6
            ELSE 0
        END AS pontos_inatividade_digital,

        CASE
            WHEN b.qtd_cartoes_cancelados > 0 THEN 10
            WHEN b.cluster_cartao = 'SEM_CARTAO_ATIVO' AND b.qtd_cartoes_ativos = 0 THEN 6
            WHEN b.flag_risco_cartao = TRUE THEN 7
            ELSE 0
        END AS pontos_cartao,

        CASE
            WHEN b.flag_risco_credito = TRUE THEN 12
            WHEN b.maior_atraso_credito >= 60 THEN 9
            WHEN b.maior_atraso_credito > 0 THEN 5
            ELSE 0
        END AS pontos_credito,

        CASE
            WHEN b.flag_risco_cobranca = TRUE THEN 15
            WHEN b.cluster_cobranca IN ('ACORDO_QUEBRADO', 'DIFICIL_CONTATO') THEN 12
            WHEN b.qtd_acionamentos_cobranca > 0 THEN 6
            ELSE 0
        END AS pontos_cobranca,

        CASE
            WHEN b.cluster_digital IN ('FRICCAO_DIGITAL', 'ABANDONO_RECORRENTE') THEN 8
            WHEN b.qtd_sessoes_abandonadas >= 2 THEN 5
            ELSE 0
        END AS pontos_friccao_digital,

        CASE
            WHEN b.cluster_crm = 'IMPACTADO_SEM_ENGAJAMENTO' THEN 6
            WHEN b.cluster_crm = 'SEM_CRM' THEN 3
            WHEN b.cluster_crm IN ('CONVERTIDO', 'RESPONSIVO') THEN -8
            WHEN b.cluster_crm = 'INTERESSADO' THEN -4
            ELSE 0
        END AS pontos_crm,

        CASE
            WHEN b.status_cliente_core IN ('INATIVO', 'ENCERRADO', 'BLOQUEADO') THEN 20
            WHEN b.flag_cliente_ativo = FALSE THEN 16
            ELSE 0
        END AS pontos_status_cliente,

        CASE
            WHEN b.qtd_portabilidades_pagas > 0 THEN -6
            WHEN b.qtd_contratos_credito > 0 THEN -4
            WHEN b.qtd_cartoes_ativos > 0 THEN -3
            WHEN b.qtd_contas_ativas > 0 THEN -2
            ELSE 0
        END AS pontos_relacionamento

    FROM base b
),

score_calc AS (
    SELECT
        f.*,
        GREATEST(
            0,
            LEAST(
                100,
                20
                + pontos_inatividade_transacional
                + pontos_inatividade_digital
                + pontos_cartao
                + pontos_credito
                + pontos_cobranca
                + pontos_friccao_digital
                + pontos_crm
                + pontos_status_cliente
                + pontos_relacionamento
            )
        ) AS score_churn
    FROM features f
)

SELECT
    num_pes,
    nome,
    segmento,
    rating_cliente,
    score_credito,
    renda_mensal,
    faixa_etaria,
    uf,
    regiao,

    flag_cliente_ativo,
    status_cliente_core,
    status_app,

    qtd_contas,
    qtd_contas_ativas,
    saldo_total_contas,
    qtd_transacoes_validas,
    valor_transacionado,
    data_ultima_transacao,
    dias_desde_ultima_transacao,
    cluster_atividade_financeira,

    data_ultimo_login,
    dias_desde_ultimo_login,
    cluster_engajamento_digital,

    qtd_cartoes_ativos,
    qtd_cartoes_cancelados,
    data_ultima_compra,
    dias_desde_ultima_compra,
    cluster_cartao,

    qtd_contratos_credito,
    saldo_devedor_credito,
    maior_atraso_credito,
    saldo_npl_90,
    cluster_risco_credito,

    qtd_solicitacoes_portabilidade,
    qtd_portabilidades_pagas,
    cluster_portabilidade,

    qtd_ofertas_crm,
    qtd_conversoes_crm,
    cluster_crm,
    proxima_melhor_acao,

    qtd_sessoes_digitais,
    qtd_sessoes_abandonadas,
    qtd_sessoes_com_erro,
    dias_desde_ultima_sessao,
    cluster_digital,

    qtd_acionamentos_cobranca,
    qtd_sem_contato_cobranca,
    qtd_acordos_quebrados,
    valor_total_em_atraso_acionado,
    valor_recuperado_cobranca,
    cluster_cobranca,

    pontos_inatividade_transacional,
    pontos_inatividade_digital,
    pontos_cartao,
    pontos_credito,
    pontos_cobranca,
    pontos_friccao_digital,
    pontos_crm,
    pontos_status_cliente,
    pontos_relacionamento,

    score_churn,

    CASE
        WHEN score_churn >= 75 THEN 'CHURN_CRITICO'
        WHEN score_churn >= 55 THEN 'CHURN_ALTO'
        WHEN score_churn >= 35 THEN 'CHURN_MEDIO'
        ELSE 'CHURN_BAIXO'
    END AS faixa_risco_churn,

    CASE WHEN score_churn >= 55 THEN 1 ELSE 0 END AS flg_risco_churn,
    CASE WHEN score_churn >= 75 THEN 1 ELSE 0 END AS flg_churn_critico,

    CASE
        WHEN score_churn >= 75 THEN 'ACIONAR_RETENCAO_URGENTE'
        WHEN score_churn >= 55 AND cluster_cobranca <> 'SEM_COBRANCA' THEN 'RETENCAO_COM_COBRANCA'
        WHEN score_churn >= 55 AND cluster_digital IN ('FRICCAO_DIGITAL', 'ABANDONO_RECORRENTE') THEN 'MELHORAR_EXPERIENCIA_DIGITAL'
        WHEN score_churn >= 55 AND qtd_cartoes_cancelados > 0 THEN 'OFERTA_REATIVACAO_CARTAO'
        WHEN score_churn >= 35 THEN 'NUTRICAO_PREVENTIVA'
        ELSE 'MANTER_RELACIONAMENTO'
    END AS acao_retencao_recomendada,

    CURRENT_TIMESTAMP AS dt_processamento
FROM score_calc;

-- ============================================================
-- 2. Cliente 360 V8
-- ============================================================

CREATE TABLE sdx.cliente_360_v8 AS
SELECT
    c360.*,
    cf.score_churn,
    cf.faixa_risco_churn,
    cf.flg_risco_churn,
    cf.flg_churn_critico,
    cf.acao_retencao_recomendada,
    cf.pontos_inatividade_transacional,
    cf.pontos_inatividade_digital,
    cf.pontos_cartao,
    cf.pontos_credito,
    cf.pontos_cobranca,
    cf.pontos_friccao_digital,
    cf.pontos_crm,
    cf.pontos_status_cliente,
    cf.pontos_relacionamento
FROM sdx.cliente_360_v7 c360
LEFT JOIN sdx.churn_features cf
    ON c360.cliente_id = cf.num_pes;

-- ============================================================
-- 3. Gold — DW Churn
-- ============================================================

CREATE TABLE gold.dw_churn AS
SELECT
    cf.num_pes,
    cf.nome,
    cf.segmento,
    cf.rating_cliente,
    cf.score_credito,
    cf.renda_mensal,
    cf.faixa_etaria,
    cf.uf,
    cf.regiao,

    cf.flag_cliente_ativo,
    cf.status_cliente_core,
    cf.status_app,

    cf.qtd_contas_ativas,
    cf.qtd_transacoes_validas,
    cf.valor_transacionado,
    cf.dias_desde_ultima_transacao,
    cf.dias_desde_ultimo_login,
    cf.dias_desde_ultima_compra,
    cf.dias_desde_ultima_sessao,

    cf.qtd_cartoes_ativos,
    cf.qtd_cartoes_cancelados,
    cf.qtd_contratos_credito,
    cf.saldo_devedor_credito,
    cf.maior_atraso_credito,
    cf.saldo_npl_90,

    cf.qtd_solicitacoes_portabilidade,
    cf.qtd_portabilidades_pagas,

    cf.qtd_ofertas_crm,
    cf.qtd_conversoes_crm,
    cf.cluster_crm,
    cf.proxima_melhor_acao,

    cf.qtd_sessoes_digitais,
    cf.qtd_sessoes_abandonadas,
    cf.qtd_sessoes_com_erro,
    cf.cluster_digital,

    cf.qtd_acionamentos_cobranca,
    cf.qtd_sem_contato_cobranca,
    cf.qtd_acordos_quebrados,
    cf.valor_total_em_atraso_acionado,
    cf.valor_recuperado_cobranca,
    cf.cluster_cobranca,

    cf.cluster_atividade_financeira,
    cf.cluster_engajamento_digital,
    cf.cluster_cartao,
    cf.cluster_risco_credito,
    cf.cluster_portabilidade,

    cf.pontos_inatividade_transacional,
    cf.pontos_inatividade_digital,
    cf.pontos_cartao,
    cf.pontos_credito,
    cf.pontos_cobranca,
    cf.pontos_friccao_digital,
    cf.pontos_crm,
    cf.pontos_status_cliente,
    cf.pontos_relacionamento,

    cf.score_churn,
    cf.faixa_risco_churn,
    cf.flg_risco_churn,
    cf.flg_churn_critico,
    cf.acao_retencao_recomendada,

    TO_CHAR(CURRENT_DATE, 'YYYY-MM') AS safra_processamento,
    CURRENT_TIMESTAMP AS dt_processamento_dw
FROM sdx.churn_features cf;

-- ============================================================
-- 4. Gold — KPI Churn Mensal
-- ============================================================
--
-- Como a V1 é uma base snapshot, a safra de churn é a safra de processamento.
-- ============================================================

CREATE TABLE gold.kpi_churn_mensal AS
SELECT
    safra_processamento,
    segmento,
    faixa_risco_churn,
    acao_retencao_recomendada,
    COUNT(*) AS qtd_clientes,
    SUM(flg_risco_churn) AS qtd_risco_churn,
    SUM(flg_churn_critico) AS qtd_churn_critico,
    ROUND(AVG(score_churn)::NUMERIC, 2) AS score_churn_medio,
    ROUND(AVG(score_credito)::NUMERIC, 2) AS score_credito_medio,
    ROUND(AVG(renda_mensal)::NUMERIC, 2) AS renda_media,
    ROUND(SUM(COALESCE(saldo_devedor_credito, 0))::NUMERIC, 2) AS saldo_devedor_credito,
    ROUND(SUM(COALESCE(valor_transacionado, 0))::NUMERIC, 2) AS valor_transacionado,
    ROUND(SUM(COALESCE(valor_total_em_atraso_acionado, 0))::NUMERIC, 2) AS valor_em_atraso_acionado
FROM gold.dw_churn
GROUP BY
    safra_processamento,
    segmento,
    faixa_risco_churn,
    acao_retencao_recomendada;

-- ============================================================
-- 5. Índices
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_dw_churn_num_pes
    ON gold.dw_churn (num_pes);

CREATE INDEX IF NOT EXISTS idx_dw_churn_faixa
    ON gold.dw_churn (faixa_risco_churn);

CREATE INDEX IF NOT EXISTS idx_dw_churn_score
    ON gold.dw_churn (score_churn);

CREATE INDEX IF NOT EXISTS idx_dw_churn_segmento
    ON gold.dw_churn (segmento);

CREATE INDEX IF NOT EXISTS idx_dw_churn_flags
    ON gold.dw_churn (flg_risco_churn, flg_churn_critico);

ANALYZE sdx.churn_features;
ANALYZE sdx.cliente_360_v8;
ANALYZE gold.dw_churn;
ANALYZE gold.kpi_churn_mensal;

-- ============================================================
-- 6. Quality checks
-- ============================================================

CREATE TABLE meta.quality_churn AS
SELECT 'churn_features_linhas' AS check_name, COUNT(*) AS qtd
FROM sdx.churn_features

UNION ALL

SELECT 'dw_churn_linhas', COUNT(*)
FROM gold.dw_churn

UNION ALL

SELECT 'cliente_360_v8_linhas', COUNT(*)
FROM sdx.cliente_360_v8

UNION ALL

SELECT 'clientes_risco_churn', COUNT(*)
FROM gold.dw_churn
WHERE flg_risco_churn = 1

UNION ALL

SELECT 'clientes_churn_critico', COUNT(*)
FROM gold.dw_churn
WHERE flg_churn_critico = 1

UNION ALL

SELECT 'clientes_sem_transacao_180d', COUNT(*)
FROM gold.dw_churn
WHERE dias_desde_ultima_transacao > 180

UNION ALL

SELECT 'clientes_sem_login_180d', COUNT(*)
FROM gold.dw_churn
WHERE dias_desde_ultimo_login > 180

UNION ALL

SELECT 'clientes_com_acordo_quebrado', COUNT(*)
FROM gold.dw_churn
WHERE qtd_acordos_quebrados > 0

UNION ALL

SELECT 'clientes_com_friccao_digital', COUNT(*)
FROM gold.dw_churn
WHERE cluster_digital IN ('FRICCAO_DIGITAL', 'ABANDONO_RECORRENTE');

-- ============================================================
-- 7. Comentários
-- ============================================================

COMMENT ON TABLE gold.dw_churn IS
'Tabela flat de churn do Aurora Bank, simulando score de risco de evasão com base em comportamento transacional, digital, CRM, crédito, cartão e cobrança.';

COMMENT ON COLUMN gold.dw_churn.score_churn IS
'Score sintético de risco de churn entre 0 e 100.';

COMMENT ON COLUMN gold.dw_churn.flg_risco_churn IS
'Flag 1/0 que indica cliente com risco relevante de churn.';

COMMENT ON COLUMN gold.dw_churn.acao_retencao_recomendada IS
'Ação sugerida para retenção ou relacionamento do cliente.';
