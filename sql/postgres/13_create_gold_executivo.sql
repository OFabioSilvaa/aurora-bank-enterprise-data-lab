-- ============================================================
-- Aurora Bank Enterprise Data Lab
-- Patch 12 — Gold Executivo
-- Banco destino: PostgreSQL
-- ============================================================
--
-- Objetivo:
-- Criar a camada executiva consolidada da V1.
--
-- Tabelas criadas:
-- - gold.kpi_executivo_banco
-- - gold.visao_executiva_cliente
-- - gold.dashboard_base_executiva
-- - gold.kpi_produtos_executivo
-- - gold.kpi_risco_executivo
-- - meta.quality_gold_executivo
--
-- Execute no PostgreSQL conectado ao banco aurora_bank.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS gold;
CREATE SCHEMA IF NOT EXISTS meta;

-- ============================================================
-- Limpeza controlada
-- ============================================================

DROP TABLE IF EXISTS gold.kpi_executivo_banco;
DROP TABLE IF EXISTS gold.visao_executiva_cliente;
DROP TABLE IF EXISTS gold.dashboard_base_executiva;
DROP TABLE IF EXISTS gold.kpi_produtos_executivo;
DROP TABLE IF EXISTS gold.kpi_risco_executivo;
DROP TABLE IF EXISTS meta.quality_gold_executivo;

-- ============================================================
-- 1. KPI Executivo Banco
-- ============================================================
--
-- Uma linha com a visão consolidada do banco.
-- ============================================================

CREATE TABLE gold.kpi_executivo_banco AS
WITH clientes AS (
    SELECT
        COUNT(*) AS total_clientes,
        SUM(CASE WHEN flag_cliente_ativo = TRUE THEN 1 ELSE 0 END) AS clientes_ativos,
        SUM(CASE WHEN flag_cliente_ativo = FALSE THEN 1 ELSE 0 END) AS clientes_inativos,
        ROUND(AVG(score_credito)::NUMERIC, 2) AS score_medio,
        ROUND(AVG(renda_mensal)::NUMERIC, 2) AS renda_media
    FROM sdx.cliente_360_v8
),

contas AS (
    SELECT
        COUNT(*) AS total_contas,
        SUM(CASE WHEN status_conta = 'ATIVA' THEN 1 ELSE 0 END) AS contas_ativas,
        ROUND(SUM(COALESCE(saldo_atual_tratado, 0))::NUMERIC, 2) AS saldo_total_contas
    FROM silver.contas
),

transacoes AS (
    SELECT
        COUNT(*) AS total_transacoes,
        SUM(CASE WHEN flag_transacao_valida_financeira = TRUE THEN 1 ELSE 0 END) AS transacoes_validas,
        ROUND(SUM(CASE WHEN flag_transacao_valida_financeira = TRUE THEN COALESCE(valor_tratado, 0) ELSE 0 END)::NUMERIC, 2) AS valor_transacionado
    FROM silver.transacoes
),

cartoes AS (
    SELECT
        COUNT(*) AS total_cartoes,
        SUM(CASE WHEN status_cartao = 'ATIVO' THEN 1 ELSE 0 END) AS cartoes_ativos,
        ROUND(SUM(COALESCE(limite_concedido_tratado, 0))::NUMERIC, 2) AS limite_total_cartao
    FROM silver.cartoes
),

faturas AS (
    SELECT
        COUNT(*) AS total_faturas,
        ROUND(SUM(COALESCE(valor_fatura_tratado, 0))::NUMERIC, 2) AS valor_faturado_cartao,
        ROUND(SUM(COALESCE(valor_pago, 0))::NUMERIC, 2) AS valor_pago_cartao,
        SUM(CASE WHEN COALESCE(dias_atraso_fatura, 0) > 0 THEN 1 ELSE 0 END) AS faturas_atrasadas
    FROM silver.faturas_cartao
),

credito AS (
    SELECT
        COUNT(*) AS total_contratos_credito,
        ROUND(SUM(COALESCE(valor_contratado, 0))::NUMERIC, 2) AS valor_contratado_credito,
        ROUND(SUM(COALESCE(saldo_devedor_tratado, 0))::NUMERIC, 2) AS saldo_devedor_credito,
        ROUND(AVG(taxa_mensal)::NUMERIC, 4) AS taxa_media_credito,
        ROUND(SUM(CASE WHEN bucket_atraso = 'NPL_90_PLUS' THEN COALESCE(saldo_devedor_tratado, 0) ELSE 0 END)::NUMERIC, 2) AS saldo_npl_90
    FROM silver.contratos_credito
),

