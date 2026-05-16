-- ============================================================
-- Testes do domínio CRM e Campanhas
-- ============================================================

SELECT *
FROM meta.quality_crm
ORDER BY check_name;

SELECT *
FROM gold.kpi_crm_campanhas
ORDER BY roi_estimado DESC;

SELECT *
FROM gold.dw_crm
LIMIT 20;

-- Funil de campanha
SELECT
    nome_campanha,
    produto_alvo,
    canal_principal,
    publico_alvo,
    qtd_ofertas_enviadas,
    qtd_entregues,
    qtd_aberturas,
    qtd_cliques,
    qtd_conversoes,
    taxa_entrega,
    taxa_abertura,
    taxa_clique,
    taxa_conversao,
    receita_estimada,
    custo_campanha,
    roi_estimado
FROM gold.kpi_crm_campanhas
ORDER BY roi_estimado DESC;

-- Clientes com melhor resposta CRM
SELECT
    c360.cliente_id,
    c360.nome,
    c360.segmento,
    c360.rating_cliente,
    c360.qtd_ofertas_crm,
    c360.qtd_aberturas_crm,
    c360.qtd_cliques_crm,
    c360.qtd_conversoes_crm,
    c360.receita_estimada_crm,
    c360.cluster_crm,
    c360.proxima_melhor_acao
FROM sdx.cliente_360_v5 c360
WHERE c360.qtd_ofertas_crm > 0
ORDER BY
    c360.qtd_conversoes_crm DESC,
    c360.receita_estimada_crm DESC
LIMIT 100;

-- Próxima melhor ação
SELECT
    proxima_melhor_acao,
    COUNT(*) AS qtd_clientes,
    ROUND(AVG(score_credito)::NUMERIC, 2) AS score_medio,
    ROUND(AVG(renda_mensal)::NUMERIC, 2) AS renda_media
FROM sdx.segmentacao_crm
GROUP BY proxima_melhor_acao
ORDER BY qtd_clientes DESC;

-- Conversões por produto
SELECT
    produto_alvo,
    COUNT(*) AS qtd_conversoes,
    ROUND(SUM(receita_estimada)::NUMERIC, 2) AS receita_estimada
FROM silver.conversoes_crm
GROUP BY produto_alvo
ORDER BY receita_estimada DESC;
