-- ============================================================
-- Aurora Bank Enterprise Data Lab
-- Patch 08 — CRM e Campanhas
-- Banco destino: PostgreSQL
-- ============================================================
--
-- Objetivo:
-- Criar o domínio de CRM/Marketing no Aurora Bank V1.
--
-- Tabelas criadas:
-- - silver.campanhas_crm
-- - silver.ofertas_crm
-- - silver.interacoes_crm
-- - silver.conversoes_crm
-- - sdx.crm_cliente
-- - sdx.segmentacao_crm
-- - sdx.cliente_360_v5
-- - gold.kpi_crm_campanhas
-- - gold.dw_crm
-- - meta.quality_crm
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

DROP TABLE IF EXISTS gold.dw_crm;
DROP TABLE IF EXISTS gold.kpi_crm_campanhas;
DROP TABLE IF EXISTS sdx.cliente_360_v5;
DROP TABLE IF EXISTS sdx.segmentacao_crm;
DROP TABLE IF EXISTS sdx.crm_cliente;
DROP TABLE IF EXISTS silver.conversoes_crm;
DROP TABLE IF EXISTS silver.interacoes_crm;
DROP TABLE IF EXISTS silver.ofertas_crm;
DROP TABLE IF EXISTS silver.campanhas_crm;
DROP TABLE IF EXISTS meta.quality_crm;

-- ============================================================
-- 1. Campanhas CRM
-- ============================================================