portabilidade AS (
    SELECT
        COUNT(*) AS total_solicitacoes_portabilidade,
        SUM(flg_portabilidade_paga) AS portabilidades_pagas,
        ROUND(SUM(COALESCE(valor_saldo_devedor, 0))::NUMERIC, 2) AS saldo_solicitado_portabilidade,
        ROUND(SUM(CASE WHEN flg_portabilidade_paga = 1 THEN COALESCE(valor_saldo_devedor, 0) ELSE 0 END)::NUMERIC, 2) AS saldo_pago_portabilidade,
        ROUND(SUM(COALESCE(valor_troco_liberado, 0))::NUMERIC, 2) AS troco_liberado_portabilidade
    FROM gold.dw_portabilidade
),

crm AS (
    SELECT
        COUNT(*) AS total_ofertas_crm,
        SUM(flg_oferta_enviada) AS ofertas_enviadas,
        SUM(flg_convertido) AS conversoes_crm,
        ROUND(SUM(COALESCE(receita_estimada, 0))::NUMERIC, 2) AS receita_estimada_crm
    FROM gold.dw_crm
),

digital AS (
    SELECT
        COUNT(DISTINCT sessao_id) AS total_sessoes_digitais,
        COUNT(*) AS total_eventos_digitais,
        SUM(flg_conclusao) AS conclusoes_digitais,
        SUM(flg_abandono) AS abandonos_digitais,
        SUM(flg_erro) AS erros_digitais
    FROM gold.dw_canais_digitais
),

cobranca AS (
    SELECT
        COUNT(*) AS total_acionamentos_cobranca,
        SUM(flg_gerou_acordo) AS acordos_gerados,
        SUM(flg_recuperou_valor) AS recuperacoes_com_valor,
        ROUND(SUM(COALESCE(valor_recuperado, 0))::NUMERIC, 2) AS valor_recuperado_cobranca
    FROM gold.dw_cobranca
),

churn AS (
    SELECT
        SUM(flg_risco_churn) AS clientes_risco_churn,
        SUM(flg_churn_critico) AS clientes_churn_critico,
        ROUND(AVG(score_churn)::NUMERIC, 2) AS score_churn_medio
    FROM gold.dw_churn
)

SELECT
    CURRENT_DATE AS data_referencia,
    TO_CHAR(CURRENT_DATE, 'YYYY-MM') AS safra_referencia,

    c.total_clientes,
    c.clientes_ativos,
    c.clientes_inativos,
    ROUND(c.clientes_ativos::NUMERIC / NULLIF(c.total_clientes, 0), 4) AS taxa_clientes_ativos,
    c.score_medio,
    c.renda_media,

    co.total_contas,
    co.contas_ativas,
    co.saldo_total_contas,

    t.total_transacoes,
    t.transacoes_validas,
    t.valor_transacionado,

    ca.total_cartoes,
    ca.cartoes_ativos,
    ca.limite_total_cartao,
    f.total_faturas,
    f.valor_faturado_cartao,
    f.valor_pago_cartao,
    f.faturas_atrasadas,

    cr.total_contratos_credito,
    cr.valor_contratado_credito,
    cr.saldo_devedor_credito,
    cr.taxa_media_credito,
    cr.saldo_npl_90,
    ROUND(cr.saldo_npl_90 / NULLIF(cr.saldo_devedor_credito, 0), 4) AS perc_npl_90,

    p.total_solicitacoes_portabilidade,
    p.portabilidades_pagas,
    ROUND(p.portabilidades_pagas::NUMERIC / NULLIF(p.total_solicitacoes_portabilidade, 0), 4) AS taxa_conversao_portabilidade,
    p.saldo_solicitado_portabilidade,
    p.saldo_pago_portabilidade,
    p.troco_liberado_portabilidade,

    crm.total_ofertas_crm,
    crm.ofertas_enviadas,
    crm.conversoes_crm,
    ROUND(crm.conversoes_crm::NUMERIC / NULLIF(crm.ofertas_enviadas, 0), 4) AS taxa_conversao_crm,
    crm.receita_estimada_crm,

    d.total_sessoes_digitais,
    d.total_eventos_digitais,
    d.conclusoes_digitais,
    d.abandonos_digitais,
    d.erros_digitais,
    ROUND(d.conclusoes_digitais::NUMERIC / NULLIF(d.total_sessoes_digitais, 0), 4) AS taxa_conclusao_digital,
    ROUND(d.abandonos_digitais::NUMERIC / NULLIF(d.total_sessoes_digitais, 0), 4) AS taxa_abandono_digital,

    cb.total_acionamentos_cobranca,
    cb.acordos_gerados,
    cb.recuperacoes_com_valor,
    cb.valor_recuperado_cobranca,

    ch.clientes_risco_churn,
    ch.clientes_churn_critico,
    ch.score_churn_medio,
    ROUND(ch.clientes_risco_churn::NUMERIC / NULLIF(c.total_clientes, 0), 4) AS taxa_risco_churn,

    CURRENT_TIMESTAMP AS dt_processamento

