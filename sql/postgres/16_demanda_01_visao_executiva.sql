-- ============================================================
-- Aurora Bank Enterprise Data Lab
-- Demanda 01 — Visão Executiva de Risco, Relacionamento e Produto
-- ============================================================
--
-- Contexto:
-- A gestora fictícia Mariana Torres pediu uma visão executiva para
-- entender a saúde da base de clientes, risco, crédito, cartão,
-- portabilidade, CRM, digital, cobrança e churn.
--
-- Objetivo:
-- Gerar uma base analítica com os clientes mais relevantes para
-- priorização de ação gerencial.
-- ============================================================

-- ============================================================
-- 1. Resumo executivo do banco
-- ============================================================

SELECT *
FROM gold.kpi_executivo_banco;

-- ============================================================
-- 2. Segmentos com maior risco
-- ============================================================

SELECT
    segmento,
    classe_risco_relacionamento,
    faixa_risco_churn,
    COUNT(*) AS qtd_clientes,
    ROUND(AVG(score_credito)::NUMERIC, 2) AS score_credito_medio,
    ROUND(AVG(score_churn)::NUMERIC, 2) AS score_churn_medio,
    ROUND(SUM(saldo_devedor_credito)::NUMERIC, 2) AS saldo_devedor_credito,
    ROUND(SUM(saldo_npl_90)::NUMERIC, 2) AS saldo_npl_90,
    ROUND(SUM(valor_total_em_atraso_acionado)::NUMERIC, 2) AS valor_em_atraso_cobranca
FROM gold.visao_executiva_cliente
GROUP BY
    segmento,
    classe_risco_relacionamento,
    faixa_risco_churn
ORDER BY
    saldo_npl_90 DESC,
    score_churn_medio DESC;

-- ============================================================
-- 3. Clientes prioritários para ação
-- ============================================================

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
    perfil_relacionamento,
    qtd_cartoes_ativos,
    qtd_contratos_credito,
    saldo_devedor_credito,
    saldo_npl_90,
    qtd_portabilidades_pagas,
    qtd_conversoes_crm,
    qtd_sessoes_abandonadas,
    qtd_sessoes_com_erro,
    qtd_acionamentos_cobranca,
    qtd_acordos_quebrados,
    valor_recuperado_cobranca,
    proxima_melhor_acao,
    acao_retencao_recomendada
FROM gold.visao_executiva_cliente
WHERE classe_risco_relacionamento = 'ALTO_RISCO'
   OR flg_churn_critico = 1
   OR saldo_npl_90 > 0
ORDER BY
    score_churn DESC,
    saldo_npl_90 DESC,
    saldo_devedor_credito DESC
LIMIT 500;

-- ============================================================
-- 4. Produtos com maior exposição
-- ============================================================

SELECT *
FROM gold.kpi_produtos_executivo
ORDER BY valor_operado DESC;

-- ============================================================
-- 5. Ações recomendadas de retenção
-- ============================================================

SELECT
    acao_retencao_recomendada,
    COUNT(*) AS qtd_clientes,
    ROUND(AVG(score_churn)::NUMERIC, 2) AS score_churn_medio,
    ROUND(SUM(saldo_devedor_credito)::NUMERIC, 2) AS saldo_devedor_credito,
    ROUND(SUM(saldo_npl_90)::NUMERIC, 2) AS saldo_npl_90,
    ROUND(SUM(receita_estimada_crm)::NUMERIC, 2) AS receita_estimada_crm
FROM gold.visao_executiva_cliente
GROUP BY acao_retencao_recomendada
ORDER BY qtd_clientes DESC;

-- ============================================================
-- 6. Base recomendada para exportação
-- ============================================================

SELECT
    num_pes,
    nome,
    segmento,
    rating_cliente,
    score_credito,
    renda_mensal,
    uf,
    regiao,
    classe_risco_relacionamento,
    faixa_risco_churn,
    score_churn,
    perfil_relacionamento,
    proxima_melhor_acao,
    acao_retencao_recomendada,
    qtd_contas_ativas,
    qtd_cartoes_ativos,
    qtd_contratos_credito,
    saldo_devedor_credito,
    saldo_npl_90,
    qtd_solicitacoes_portabilidade,
    qtd_portabilidades_pagas,
    qtd_conversoes_crm,
    qtd_sessoes_digitais,
    qtd_sessoes_abandonadas,
    qtd_sessoes_com_erro,
    qtd_acionamentos_cobranca,
    qtd_acordos_quebrados,
    valor_recuperado_cobranca
FROM gold.visao_executiva_cliente
ORDER BY
    classe_risco_relacionamento,
    score_churn DESC,
    saldo_npl_90 DESC
LIMIT 10000;