CREATE TABLE silver.campanhas_crm (
    campanha_id INTEGER PRIMARY KEY,
    nome_campanha TEXT NOT NULL,
    produto_alvo TEXT NOT NULL,
    canal_principal TEXT NOT NULL,
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    safra_campanha TEXT NOT NULL,
    publico_alvo TEXT NOT NULL,
    objetivo_campanha TEXT NOT NULL,
    custo_campanha NUMERIC(18, 2) NOT NULL,
    status_campanha TEXT NOT NULL,
    dt_processamento TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO silver.campanhas_crm (
    campanha_id,
    nome_campanha,
    produto_alvo,
    canal_principal,
    data_inicio,
    data_fim,
    safra_campanha,
    publico_alvo,
    objetivo_campanha,
    custo_campanha,
    status_campanha
)
VALUES
    (1,  'Cartao Mais Limite Jan/2026',             'CARTAO_CREDITO',       'APP',         DATE '2026-01-05', DATE '2026-01-31', '2026-01', 'CLIENTES_ATIVOS',       'AUMENTO_USO_CARTAO',      75000.00,  'ENCERRADA'),
    (2,  'Credito Pessoal Pre Aprovado Fev/2026',   'CREDITO_PESSOAL',      'WHATSAPP',    DATE '2026-02-01', DATE '2026-02-28', '2026-02', 'SCORE_BOM',             'CONVERSAO_CREDITO',       120000.00, 'ENCERRADA'),
    (3,  'Portabilidade Taxa Menor Mar/2026',       'PORTABILIDADE',        'CALL_CENTER', DATE '2026-03-01', DATE '2026-03-31', '2026-03', 'COM_CREDITO_ATIVO',     'CONVERSAO_PORTABILIDADE', 95000.00,  'ENCERRADA'),
    (4,  'Renovacao Inteligente Abr/2026',          'REFINANCIAMENTO',      'APP',         DATE '2026-04-01', DATE '2026-04-30', '2026-04', 'APTO_RENOVACAO',        'RENOVACAO_CONTRATO',      60000.00,  'ENCERRADA'),
    (5,  'Consignado Digital Mai/2026',             'CONSIGNADO',           'WHATSAPP',    DATE '2026-05-01', DATE '2026-05-31', '2026-05', 'CONSIGNADO',            'CONVERSAO_CONSIGNADO',    85000.00,  'ENCERRADA'),
    (6,  'Recuperacao de Inativos Jun/2026',        'CONTA_DIGITAL',        'EMAIL',       DATE '2026-06-01', DATE '2026-06-30', '2026-06', 'BAIXA_ATIVIDADE',       'REATIVACAO_CLIENTE',      45000.00,  'ENCERRADA'),
    (7,  'Seguro Protecao Financeira Jul/2026',     'SEGURO',               'SMS',         DATE '2026-07-01', DATE '2026-07-31', '2026-07', 'TODOS',                 'CROSS_SELL_SEGURO',       50000.00,  'ENCERRADA'),
    (8,  'Investimentos Prime Ago/2026',            'INVESTIMENTOS',        'APP',         DATE '2026-08-01', DATE '2026-08-31', '2026-08', 'ALTA_RENDA',            'CROSS_SELL_INVESTIMENTO', 90000.00,  'ENCERRADA'),
    (9,  'FGTS Antecipacao Set/2026',               'ANTECIPACAO_FGTS',     'APP',         DATE '2026-09-01', DATE '2026-09-30', '2026-09', 'DIGITAL',               'CONVERSAO_FGTS',          55000.00,  'ENCERRADA'),
    (10, 'Portabilidade Reforco Out/2026',          'PORTABILIDADE',        'WHATSAPP',    DATE '2026-10-01', DATE '2026-10-31', '2026-10', 'SEM_PORTABILIDADE_PAGA', 'CONVERSAO_PORTABILIDADE', 105000.00, 'ENCERRADA'),
    (11, 'Cartao Retencao Nov/2026',                'CARTAO_CREDITO',       'CALL_CENTER', DATE '2026-11-01', DATE '2026-11-30', '2026-11', 'RISCO_CHURN',           'RETENCAO_CLIENTE',        70000.00,  'ENCERRADA'),
    (12, 'Credito Final de Ano Dez/2026',           'CREDITO_PESSOAL',      'APP',         DATE '2026-12-01', DATE '2026-12-31', '2026-12', 'CLIENTES_ATIVOS',       'CONVERSAO_CREDITO',       130000.00, 'ENCERRADA');

-- ============================================================
-- 2. Ofertas CRM
-- ============================================================
--
-- Gera público elegível a partir do Cliente 360 V4 + DW Contratação.
-- A lógica simula campanhas com segmentação de negócio.
-- ============================================================

CREATE TABLE silver.ofertas_crm AS
WITH cliente_base AS (
    SELECT
        c360.cliente_id,
        c360.nome,
        c360.segmento,
        c360.rating_cliente,
        c360.score_credito,
        c360.renda_mensal,
        c360.flag_cliente_ativo,
        COALESCE(c360.qtd_cartoes_ativos, 0) AS qtd_cartoes_ativos,
        COALESCE(c360.qtd_contratos_credito, 0) AS qtd_contratos_credito,
        COALESCE(c360.qtd_solicitacoes_portabilidade, 0) AS qtd_solicitacoes_portabilidade,
        COALESCE(c360.qtd_portabilidades_pagas, 0) AS qtd_portabilidades_pagas,
        COALESCE(c360.flag_risco_churn_inicial, FALSE) AS flag_risco_churn_inicial,
        COALESCE(c360.cluster_atividade_financeira, 'NAO_INFORMADO') AS cluster_atividade_financeira,
        COALESCE(c360.cluster_cartao, 'SEM_CARTAO') AS cluster_cartao,
        COALESCE(c360.cluster_portabilidade, 'SEM_PORTABILIDADE') AS cluster_portabilidade
    FROM sdx.cliente_360_v4 c360
),

apto_renovacao AS (
    SELECT
        num_pes,
        MAX(flg_apto_renovacao) AS flg_apto_renovacao,
        MAX(flg_produto_consignado) AS flg_produto_consignado
    FROM gold.dw_contratacao
    GROUP BY num_pes
),

elegiveis AS (
    SELECT
        camp.campanha_id,
        cb.cliente_id AS num_pes,

        CASE
            WHEN camp.publico_alvo = 'CLIENTES_ATIVOS'
                THEN cb.flag_cliente_ativo = TRUE

            WHEN camp.publico_alvo = 'SCORE_BOM'
                THEN COALESCE(cb.score_credito, 0) >= 650
                 AND cb.flag_cliente_ativo = TRUE

            WHEN camp.publico_alvo = 'COM_CREDITO_ATIVO'
                THEN cb.qtd_contratos_credito > 0

            WHEN camp.publico_alvo = 'APTO_RENOVACAO'
                THEN COALESCE(ar.flg_apto_renovacao, 0) = 1

            WHEN camp.publico_alvo = 'CONSIGNADO'
                THEN cb.segmento = 'CONSIGNADO'
                  OR COALESCE(ar.flg_produto_consignado, 0) = 1

            WHEN camp.publico_alvo = 'BAIXA_ATIVIDADE'
                THEN cb.cluster_atividade_financeira IN ('BAIXA_ATIVIDADE', 'INATIVO_TRANSACIONAL', 'SEM_MOVIMENTO')

            WHEN camp.publico_alvo = 'ALTA_RENDA'
                THEN cb.segmento IN ('ALTA_RENDA', 'INVESTIDOR')
                  OR COALESCE(cb.renda_mensal, 0) >= 10000

            WHEN camp.publico_alvo = 'DIGITAL'
                THEN cb.segmento = 'DIGITAL'
                  OR cb.cluster_atividade_financeira IN ('ALTA_ATIVIDADE', 'ATIVIDADE_MEDIA')

            WHEN camp.publico_alvo = 'SEM_PORTABILIDADE_PAGA'
                THEN cb.qtd_contratos_credito > 0
                 AND cb.qtd_portabilidades_pagas = 0

            WHEN camp.publico_alvo = 'RISCO_CHURN'
                THEN cb.flag_risco_churn_inicial = TRUE

            WHEN camp.publico_alvo = 'TODOS'
                THEN TRUE

            ELSE TRUE
        END AS flg_elegivel,

        cb.rating_cliente,
        cb.score_credito,
        cb.segmento,
        cb.flag_cliente_ativo,
        cb.qtd_cartoes_ativos,
        cb.qtd_contratos_credito,
        cb.cluster_atividade_financeira,
        cb.cluster_cartao,
        cb.cluster_portabilidade

    FROM silver.campanhas_crm camp
    CROSS JOIN cliente_base cb
    LEFT JOIN apto_renovacao ar
        ON cb.cliente_id = ar.num_pes
)

SELECT
    ROW_NUMBER() OVER (ORDER BY e.campanha_id, e.num_pes) AS oferta_id,
    e.campanha_id,
    e.num_pes,
    camp.produto_alvo,
    camp.canal_principal AS canal_oferta,
    camp.safra_campanha,
    (
        camp.data_inicio
        + ((random() * GREATEST((camp.data_fim - camp.data_inicio), 1))::INTEGER)
    )::DATE AS data_oferta,

    ROUND(
        CASE
            WHEN camp.produto_alvo IN ('CREDITO_PESSOAL', 'CONSIGNADO', 'REFINANCIAMENTO') THEN (1000 + random() * 35000)
            WHEN camp.produto_alvo = 'CARTAO_CREDITO' THEN (500 + random() * 20000)
            WHEN camp.produto_alvo = 'PORTABILIDADE' THEN (2000 + random() * 80000)
            WHEN camp.produto_alvo = 'INVESTIMENTOS' THEN (100 + random() * 25000)
            ELSE (100 + random() * 5000)
        END::NUMERIC,
        2
    ) AS valor_oferta,

    CASE
        WHEN e.rating_cliente = 'A' THEN 'ALTA_PROPENSAO'
        WHEN e.rating_cliente = 'B' THEN 'MEDIA_PROPENSAO'
        WHEN e.rating_cliente = 'C' THEN 'BAIXA_PROPENSAO'
        ELSE 'RISCO/SEM_SCORE'
    END AS faixa_propensao,

    e.rating_cliente,
    e.score_credito,
    e.segmento,
    e.flag_cliente_ativo,
    e.qtd_cartoes_ativos,
    e.qtd_contratos_credito,
    e.cluster_atividade_financeira,
    e.cluster_cartao,
    e.cluster_portabilidade,

    CASE
        WHEN e.flg_elegivel = TRUE THEN 1
        ELSE 0
    END AS flg_elegivel,

    CASE
        WHEN e.flg_elegivel = TRUE
         AND random() < 0.72 THEN 1
        ELSE 0
    END AS flg_oferta_enviada,

    CURRENT_TIMESTAMP AS dt_processamento

FROM elegiveis e
INNER JOIN silver.campanhas_crm camp
    ON e.campanha_id = camp.campanha_id
WHERE e.flg_elegivel = TRUE
  AND random() < 0.18;

-- ============================================================
-- 3. Interações CRM
-- ============================================================
--
-- Eventos simulados:
-- ENVIADO -> ENTREGUE -> ABERTO -> CLICADO -> RESPONDIDO
-- ============================================================

CREATE TABLE silver.interacoes_crm AS
WITH eventos AS (
    SELECT
        o.oferta_id,
        o.campanha_id,
        o.num_pes,
        o.canal_oferta AS canal,
        'ENVIADO' AS evento,
        o.data_oferta AS data_evento,
        1 AS ordem_evento
    FROM silver.ofertas_crm o
    WHERE o.flg_oferta_enviada = 1

    UNION ALL

    SELECT
        o.oferta_id,
        o.campanha_id,
        o.num_pes,
        o.canal_oferta,
        'ENTREGUE',
        (o.data_oferta + ((random() * 2)::INTEGER))::DATE,
        2
    FROM silver.ofertas_crm o
    WHERE o.flg_oferta_enviada = 1
      AND random() < 0.88

    UNION ALL

    SELECT
        o.oferta_id,
        o.campanha_id,
        o.num_pes,
        o.canal_oferta,
        'ABERTO',
        (o.data_oferta + ((1 + random() * 5)::INTEGER))::DATE,
        3
    FROM silver.ofertas_crm o
    WHERE o.flg_oferta_enviada = 1
      AND random() < 0.46

    UNION ALL

    SELECT
        o.oferta_id,
        o.campanha_id,
        o.num_pes,
        o.canal_oferta,
        'CLICADO',
        (o.data_oferta + ((1 + random() * 7)::INTEGER))::DATE,
        4
    FROM silver.ofertas_crm o
    WHERE o.flg_oferta_enviada = 1
      AND random() < 0.22

    UNION ALL

    SELECT
        o.oferta_id,
        o.campanha_id,
        o.num_pes,
        o.canal_oferta,
        'RESPONDIDO',
        (o.data_oferta + ((1 + random() * 10)::INTEGER))::DATE,
        5
    FROM silver.ofertas_crm o
    WHERE o.flg_oferta_enviada = 1
      AND random() < 0.12
)

SELECT
    ROW_NUMBER() OVER (ORDER BY campanha_id, num_pes, oferta_id, ordem_evento) AS interacao_id,
    oferta_id,
    campanha_id,
    num_pes,
    canal,
    evento,
    data_evento,
    TO_CHAR(data_evento, 'YYYY-MM') AS safra_evento,
    ordem_evento,
    CURRENT_TIMESTAMP AS dt_processamento
FROM eventos;

-- ============================================================
-- 4. Conversões CRM
-- ============================================================

CREATE TABLE silver.conversoes_crm AS
WITH resumo_interacao AS (
    SELECT
        oferta_id,
        campanha_id,
        num_pes,
        MAX(CASE WHEN evento = 'CLICADO' THEN 1 ELSE 0 END) AS flg_clicado,
        MAX(CASE WHEN evento = 'RESPONDIDO' THEN 1 ELSE 0 END) AS flg_respondido
    FROM silver.interacoes_crm
    GROUP BY
        oferta_id,
        campanha_id,
        num_pes
),

base_conv AS (
    SELECT
        o.oferta_id,
        o.campanha_id,
        o.num_pes,
        o.produto_alvo,
        o.valor_oferta,
        o.data_oferta,
        COALESCE(ri.flg_clicado, 0) AS flg_clicado,
        COALESCE(ri.flg_respondido, 0) AS flg_respondido,
        o.faixa_propensao,
        o.rating_cliente,
        o.score_credito,

        CASE
            WHEN COALESCE(ri.flg_respondido, 0) = 1 AND o.rating_cliente IN ('A', 'B') THEN 0.32
            WHEN COALESCE(ri.flg_clicado, 0) = 1 AND o.rating_cliente IN ('A', 'B') THEN 0.22
            WHEN COALESCE(ri.flg_respondido, 0) = 1 THEN 0.18
            WHEN COALESCE(ri.flg_clicado, 0) = 1 THEN 0.11
            ELSE 0.025
        END AS prob_conversao
    FROM silver.ofertas_crm o
    LEFT JOIN resumo_interacao ri
        ON o.oferta_id = ri.oferta_id
)

SELECT
    ROW_NUMBER() OVER (ORDER BY campanha_id, num_pes, oferta_id) AS conversao_id,
    oferta_id,
    campanha_id,
    num_pes,
    produto_alvo,
    (data_oferta + ((1 + random() * 18)::INTEGER))::DATE AS data_conversao,
    TO_CHAR((data_oferta + ((1 + random() * 18)::INTEGER))::DATE, 'YYYY-MM') AS safra_conversao,

    ROUND(
        CASE
            WHEN produto_alvo IN ('CREDITO_PESSOAL', 'CONSIGNADO', 'REFINANCIAMENTO', 'PORTABILIDADE')
                THEN valor_oferta * (0.035 + random() * 0.080)
            WHEN produto_alvo = 'CARTAO_CREDITO'
                THEN valor_oferta * (0.015 + random() * 0.060)
            WHEN produto_alvo = 'INVESTIMENTOS'
                THEN valor_oferta * (0.003 + random() * 0.012)
            ELSE valor_oferta * (0.010 + random() * 0.040)
        END::NUMERIC,
        2
    ) AS receita_estimada,

    CASE
        WHEN produto_alvo = 'CARTAO_CREDITO' THEN 'CARTAO_ATIVADO'
        WHEN produto_alvo = 'PORTABILIDADE' THEN 'PORTABILIDADE_SOLICITADA'
        WHEN produto_alvo IN ('CREDITO_PESSOAL', 'CONSIGNADO', 'REFINANCIAMENTO') THEN 'PROPOSTA_CREDITO'
        WHEN produto_alvo = 'INVESTIMENTOS' THEN 'APORTE_INICIAL'
        ELSE 'CONVERSAO_PRODUTO'
    END AS tipo_conversao,

    CURRENT_TIMESTAMP AS dt_processamento

FROM base_conv
WHERE random() < prob_conversao;

-- ============================================================
-- 5. SDX — CRM por cliente
-- ============================================================

CREATE TABLE sdx.crm_cliente AS
WITH ofertas AS (
    SELECT
        num_pes,
        COUNT(*) AS qtd_ofertas_crm,
        SUM(flg_oferta_enviada) AS qtd_ofertas_enviadas,
        COUNT(DISTINCT campanha_id) AS qtd_campanhas_impactadas,
        MAX(data_oferta) AS data_ultima_oferta
    FROM silver.ofertas_crm
    GROUP BY num_pes
),

interacoes AS (
    SELECT
        num_pes,
        COUNT(*) AS qtd_interacoes_crm,
        SUM(CASE WHEN evento = 'ENTREGUE' THEN 1 ELSE 0 END) AS qtd_entregues,
        SUM(CASE WHEN evento = 'ABERTO' THEN 1 ELSE 0 END) AS qtd_aberturas,
        SUM(CASE WHEN evento = 'CLICADO' THEN 1 ELSE 0 END) AS qtd_cliques,
        SUM(CASE WHEN evento = 'RESPONDIDO' THEN 1 ELSE 0 END) AS qtd_respostas,
        MAX(data_evento) AS data_ultima_interacao
    FROM silver.interacoes_crm
    GROUP BY num_pes
),

conversoes AS (
    SELECT
        num_pes,
        COUNT(*) AS qtd_conversoes_crm,
        ROUND(SUM(receita_estimada)::NUMERIC, 2) AS receita_estimada_crm,
        MAX(data_conversao) AS data_ultima_conversao
    FROM silver.conversoes_crm
    GROUP BY num_pes
)

SELECT
    COALESCE(o.num_pes, i.num_pes, c.num_pes) AS num_pes,
    COALESCE(o.qtd_ofertas_crm, 0) AS qtd_ofertas_crm,
    COALESCE(o.qtd_ofertas_enviadas, 0) AS qtd_ofertas_enviadas,
    COALESCE(o.qtd_campanhas_impactadas, 0) AS qtd_campanhas_impactadas,
    o.data_ultima_oferta,
    COALESCE(i.qtd_interacoes_crm, 0) AS qtd_interacoes_crm,
    COALESCE(i.qtd_entregues, 0) AS qtd_entregues,
    COALESCE(i.qtd_aberturas, 0) AS qtd_aberturas,
    COALESCE(i.qtd_cliques, 0) AS qtd_cliques,
    COALESCE(i.qtd_respostas, 0) AS qtd_respostas,
    i.data_ultima_interacao,
    COALESCE(c.qtd_conversoes_crm, 0) AS qtd_conversoes_crm,
    COALESCE(c.receita_estimada_crm, 0) AS receita_estimada_crm,
    c.data_ultima_conversao,
    CASE
        WHEN COALESCE(c.qtd_conversoes_crm, 0) > 0 THEN 'CONVERTIDO'
        WHEN COALESCE(i.qtd_respostas, 0) > 0 THEN 'RESPONSIVO'
        WHEN COALESCE(i.qtd_cliques, 0) > 0 THEN 'INTERESSADO'
        WHEN COALESCE(i.qtd_aberturas, 0) > 0 THEN 'ABRIU_SEM_ACAO'
        WHEN COALESCE(o.qtd_ofertas_enviadas, 0) > 0 THEN 'IMPACTADO_SEM_ENGAJAMENTO'
        ELSE 'SEM_CRM'
    END AS cluster_crm
FROM ofertas o
FULL OUTER JOIN interacoes i
    ON o.num_pes = i.num_pes
FULL OUTER JOIN conversoes c
    ON COALESCE(o.num_pes, i.num_pes) = c.num_pes;

-- ============================================================
-- 6. SDX — Segmentação CRM
-- ============================================================

CREATE TABLE sdx.segmentacao_crm AS
SELECT
    c360.cliente_id AS num_pes,
    c360.segmento,
    c360.rating_cliente,
    c360.score_credito,
    c360.renda_mensal,
    COALESCE(c360.qtd_cartoes_ativos, 0) AS qtd_cartoes_ativos,
    COALESCE(c360.qtd_contratos_credito, 0) AS qtd_contratos_credito,
    COALESCE(c360.qtd_solicitacoes_portabilidade, 0) AS qtd_solicitacoes_portabilidade,
    COALESCE(c360.qtd_portabilidades_pagas, 0) AS qtd_portabilidades_pagas,
    COALESCE(c360.flag_risco_churn_inicial, FALSE) AS flag_risco_churn_inicial,
    COALESCE(crm.qtd_ofertas_crm, 0) AS qtd_ofertas_crm,
    COALESCE(crm.qtd_conversoes_crm, 0) AS qtd_conversoes_crm,
    COALESCE(crm.receita_estimada_crm, 0) AS receita_estimada_crm,
    COALESCE(crm.cluster_crm, 'SEM_CRM') AS cluster_crm,

    CASE
        WHEN COALESCE(c360.flag_risco_churn_inicial, FALSE) = TRUE THEN 'RETENCAO'
        WHEN COALESCE(c360.qtd_cartoes_ativos, 0) = 0 AND COALESCE(c360.score_credito, 0) >= 650 THEN 'OFERTA_CARTAO'
        WHEN COALESCE(c360.qtd_contratos_credito, 0) = 0 AND COALESCE(c360.score_credito, 0) >= 650 THEN 'OFERTA_CREDITO'
        WHEN COALESCE(c360.qtd_contratos_credito, 0) > 0 AND COALESCE(c360.qtd_portabilidades_pagas, 0) = 0 THEN 'OFERTA_PORTABILIDADE'
        WHEN COALESCE(crm.qtd_conversoes_crm, 0) > 0 THEN 'CROSS_SELL'
        WHEN c360.segmento IN ('ALTA_RENDA', 'INVESTIDOR') THEN 'INVESTIMENTOS'
        ELSE 'NUTRICAO'
    END AS proxima_melhor_acao,

    CURRENT_TIMESTAMP AS dt_processamento

FROM sdx.cliente_360_v4 c360
LEFT JOIN sdx.crm_cliente crm
    ON c360.cliente_id = crm.num_pes;

-- ============================================================
-- 7. Cliente 360 V5
-- ============================================================

CREATE TABLE sdx.cliente_360_v5 AS
SELECT
    c360.*,
    COALESCE(crm.qtd_ofertas_crm, 0) AS qtd_ofertas_crm,
    COALESCE(crm.qtd_ofertas_enviadas, 0) AS qtd_ofertas_enviadas,
    COALESCE(crm.qtd_campanhas_impactadas, 0) AS qtd_campanhas_impactadas,
    crm.data_ultima_oferta,
    COALESCE(crm.qtd_interacoes_crm, 0) AS qtd_interacoes_crm,
    COALESCE(crm.qtd_aberturas, 0) AS qtd_aberturas_crm,
    COALESCE(crm.qtd_cliques, 0) AS qtd_cliques_crm,
    COALESCE(crm.qtd_respostas, 0) AS qtd_respostas_crm,
    COALESCE(crm.qtd_conversoes_crm, 0) AS qtd_conversoes_crm,
    COALESCE(crm.receita_estimada_crm, 0) AS receita_estimada_crm,
    COALESCE(crm.cluster_crm, 'SEM_CRM') AS cluster_crm,
    COALESCE(seg.proxima_melhor_acao, 'NUTRICAO') AS proxima_melhor_acao
FROM sdx.cliente_360_v4 c360
LEFT JOIN sdx.crm_cliente crm
    ON c360.cliente_id = crm.num_pes
LEFT JOIN sdx.segmentacao_crm seg
    ON c360.cliente_id = seg.num_pes;

-- ============================================================
-- 8. Gold — KPI CRM Campanhas
-- ============================================================

CREATE TABLE gold.kpi_crm_campanhas AS
WITH interacoes AS (
    SELECT
        campanha_id,
        COUNT(*) AS qtd_interacoes,
        SUM(CASE WHEN evento = 'ENVIADO' THEN 1 ELSE 0 END) AS qtd_enviados,
        SUM(CASE WHEN evento = 'ENTREGUE' THEN 1 ELSE 0 END) AS qtd_entregues,
        SUM(CASE WHEN evento = 'ABERTO' THEN 1 ELSE 0 END) AS qtd_aberturas,
        SUM(CASE WHEN evento = 'CLICADO' THEN 1 ELSE 0 END) AS qtd_cliques,
        SUM(CASE WHEN evento = 'RESPONDIDO' THEN 1 ELSE 0 END) AS qtd_respostas
    FROM silver.interacoes_crm
    GROUP BY campanha_id
),

ofertas AS (
    SELECT
        campanha_id,
        COUNT(*) AS qtd_ofertas,
        SUM(flg_oferta_enviada) AS qtd_ofertas_enviadas,
        COUNT(DISTINCT num_pes) AS qtd_clientes_impactados
    FROM silver.ofertas_crm
    GROUP BY campanha_id
),

conversoes AS (
    SELECT
        campanha_id,
        COUNT(*) AS qtd_conversoes,
        ROUND(SUM(receita_estimada)::NUMERIC, 2) AS receita_estimada
    FROM silver.conversoes_crm
    GROUP BY campanha_id
)

SELECT
    c.campanha_id,
    c.nome_campanha,
    c.produto_alvo,
    c.canal_principal,
    c.safra_campanha,
    c.publico_alvo,
    c.objetivo_campanha,
    c.custo_campanha,
    COALESCE(o.qtd_ofertas, 0) AS qtd_ofertas,
    COALESCE(o.qtd_ofertas_enviadas, 0) AS qtd_ofertas_enviadas,
    COALESCE(o.qtd_clientes_impactados, 0) AS qtd_clientes_impactados,
    COALESCE(i.qtd_interacoes, 0) AS qtd_interacoes,
    COALESCE(i.qtd_enviados, 0) AS qtd_enviados,
    COALESCE(i.qtd_entregues, 0) AS qtd_entregues,
    COALESCE(i.qtd_aberturas, 0) AS qtd_aberturas,
    COALESCE(i.qtd_cliques, 0) AS qtd_cliques,
    COALESCE(i.qtd_respostas, 0) AS qtd_respostas,
    COALESCE(cv.qtd_conversoes, 0) AS qtd_conversoes,
    COALESCE(cv.receita_estimada, 0) AS receita_estimada,

    ROUND(COALESCE(i.qtd_entregues, 0)::NUMERIC / NULLIF(COALESCE(i.qtd_enviados, 0), 0), 4) AS taxa_entrega,
    ROUND(COALESCE(i.qtd_aberturas, 0)::NUMERIC / NULLIF(COALESCE(i.qtd_entregues, 0), 0), 4) AS taxa_abertura,
    ROUND(COALESCE(i.qtd_cliques, 0)::NUMERIC / NULLIF(COALESCE(i.qtd_aberturas, 0), 0), 4) AS taxa_clique,
    ROUND(COALESCE(cv.qtd_conversoes, 0)::NUMERIC / NULLIF(COALESCE(o.qtd_ofertas_enviadas, 0), 0), 4) AS taxa_conversao,
    ROUND((COALESCE(cv.receita_estimada, 0) - c.custo_campanha)::NUMERIC / NULLIF(c.custo_campanha, 0), 4) AS roi_estimado

FROM silver.campanhas_crm c
LEFT JOIN ofertas o
    ON c.campanha_id = o.campanha_id
LEFT JOIN interacoes i
    ON c.campanha_id = i.campanha_id
LEFT JOIN conversoes cv
    ON c.campanha_id = cv.campanha_id;

-- ============================================================
-- 9. Gold — DW CRM
-- ============================================================

CREATE TABLE gold.dw_crm AS
SELECT
    o.oferta_id,
    o.campanha_id,
    c.nome_campanha,
    c.produto_alvo,
    c.canal_principal,
    c.publico_alvo,
    c.objetivo_campanha,
    c.safra_campanha,
    o.num_pes,
    cli.nome,
    cli.segmento,
    cli.rating_cliente,
    cli.score_credito,
    cli.renda_mensal,
    o.data_oferta,
    o.valor_oferta,
    o.faixa_propensao,
    o.flg_elegivel,
    o.flg_oferta_enviada,

    COALESCE(MAX(CASE WHEN i.evento = 'ENTREGUE' THEN 1 ELSE 0 END), 0) AS flg_entregue,
    COALESCE(MAX(CASE WHEN i.evento = 'ABERTO' THEN 1 ELSE 0 END), 0) AS flg_aberto,
    COALESCE(MAX(CASE WHEN i.evento = 'CLICADO' THEN 1 ELSE 0 END), 0) AS flg_clicado,
    COALESCE(MAX(CASE WHEN i.evento = 'RESPONDIDO' THEN 1 ELSE 0 END), 0) AS flg_respondido,
    CASE WHEN cv.conversao_id IS NOT NULL THEN 1 ELSE 0 END AS flg_convertido,
    cv.data_conversao,
    cv.tipo_conversao,
    COALESCE(cv.receita_estimada, 0) AS receita_estimada,
    CURRENT_TIMESTAMP AS dt_processamento_dw

FROM silver.ofertas_crm o
INNER JOIN silver.campanhas_crm c
    ON o.campanha_id = c.campanha_id
LEFT JOIN sdx.cliente_360_v4 cli
    ON o.num_pes = cli.cliente_id
LEFT JOIN silver.interacoes_crm i
    ON o.oferta_id = i.oferta_id
LEFT JOIN silver.conversoes_crm cv
    ON o.oferta_id = cv.oferta_id
GROUP BY
    o.oferta_id,
    o.campanha_id,
    c.nome_campanha,
    c.produto_alvo,
    c.canal_principal,
    c.publico_alvo,
    c.objetivo_campanha,
    c.safra_campanha,
    o.num_pes,
    cli.nome,
    cli.segmento,
    cli.rating_cliente,
    cli.score_credito,
    cli.renda_mensal,
    o.data_oferta,
    o.valor_oferta,
    o.faixa_propensao,
    o.flg_elegivel,
    o.flg_oferta_enviada,
    cv.conversao_id,
    cv.data_conversao,
    cv.tipo_conversao,
    cv.receita_estimada;

-- ============================================================
-- 10. Índices
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_dw_crm_num_pes
    ON gold.dw_crm (num_pes);

CREATE INDEX IF NOT EXISTS idx_dw_crm_campanha
    ON gold.dw_crm (campanha_id);

CREATE INDEX IF NOT EXISTS idx_dw_crm_safra
    ON gold.dw_crm (safra_campanha);

CREATE INDEX IF NOT EXISTS idx_dw_crm_flags
    ON gold.dw_crm (flg_oferta_enviada, flg_entregue, flg_aberto, flg_clicado, flg_convertido);

ANALYZE silver.campanhas_crm;
ANALYZE silver.ofertas_crm;
ANALYZE silver.interacoes_crm;
ANALYZE silver.conversoes_crm;
ANALYZE sdx.crm_cliente;
ANALYZE sdx.segmentacao_crm;
ANALYZE sdx.cliente_360_v5;
ANALYZE gold.kpi_crm_campanhas;
ANALYZE gold.dw_crm;

-- ============================================================
-- 11. Quality checks
-- ============================================================

CREATE TABLE meta.quality_crm AS
SELECT 'campanhas_crm' AS check_name, COUNT(*) AS qtd
FROM silver.campanhas_crm

UNION ALL

SELECT 'ofertas_crm', COUNT(*)
FROM silver.ofertas_crm

UNION ALL

SELECT 'ofertas_enviadas', COUNT(*)
FROM silver.ofertas_crm
WHERE flg_oferta_enviada = 1

UNION ALL

SELECT 'interacoes_crm', COUNT(*)
FROM silver.interacoes_crm

UNION ALL

SELECT 'conversoes_crm', COUNT(*)
FROM silver.conversoes_crm

UNION ALL

SELECT 'clientes_impactados', COUNT(DISTINCT num_pes)
FROM silver.ofertas_crm

UNION ALL

SELECT 'clientes_convertidos', COUNT(DISTINCT num_pes)
FROM silver.conversoes_crm

UNION ALL

SELECT 'dw_crm_linhas', COUNT(*)
FROM gold.dw_crm

UNION ALL

SELECT 'cliente_360_v5_linhas', COUNT(*)
FROM sdx.cliente_360_v5;

-- ============================================================
-- 12. Comentários
-- ============================================================

COMMENT ON TABLE gold.dw_crm IS
'Tabela flat de CRM do Aurora Bank, simulando uma DW corporativa para análise de campanhas, ofertas, interações, conversão e ROI.';

COMMENT ON COLUMN gold.dw_crm.num_pes IS
'Identificador da pessoa/cliente no padrão de DW bancária.';

COMMENT ON COLUMN gold.dw_crm.flg_convertido IS
'Flag 1/0 que indica se a oferta gerou conversão.';

COMMENT ON COLUMN sdx.segmentacao_crm.proxima_melhor_acao IS
'Classificação analítica indicando a próxima melhor ação de CRM para o cliente.';