FROM clientes c
CROSS JOIN contas co
CROSS JOIN transacoes t
CROSS JOIN cartoes ca
CROSS JOIN faturas f
CROSS JOIN credito cr
CROSS JOIN portabilidade p
CROSS JOIN crm
CROSS JOIN digital d
CROSS JOIN cobranca cb
CROSS JOIN churn ch;

-- ============================================================
-- 2. Visão Executiva Cliente
-- ============================================================
--
-- Uma linha por cliente com indicadores consolidados para consulta.
-- ============================================================

CREATE TABLE gold.visao_executiva_cliente AS
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

    COALESCE(c.qtd_contas_ativas, 0) AS qtd_contas_ativas,
    COALESCE(c.saldo_total_contas, 0) AS saldo_total_contas,

    COALESCE(c.qtd_transacoes_validas, 0) AS qtd_transacoes_validas,
    COALESCE(c.valor_transacionado, 0) AS valor_transacionado,
    c.dias_desde_ultima_transacao,

    COALESCE(c.qtd_cartoes_ativos, 0) AS qtd_cartoes_ativos,
    COALESCE(c.limite_total_cartao, 0) AS limite_total_cartao,
    COALESCE(c.valor_total_compras_cartao, 0) AS valor_total_compras_cartao,
    COALESCE(c.maior_atraso_fatura, 0) AS maior_atraso_fatura,
    COALESCE(c.flag_risco_cartao, FALSE) AS flag_risco_cartao,

    COALESCE(c.qtd_contratos_credito, 0) AS qtd_contratos_credito,
    COALESCE(c.valor_total_contratado_credito, 0) AS valor_total_contratado_credito,
    COALESCE(c.saldo_devedor_credito, 0) AS saldo_devedor_credito,
    COALESCE(c.maior_atraso_credito, 0) AS maior_atraso_credito,
    COALESCE(c.saldo_npl_90, 0) AS saldo_npl_90,
    COALESCE(c.flag_risco_credito, FALSE) AS flag_risco_credito,

    COALESCE(c.qtd_solicitacoes_portabilidade, 0) AS qtd_solicitacoes_portabilidade,
    COALESCE(c.qtd_portabilidades_pagas, 0) AS qtd_portabilidades_pagas,
    COALESCE(c.saldo_pago_portabilidade, 0) AS saldo_pago_portabilidade,

    COALESCE(c.qtd_ofertas_crm, 0) AS qtd_ofertas_crm,
    COALESCE(c.qtd_conversoes_crm, 0) AS qtd_conversoes_crm,
    COALESCE(c.receita_estimada_crm, 0) AS receita_estimada_crm,
    COALESCE(c.cluster_crm, 'SEM_CRM') AS cluster_crm,
    COALESCE(c.proxima_melhor_acao, 'NUTRICAO') AS proxima_melhor_acao,

    COALESCE(c.qtd_sessoes_digitais, 0) AS qtd_sessoes_digitais,
    COALESCE(c.qtd_sessoes_abandonadas, 0) AS qtd_sessoes_abandonadas,
    COALESCE(c.qtd_sessoes_com_erro, 0) AS qtd_sessoes_com_erro,
    COALESCE(c.cluster_digital, 'SEM_DIGITAL') AS cluster_digital,

    COALESCE(c.qtd_acionamentos_cobranca, 0) AS qtd_acionamentos_cobranca,
    COALESCE(c.qtd_acordos_cobranca, 0) AS qtd_acordos_cobranca,
    COALESCE(c.qtd_acordos_quebrados, 0) AS qtd_acordos_quebrados,
    COALESCE(c.valor_recuperado_cobranca, 0) AS valor_recuperado_cobranca,
    COALESCE(c.cluster_cobranca, 'SEM_COBRANCA') AS cluster_cobranca,

    COALESCE(c.score_churn, 0) AS score_churn,
    COALESCE(c.faixa_risco_churn, 'NAO_CLASSIFICADO') AS faixa_risco_churn,
    COALESCE(c.flg_risco_churn, 0) AS flg_risco_churn,
    COALESCE(c.flg_churn_critico, 0) AS flg_churn_critico,
    COALESCE(c.acao_retencao_recomendada, 'MANTER_RELACIONAMENTO') AS acao_retencao_recomendada,

    CASE
        WHEN COALESCE(c.flag_risco_credito, FALSE) = TRUE
          OR COALESCE(c.flag_risco_cobranca, FALSE) = TRUE
          OR COALESCE(c.flg_churn_critico, 0) = 1
        THEN 'ALTO_RISCO'
        WHEN COALESCE(c.flag_risco_cartao, FALSE) = TRUE
          OR COALESCE(c.flg_risco_churn, 0) = 1
        THEN 'RISCO_MEDIO'
        ELSE 'RISCO_BAIXO'
    END AS classe_risco_relacionamento,

    CASE
        WHEN COALESCE(c.qtd_conversoes_crm, 0) > 0 THEN 'CLIENTE_RESPONSIVO'
        WHEN COALESCE(c.qtd_portabilidades_pagas, 0) > 0 THEN 'CLIENTE_COM_PORTABILIDADE'
        WHEN COALESCE(c.qtd_contratos_credito, 0) > 0 AND COALESCE(c.qtd_cartoes_ativos, 0) > 0 THEN 'MULTIPRODUTO'
        WHEN COALESCE(c.qtd_transacoes_validas, 0) > 0 THEN 'TRANSACIONAL'
        ELSE 'BAIXO_RELACIONAMENTO'
    END AS perfil_relacionamento,

    CURRENT_TIMESTAMP AS dt_processamento

