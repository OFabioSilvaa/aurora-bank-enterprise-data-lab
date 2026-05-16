-- ============================================================
-- Testes do domínio Cobrança
-- ============================================================

SELECT *
FROM meta.quality_cobranca
ORDER BY check_name;

SELECT *
FROM gold.dw_cobranca
LIMIT 20;

-- Eficiência de cobrança por carteira e canal
SELECT
    carteira_cobranca,
    canal_acionamento,
    COUNT(*) AS qtd_acionamentos,
    COUNT(DISTINCT num_pes) AS qtd_clientes,
    SUM(flg_gerou_acordo) AS qtd_acordos,
    SUM(flg_recuperou_valor) AS qtd_recuperacoes,
    ROUND(SUM(valor_recuperado)::NUMERIC, 2) AS valor_recuperado,
    ROUND(SUM(valor_parcelas_em_atraso)::NUMERIC, 2) AS valor_em_atraso_acionado,
    ROUND(SUM(flg_gerou_acordo)::NUMERIC / NULLIF(COUNT(*), 0), 4) AS taxa_acordo,
    ROUND(SUM(flg_recuperou_valor)::NUMERIC / NULLIF(COUNT(*), 0), 4) AS taxa_recuperacao
FROM gold.dw_cobranca
GROUP BY
    carteira_cobranca,
    canal_acionamento
ORDER BY valor_recuperado DESC;

-- Acordos por status
SELECT
    status_acordo,
    COUNT(*) AS qtd_acordos,
    ROUND(SUM(valor_acordo)::NUMERIC, 2) AS valor_acordado
FROM silver.acordos_cobranca
GROUP BY status_acordo
ORDER BY qtd_acordos DESC;

-- Clientes com maior risco em cobrança
SELECT
    cliente_id,
    nome,
    segmento,
    rating_cliente,
    qtd_acionamentos_cobranca,
    qtd_contratos_acionados,
    qtd_sem_contato_cobranca,
    qtd_acordos_cobranca,
    qtd_acordos_quebrados,
    maior_atraso_cobranca,
    valor_total_em_atraso_acionado,
    valor_recuperado_cobranca,
    cluster_cobranca,
    flag_risco_cobranca
FROM sdx.cliente_360_v7
WHERE flag_risco_cobranca = TRUE
ORDER BY
    qtd_acordos_quebrados DESC,
    maior_atraso_cobranca DESC,
    valor_total_em_atraso_acionado DESC
LIMIT 100;

-- KPI mensal cobrança
SELECT *
FROM gold.kpi_cobranca_mensal
ORDER BY safra_acionamento, qtd_acionamentos DESC
LIMIT 100;
