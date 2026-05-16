-- ============================================================
-- Aurora Bank Enterprise Data Lab
-- Patch 13 — Teste Geral da V1
-- Banco destino: PostgreSQL
-- ============================================================
--
-- Objetivo:
-- Validar se a V1 do Aurora Bank está funcional após todos os patches.
--
-- Execute no PostgreSQL conectado ao banco aurora_bank.
-- ============================================================

-- ============================================================
-- 1. Inventário geral de schemas e tabelas
-- ============================================================

SELECT
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema IN ('silver', 'sdx', 'gold', 'meta')
ORDER BY
    table_schema,
    table_name;

-- ============================================================
-- 2. Contagem das principais tabelas
-- ============================================================

SELECT 'silver.clientes' AS tabela, COUNT(*) AS qtd_linhas FROM silver.clientes
UNION ALL SELECT 'silver.contas', COUNT(*) FROM silver.contas
UNION ALL SELECT 'silver.transacoes', COUNT(*) FROM silver.transacoes
UNION ALL SELECT 'silver.cartoes', COUNT(*) FROM silver.cartoes
UNION ALL SELECT 'silver.compras_cartao', COUNT(*) FROM silver.compras_cartao
UNION ALL SELECT 'silver.faturas_cartao', COUNT(*) FROM silver.faturas_cartao
UNION ALL SELECT 'silver.propostas_credito', COUNT(*) FROM silver.propostas_credito
UNION ALL SELECT 'silver.contratos_credito', COUNT(*) FROM silver.contratos_credito
UNION ALL SELECT 'silver.parcelas_credito', COUNT(*) FROM silver.parcelas_credito
UNION ALL SELECT 'silver.propostas_portabilidade', COUNT(*) FROM silver.propostas_portabilidade
UNION ALL SELECT 'silver.campanhas_crm', COUNT(*) FROM silver.campanhas_crm
UNION ALL SELECT 'silver.ofertas_crm', COUNT(*) FROM silver.ofertas_crm
UNION ALL SELECT 'silver.sessoes_digitais', COUNT(*) FROM silver.sessoes_digitais
UNION ALL SELECT 'silver.acionamentos_cobranca', COUNT(*) FROM silver.acionamentos_cobranca
UNION ALL SELECT 'sdx.cliente_360_v8', COUNT(*) FROM sdx.cliente_360_v8
UNION ALL SELECT 'gold.visao_executiva_cliente', COUNT(*) FROM gold.visao_executiva_cliente
UNION ALL SELECT 'gold.kpi_executivo_banco', COUNT(*) FROM gold.kpi_executivo_banco
UNION ALL SELECT 'gold.dashboard_base_executiva', COUNT(*) FROM gold.dashboard_base_executiva
ORDER BY tabela;

-- ============================================================
-- 3. Todas as tabelas de quality check
-- ============================================================

SELECT 'quality_clientes' AS tabela_quality, * FROM meta.quality_clientes
UNION ALL
SELECT 'quality_contas_transacoes' AS tabela_quality, * FROM meta.quality_contas_transacoes
UNION ALL
SELECT 'quality_cartoes' AS tabela_quality, * FROM meta.quality_cartoes
UNION ALL
SELECT 'quality_credito' AS tabela_quality, * FROM meta.quality_credito
UNION ALL
SELECT 'quality_dw_contratacao' AS tabela_quality, * FROM meta.quality_dw_contratacao
UNION ALL
SELECT 'quality_portabilidade' AS tabela_quality, * FROM meta.quality_portabilidade
UNION ALL
SELECT 'quality_crm' AS tabela_quality, * FROM meta.quality_crm
UNION ALL
SELECT 'quality_canais_digitais' AS tabela_quality, * FROM meta.quality_canais_digitais
UNION ALL
SELECT 'quality_cobranca' AS tabela_quality, * FROM meta.quality_cobranca
UNION ALL
SELECT 'quality_churn' AS tabela_quality, * FROM meta.quality_churn
UNION ALL
SELECT 'quality_gold_executivo' AS tabela_quality, * FROM meta.quality_gold_executivo
ORDER BY tabela_quality, check_name;

-- ============================================================
-- 4. KPI executivo principal
-- ============================================================

SELECT *
FROM gold.kpi_executivo_banco;

-- ============================================================
-- 5. Visão executiva por cliente
-- ============================================================

SELECT *
FROM gold.visao_executiva_cliente
LIMIT 50;

-- ============================================================
-- 6. Dashboard executivo agregado
-- ============================================================

SELECT *
FROM gold.dashboard_base_executiva
ORDER BY qtd_clientes DESC
LIMIT 50;

-- ============================================================
-- 7. Produtos executivos
-- ============================================================

SELECT *
FROM gold.kpi_produtos_executivo
ORDER BY valor_operado DESC;

-- ============================================================
-- 8. Risco executivo
-- ============================================================

SELECT *
FROM gold.kpi_risco_executivo
ORDER BY qtd_clientes DESC
LIMIT 100;

-- ============================================================
-- 9. Cliente 360 V8 — amostra final
-- ============================================================

SELECT
    cliente_id,
    nome,
    segmento,
    rating_cliente,
    score_credito,
    renda_mensal,
    qtd_contas_ativas,
    qtd_cartoes_ativos,
    qtd_contratos_credito,
    qtd_portabilidades_pagas,
    qtd_conversoes_crm,
    qtd_sessoes_digitais,
    qtd_acionamentos_cobranca,
    score_churn,
    faixa_risco_churn,
    acao_retencao_recomendada
FROM sdx.cliente_360_v8
LIMIT 100;

-- ============================================================
-- 10. Teste de integridade executiva
-- ============================================================

SELECT
    'clientes_sem_visao_executiva' AS check_name,
    COUNT(*) AS qtd
FROM sdx.cliente_360_v8 c
LEFT JOIN gold.visao_executiva_cliente v
    ON c.cliente_id = v.num_pes
WHERE v.num_pes IS NULL

UNION ALL

SELECT
    'visao_executiva_sem_cliente_360' AS check_name,
    COUNT(*) AS qtd
FROM gold.visao_executiva_cliente v
LEFT JOIN sdx.cliente_360_v8 c
    ON v.num_pes = c.cliente_id
WHERE c.cliente_id IS NULL

UNION ALL

SELECT
    'kpi_executivo_deve_ter_1_linha' AS check_name,
    COUNT(*) AS qtd
FROM gold.kpi_executivo_banco;