FROM sdx.cliente_360_v8 c;

-- ============================================================
-- 3. Dashboard Base Executiva
-- ============================================================
--
-- Base agregada por segmento, UF e faixa de risco.
-- ============================================================

CREATE TABLE gold.dashboard_base_executiva AS
SELECT
    segmento,
    uf,
    regiao,
    faixa_risco_churn,
    classe_risco_relacionamento,
    perfil_relacionamento,

    COUNT(*) AS qtd_clientes,
    SUM(CASE WHEN flag_cliente_ativo = TRUE THEN 1 ELSE 0 END) AS qtd_clientes_ativos,
    ROUND(AVG(score_credito)::NUMERIC, 2) AS score_medio,
    ROUND(AVG(renda_mensal)::NUMERIC, 2) AS renda_media,

    ROUND(SUM(saldo_total_contas)::NUMERIC, 2) AS saldo_total_contas,
    ROUND(SUM(valor_transacionado)::NUMERIC, 2) AS valor_transacionado,

    SUM(qtd_cartoes_ativos) AS qtd_cartoes_ativos,
    ROUND(SUM(limite_total_cartao)::NUMERIC, 2) AS limite_total_cartao,
    ROUND(SUM(valor_total_compras_cartao)::NUMERIC, 2) AS valor_total_compras_cartao,

    SUM(qtd_contratos_credito) AS qtd_contratos_credito,
    ROUND(SUM(valor_total_contratado_credito)::NUMERIC, 2) AS valor_total_contratado_credito,
    ROUND(SUM(saldo_devedor_credito)::NUMERIC, 2) AS saldo_devedor_credito,
    ROUND(SUM(saldo_npl_90)::NUMERIC, 2) AS saldo_npl_90,

    SUM(qtd_solicitacoes_portabilidade) AS qtd_solicitacoes_portabilidade,
    SUM(qtd_portabilidades_pagas) AS qtd_portabilidades_pagas,
    ROUND(SUM(saldo_pago_portabilidade)::NUMERIC, 2) AS saldo_pago_portabilidade,

    SUM(qtd_ofertas_crm) AS qtd_ofertas_crm,
    SUM(qtd_conversoes_crm) AS qtd_conversoes_crm,
    ROUND(SUM(receita_estimada_crm)::NUMERIC, 2) AS receita_estimada_crm,

    SUM(qtd_sessoes_digitais) AS qtd_sessoes_digitais,
    SUM(qtd_sessoes_abandonadas) AS qtd_sessoes_abandonadas,
    SUM(qtd_sessoes_com_erro) AS qtd_sessoes_com_erro,

    SUM(qtd_acionamentos_cobranca) AS qtd_acionamentos_cobranca,
    SUM(qtd_acordos_cobranca) AS qtd_acordos_cobranca,
    SUM(qtd_acordos_quebrados) AS qtd_acordos_quebrados,
    ROUND(SUM(valor_recuperado_cobranca)::NUMERIC, 2) AS valor_recuperado_cobranca,

    SUM(flg_risco_churn) AS qtd_risco_churn,
    SUM(flg_churn_critico) AS qtd_churn_critico,
    ROUND(AVG(score_churn)::NUMERIC, 2) AS score_churn_medio,

    CURRENT_TIMESTAMP AS dt_processamento

