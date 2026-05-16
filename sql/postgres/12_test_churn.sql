-- ============================================================
-- Testes do domínio Churn
-- ============================================================

SELECT *
FROM meta.quality_churn
ORDER BY check_name;

SELECT *
FROM gold.dw_churn
LIMIT 20;

-- Distribuição do risco de churn
SELECT
    faixa_risco_churn,
    COUNT(*) AS qtd_clientes,
    ROUND(AVG(score_churn)::NUMERIC, 2) AS score_medio,
    ROUND(AVG(score_credito)::NUMERIC, 2) AS score_credito_medio,
    ROUND(AVG(renda_mensal)::NUMERIC, 2) AS renda_media
FROM gold.dw_churn
GROUP BY faixa_risco_churn
ORDER BY score_medio DESC;

-- Churn por segmento
SELECT
    segmento,
    faixa_risco_churn,
    COUNT(*) AS qtd_clientes,
    SUM(flg_risco_churn) AS qtd_risco_churn,
    SUM(flg_churn_critico) AS qtd_churn_critico,
    ROUND(AVG(score_churn)::NUMERIC, 2) AS score_churn_medio
FROM gold.dw_churn
GROUP BY
    segmento,
    faixa_risco_churn
ORDER BY
    segmento,
    score_churn_medio DESC;

-- Top clientes críticos
SELECT
    num_pes,
    nome,
    segmento,
    rating_cliente,
    score_credito,
    score_churn,
    faixa_risco_churn,
    acao_retencao_recomendada,
    dias_desde_ultima_transacao,
    dias_desde_ultimo_login,
    qtd_acordos_quebrados,
    cluster_cobranca,
    cluster_digital,
    cluster_crm
FROM gold.dw_churn
WHERE flg_risco_churn = 1
ORDER BY score_churn DESC
LIMIT 100;

-- Ações recomendadas
SELECT
    acao_retencao_recomendada,
    COUNT(*) AS qtd_clientes,
    ROUND(AVG(score_churn)::NUMERIC, 2) AS score_churn_medio,
    ROUND(SUM(COALESCE(saldo_devedor_credito, 0))::NUMERIC, 2) AS saldo_devedor_credito
FROM gold.dw_churn
GROUP BY acao_retencao_recomendada
ORDER BY qtd_clientes DESC;

-- KPI Churn
SELECT *
FROM gold.kpi_churn_mensal
ORDER BY qtd_risco_churn DESC;
