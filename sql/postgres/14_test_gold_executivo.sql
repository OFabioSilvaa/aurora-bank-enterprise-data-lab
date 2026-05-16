-- ============================================================
-- Testes Gold Executivo
-- ============================================================

SELECT *
FROM meta.quality_gold_executivo
ORDER BY check_name;

SELECT *
FROM gold.kpi_executivo_banco;

SELECT *
FROM gold.visao_executiva_cliente
LIMIT 20;

SELECT *
FROM gold.dashboard_base_executiva
ORDER BY qtd_clientes DESC
LIMIT 50;

SELECT *
FROM gold.kpi_produtos_executivo
ORDER BY valor_operado DESC;

SELECT *
FROM gold.kpi_risco_executivo
ORDER BY qtd_clientes DESC;

-- Visão executiva de risco
SELECT
    classe_risco_relacionamento,
    faixa_risco_churn,
    COUNT(*) AS qtd_clientes,
    ROUND(AVG(score_credito)::NUMERIC, 2) AS score_credito_medio,
    ROUND(AVG(score_churn)::NUMERIC, 2) AS score_churn_medio,
    ROUND(SUM(saldo_devedor_credito)::NUMERIC, 2) AS saldo_devedor_credito,
    ROUND(SUM(saldo_npl_90)::NUMERIC, 2) AS saldo_npl_90
FROM gold.visao_executiva_cliente
GROUP BY
    classe_risco_relacionamento,
    faixa_risco_churn
ORDER BY
    classe_risco_relacionamento,
    score_churn_medio DESC;

-- Top clientes executivos críticos
SELECT
    num_pes,
    nome,
    segmento,
    rating_cliente,
    score_credito,
    renda_mensal,
    classe_risco_relacionamento,
    faixa_risco_churn,
    score_churn,
    saldo_devedor_credito,
    saldo_npl_90,
    valor_recuperado_cobranca,
    proxima_melhor_acao,
    acao_retencao_recomendada
FROM gold.visao_executiva_cliente
WHERE classe_risco_relacionamento = 'ALTO_RISCO'
   OR flg_churn_critico = 1
ORDER BY
    score_churn DESC,
    saldo_npl_90 DESC
LIMIT 100;