FROM gold.visao_executiva_cliente
GROUP BY
    segmento,
    uf,
    regiao,
    faixa_risco_churn,
    classe_risco_relacionamento,
    perfil_relacionamento;

-- ============================================================
-- 4. KPI Produtos Executivo
-- ============================================================

CREATE TABLE gold.kpi_produtos_executivo AS
SELECT
    'CREDITO' AS dominio,
    produto,
    subproduto,
    COUNT(*) AS qtd_operacoes,
    COUNT(DISTINCT num_pes) AS qtd_clientes,
    ROUND(SUM(valor_contratado)::NUMERIC, 2) AS valor_operado,
    ROUND(SUM(saldo_devedor)::NUMERIC, 2) AS saldo_atual,
    SUM(flg_inadimplente) AS qtd_inadimplente,
    SUM(flg_npl_90) AS qtd_npl_90,
    CURRENT_TIMESTAMP AS dt_processamento
FROM gold.dw_contratacao
GROUP BY produto, subproduto

UNION ALL

SELECT
    'PORTABILIDADE' AS dominio,
    produto,
    subproduto,
    COUNT(*) AS qtd_operacoes,
    COUNT(DISTINCT num_pes) AS qtd_clientes,
    ROUND(SUM(valor_saldo_devedor)::NUMERIC, 2) AS valor_operado,
    ROUND(SUM(CASE WHEN flg_portabilidade_paga = 1 THEN valor_saldo_devedor ELSE 0 END)::NUMERIC, 2) AS saldo_atual,
    SUM(flg_portabilidade_nao_paga) AS qtd_inadimplente,
    SUM(flg_reprovada_risco) AS qtd_npl_90,
    CURRENT_TIMESTAMP AS dt_processamento
FROM gold.dw_portabilidade
GROUP BY produto, subproduto

UNION ALL

SELECT
    'CARTAO' AS dominio,
    'CARTAO_CREDITO' AS produto,
    'FATURAS' AS subproduto,
    COUNT(*) AS qtd_operacoes,
    COUNT(DISTINCT cliente_id) AS qtd_clientes,
    ROUND(SUM(valor_fatura_tratado)::NUMERIC, 2) AS valor_operado,
    ROUND(SUM(valor_pago)::NUMERIC, 2) AS saldo_atual,
    SUM(CASE WHEN dias_atraso_fatura > 0 THEN 1 ELSE 0 END) AS qtd_inadimplente,
    SUM(CASE WHEN dias_atraso_fatura > 90 THEN 1 ELSE 0 END) AS qtd_npl_90,
    CURRENT_TIMESTAMP AS dt_processamento
FROM silver.faturas_cartao;

-- ============================================================
-- 5. KPI Risco Executivo
-- ============================================================

CREATE TABLE gold.kpi_risco_executivo AS
SELECT
    classe_risco_relacionamento,
    faixa_risco_churn,
    cluster_cobranca,
    cluster_digital,
    cluster_crm,
    COUNT(*) AS qtd_clientes,
    ROUND(AVG(score_credito)::NUMERIC, 2) AS score_credito_medio,
    ROUND(AVG(score_churn)::NUMERIC, 2) AS score_churn_medio,
    ROUND(SUM(saldo_devedor_credito)::NUMERIC, 2) AS saldo_devedor_credito,
    ROUND(SUM(saldo_npl_90)::NUMERIC, 2) AS saldo_npl_90,
    ROUND(SUM(valor_total_compras_cartao)::NUMERIC, 2) AS valor_total_compras_cartao,
    ROUND(SUM(valor_recuperado_cobranca)::NUMERIC, 2) AS valor_recuperado_cobranca,
    CURRENT_TIMESTAMP AS dt_processamento
FROM gold.visao_executiva_cliente
GROUP BY
    classe_risco_relacionamento,
    faixa_risco_churn,
    cluster_cobranca,
    cluster_digital,
    cluster_crm;

-- ============================================================
-- 6. Índices
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_visao_executiva_cliente_num_pes
    ON gold.visao_executiva_cliente (num_pes);

CREATE INDEX IF NOT EXISTS idx_visao_executiva_cliente_segmento
    ON gold.visao_executiva_cliente (segmento);

CREATE INDEX IF NOT EXISTS idx_visao_executiva_cliente_risco
    ON gold.visao_executiva_cliente (classe_risco_relacionamento, faixa_risco_churn);

CREATE INDEX IF NOT EXISTS idx_dashboard_base_executiva_segmento
    ON gold.dashboard_base_executiva (segmento, uf, classe_risco_relacionamento);

CREATE INDEX IF NOT EXISTS idx_kpi_produtos_executivo_dominio
    ON gold.kpi_produtos_executivo (dominio, produto);

ANALYZE gold.kpi_executivo_banco;
ANALYZE gold.visao_executiva_cliente;
ANALYZE gold.dashboard_base_executiva;
ANALYZE gold.kpi_produtos_executivo;
ANALYZE gold.kpi_risco_executivo;

-- ============================================================
-- 7. Quality checks
-- ============================================================

CREATE TABLE meta.quality_gold_executivo AS
SELECT 'kpi_executivo_banco_linhas' AS check_name, COUNT(*) AS qtd
FROM gold.kpi_executivo_banco

UNION ALL

SELECT 'visao_executiva_cliente_linhas', COUNT(*)
FROM gold.visao_executiva_cliente

UNION ALL

SELECT 'dashboard_base_executiva_linhas', COUNT(*)
FROM gold.dashboard_base_executiva

UNION ALL

SELECT 'kpi_produtos_executivo_linhas', COUNT(*)
FROM gold.kpi_produtos_executivo

UNION ALL

SELECT 'kpi_risco_executivo_linhas', COUNT(*)
FROM gold.kpi_risco_executivo

UNION ALL

SELECT 'clientes_alto_risco', COUNT(*)
FROM gold.visao_executiva_cliente
WHERE classe_risco_relacionamento = 'ALTO_RISCO'

UNION ALL

SELECT 'clientes_churn_critico', COUNT(*)
FROM gold.visao_executiva_cliente
WHERE flg_churn_critico = 1

UNION ALL

SELECT 'clientes_multiproduto', COUNT(*)
FROM gold.visao_executiva_cliente
WHERE perfil_relacionamento = 'MULTIPRODUTO';

-- ============================================================
-- 8. Comentários
-- ============================================================

COMMENT ON TABLE gold.kpi_executivo_banco IS
'Visão consolidada executiva do Aurora Bank com principais KPIs de clientes, transações, cartões, crédito, portabilidade, CRM, digital, cobrança e churn.';

COMMENT ON TABLE gold.visao_executiva_cliente IS
'Visão executiva por cliente consolidando relacionamento, risco, crédito, cartão, portabilidade, CRM, digital, cobrança e churn.';

COMMENT ON TABLE gold.dashboard_base_executiva IS
'Base agregada para dashboard executivo em Power BI/Excel.';

COMMENT ON TABLE gold.kpi_produtos_executivo IS
'KPIs executivos por domínio/produto.';

COMMENT ON TABLE gold.kpi_risco_executivo IS
'KPIs executivos por classes de risco, churn, cobrança, digital e CRM.';
