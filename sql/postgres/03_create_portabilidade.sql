-- ============================================================
-- Aurora Bank Enterprise Data Lab
-- Patch 07 — Portabilidade
-- Banco destino: PostgreSQL
-- ============================================================
--
-- Objetivo:
-- Criar o domínio de portabilidade no Aurora Bank V1.
--
-- Tabelas criadas:
-- - silver.bancos_origem
-- - silver.propostas_portabilidade
-- - silver.contratos_portados
-- - sdx.funil_portabilidade
-- - sdx.portabilidade_cliente
-- - sdx.cliente_360_v4
-- - gold.kpi_portabilidade_mensal
-- - gold.dw_portabilidade
-- - meta.quality_portabilidade
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

DROP TABLE IF EXISTS gold.dw_portabilidade;
DROP TABLE IF EXISTS gold.kpi_portabilidade_mensal;
DROP TABLE IF EXISTS sdx.cliente_360_v4;
DROP TABLE IF EXISTS sdx.portabilidade_cliente;
DROP TABLE IF EXISTS sdx.funil_portabilidade;
DROP TABLE IF EXISTS silver.contratos_portados;
DROP TABLE IF EXISTS silver.propostas_portabilidade;
DROP TABLE IF EXISTS silver.bancos_origem;
DROP TABLE IF EXISTS meta.quality_portabilidade;

-- ============================================================
-- 1. Bancos de origem
-- ============================================================

CREATE TABLE silver.bancos_origem (
    banco_origem_id INTEGER PRIMARY KEY,
    nome_banco_origem TEXT NOT NULL,
    tipo_instituicao TEXT NOT NULL,
    segmento_concorrente TEXT NOT NULL,
    flg_banco_digital INTEGER NOT NULL,
    dt_processamento TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO silver.bancos_origem (
    banco_origem_id,
    nome_banco_origem,
    tipo_instituicao,
    segmento_concorrente,
    flg_banco_digital
)
VALUES
    (1,  'Banco Horizonte',       'BANCO_MULTIPLO',     'TRADICIONAL', 0),
    (2,  'NexaBank',              'BANCO_DIGITAL',      'DIGITAL',     1),
    (3,  'Banco Popular Sul',     'BANCO_MULTIPLO',     'REGIONAL',    0),
    (4,  'CredMais Financeira',   'FINANCEIRA',         'FINANCEIRA',  0),
    (5,  'Intera Crédito',        'BANCO_DIGITAL',      'DIGITAL',     1),
    (6,  'Banco Delta',           'BANCO_MULTIPLO',     'TRADICIONAL', 0),
    (7,  'Financeira União',      'FINANCEIRA',         'FINANCEIRA',  0),
    (8,  'Banco Nacional Prime',  'BANCO_MULTIPLO',     'TRADICIONAL', 0),
    (9,  'ContaLivre Bank',       'BANCO_DIGITAL',      'DIGITAL',     1),
    (10, 'Crédito Fácil S.A.',    'FINANCEIRA',         'FINANCEIRA',  0);

-- ============================================================
-- 2. Propostas de portabilidade
-- ============================================================
--
-- A base é gerada a partir de contratos de crédito existentes.
-- Isso cria uma lógica realista:
-- clientes com contratos ativos podem simular portabilidade.
-- ============================================================

CREATE TABLE silver.propostas_portabilidade AS
WITH contratos_elegiveis AS (
    SELECT
        ct.contrato_id,
        ct.cliente_id,
        ct.produto_credito,
        ct.canal_contratacao,
        ct.data_contratacao,
        ct.valor_contratado,
        ct.saldo_devedor_tratado,
        ct.taxa_mensal,
        ct.prazo_meses,
        ct.status_contrato,
        ct.dias_atraso_atual,
        cli.segmento,
        cli.rating_cliente,
        cli.score_credito,
        cli.renda_mensal_tratada,
        ROW_NUMBER() OVER (ORDER BY random()) AS rn
    FROM silver.contratos_credito ct
    INNER JOIN silver.clientes cli
        ON ct.cliente_id = cli.cliente_id
    WHERE ct.status_contrato IN ('ATIVO', 'RENEGOCIADO')
      AND COALESCE(ct.saldo_devedor_tratado, 0) > 1000
      AND COALESCE(ct.taxa_mensal, 0) > 0
      AND ct.flag_cliente_orfao = FALSE
      AND random() < 0.42
    LIMIT 120000
),

base_gerada AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY ce.rn) AS portabilidade_id,
        ce.contrato_id AS contrato_referencia_id,
        ce.cliente_id,
        ((random() * 9)::INTEGER + 1) AS banco_origem_id,

        CASE
            WHEN ce.produto_credito IN ('CONSIGNADO_PRIVADO', 'CONSIGNADO_PUBLICO', 'CONSIGNADO_INSS') THEN ce.produto_credito
            WHEN ce.produto_credito = 'REFINANCIAMENTO' THEN 'PORTABILIDADE_REFIN'
            ELSE 'PORTABILIDADE_CREDITO_PESSOAL'
        END AS produto_portabilidade,

        CASE
            WHEN ce.canal_contratacao IN ('APP', 'SITE') AND random() < 0.70 THEN ce.canal_contratacao
            WHEN random() < 0.35 THEN 'WHATSAPP'
            WHEN random() < 0.55 THEN 'CORRESPONDENTE'
            WHEN random() < 0.75 THEN 'CALL_CENTER'
            ELSE 'APP'
        END AS canal_solicitacao,

        CASE
            WHEN ce.canal_contratacao IN ('APP', 'SITE') THEN 'DIGITAL'
            WHEN ce.canal_contratacao IN ('CORRESPONDENTE', 'AGENCIA') THEN 'PARCEIRO_FISICO'
            WHEN ce.canal_contratacao IN ('WHATSAPP', 'CALL_CENTER') THEN 'ATENDIMENTO'
            ELSE 'OUTROS'
        END AS origem,

        (
            ce.data_contratacao
            + (
                (random() * GREATEST((DATE '2026-12-31' - ce.data_contratacao), 1))::INTEGER
              )
        )::DATE AS data_solicitacao,

        ROUND(COALESCE(ce.saldo_devedor_tratado, ce.valor_contratado)::NUMERIC, 2) AS valor_saldo_devedor,

        ROUND((ce.taxa_mensal + (0.004 + random() * 0.030))::NUMERIC, 4) AS taxa_origem,

        ROUND(
            GREATEST(
                0.004,
                ce.taxa_mensal * (0.55 + random() * 0.48)
            )::NUMERIC,
            4
        ) AS taxa_ofertada,

        GREATEST(6, (ce.prazo_meses - ((random() * ce.prazo_meses)::INTEGER))) AS prazo_remanescente,

        ce.segmento,
        ce.rating_cliente,
        ce.score_credito,
        ce.renda_mensal_tratada,

        random() AS fator_decisao,
        ce.dias_atraso_atual
    FROM contratos_elegiveis ce
),

status_calc AS (
    SELECT
        bg.*,

        ROUND((bg.taxa_origem - bg.taxa_ofertada)::NUMERIC, 4) AS ganho_taxa,

        ROUND(
            CASE
                WHEN bg.taxa_origem - bg.taxa_ofertada >= 0.015
                    THEN bg.valor_saldo_devedor * (0.04 + random() * 0.16)
                WHEN bg.taxa_origem - bg.taxa_ofertada >= 0.005
                    THEN bg.valor_saldo_devedor * (0.01 + random() * 0.08)
                ELSE 0
            END::NUMERIC,
            2
        ) AS valor_troco_estimado,

        CASE
            WHEN bg.dias_atraso_atual >= 90 THEN 'REPROVADA_RISCO'
            WHEN bg.taxa_origem - bg.taxa_ofertada >= 0.015 AND bg.fator_decisao < 0.58 THEN 'PAGA'
            WHEN bg.taxa_origem - bg.taxa_ofertada >= 0.005 AND bg.fator_decisao < 0.42 THEN 'PAGA'
            WHEN bg.taxa_origem - bg.taxa_ofertada < 0.002 AND bg.fator_decisao < 0.45 THEN 'PERDIDA_TAXA'
            WHEN bg.fator_decisao < 0.12 THEN 'CANCELADA_CLIENTE'
            WHEN bg.fator_decisao < 0.24 THEN 'RETIDA_BANCO_ORIGEM'
            WHEN bg.fator_decisao < 0.34 THEN 'DOCUMENTACAO_PENDENTE'
            ELSE 'EM_ANALISE'
        END AS status_portabilidade
    FROM base_gerada bg
),

datas_calc AS (
    SELECT
        sc.*,

        (sc.data_solicitacao + ((3 + random() * 10)::INTEGER))::DATE AS data_envio_banco_origem,

        (sc.data_solicitacao + ((8 + random() * 18)::INTEGER))::DATE AS data_retorno_banco_origem,

        CASE
            WHEN sc.status_portabilidade = 'PAGA'
                THEN (sc.data_solicitacao + ((12 + random() * 24)::INTEGER))::DATE
            ELSE NULL
        END AS data_pagamento,

        CASE
            WHEN sc.status_portabilidade = 'PAGA'
                THEN sc.valor_troco_estimado
            ELSE 0
        END AS valor_troco_liberado,

        CASE
            WHEN sc.status_portabilidade = 'PAGA' THEN NULL
            WHEN sc.status_portabilidade = 'PERDIDA_TAXA' THEN 'TAXA_NAO_COMPETITIVA'
            WHEN sc.status_portabilidade = 'CANCELADA_CLIENTE' THEN 'CLIENTE_DESISTIU'
            WHEN sc.status_portabilidade = 'RETIDA_BANCO_ORIGEM' THEN 'RETENCAO_BANCO_ORIGEM'
            WHEN sc.status_portabilidade = 'DOCUMENTACAO_PENDENTE' THEN 'DOCUMENTACAO_PENDENTE'
            WHEN sc.status_portabilidade = 'REPROVADA_RISCO' THEN 'RISCO_CREDITO'
            ELSE NULL
        END AS motivo_perda
    FROM status_calc sc
)

SELECT
    portabilidade_id,
    contrato_referencia_id,
    cliente_id AS num_pes,
    banco_origem_id,
    produto_portabilidade,
    canal_solicitacao AS canal,
    origem,
    data_solicitacao,
    data_envio_banco_origem,
    data_retorno_banco_origem,
    data_pagamento,
    TO_CHAR(data_solicitacao, 'YYYY-MM') AS safra_solicitacao,
    valor_saldo_devedor,
    taxa_origem,
    taxa_ofertada,
    ganho_taxa,
    prazo_remanescente,
    valor_troco_estimado,
    valor_troco_liberado,
    status_portabilidade,
    motivo_perda,
    segmento,
    rating_cliente,
    score_credito,
    renda_mensal_tratada AS renda_mensal,
    CASE
        WHEN data_pagamento IS NOT NULL THEN data_pagamento - data_solicitacao
        ELSE NULL
    END AS dias_entre_solicitacao_pagamento,
    CASE
        WHEN data_retorno_banco_origem IS NOT NULL THEN data_retorno_banco_origem - data_envio_banco_origem
        ELSE NULL
    END AS dias_retorno_banco_origem,
    CURRENT_TIMESTAMP AS dt_processamento
FROM datas_calc;

-- ============================================================
-- 3. Contratos portados
-- ============================================================

CREATE TABLE silver.contratos_portados AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pp.portabilidade_id) AS contrato_portado_id,
    pp.portabilidade_id,
    pp.num_pes,
    pp.contrato_referencia_id,
    pp.banco_origem_id,
    pp.produto_portabilidade,
    pp.data_pagamento AS data_contratacao_portabilidade,
    pp.safra_solicitacao AS safra_portabilidade,
    pp.valor_saldo_devedor AS valor_portado,
    pp.valor_troco_liberado,
    pp.taxa_origem,
    pp.taxa_ofertada,
    pp.ganho_taxa,
    pp.prazo_remanescente,
    pp.canal,
    pp.origem,
    'ATIVO' AS status_contrato_portado,
    CURRENT_TIMESTAMP AS dt_processamento
FROM silver.propostas_portabilidade pp
WHERE pp.status_portabilidade = 'PAGA';

-- ============================================================
-- 4. SDX — Funil de portabilidade
-- ============================================================

CREATE TABLE sdx.funil_portabilidade AS
SELECT
    safra_solicitacao,
    produto_portabilidade,
    canal,
    origem,
    bo.nome_banco_origem,
    bo.segmento_concorrente,
    COUNT(*) AS qtd_solicitacoes,
    SUM(CASE WHEN status_portabilidade = 'PAGA' THEN 1 ELSE 0 END) AS qtd_pagas,
    SUM(CASE WHEN status_portabilidade = 'EM_ANALISE' THEN 1 ELSE 0 END) AS qtd_em_analise,
    SUM(CASE WHEN status_portabilidade <> 'PAGA' THEN 1 ELSE 0 END) AS qtd_nao_pagas,
    ROUND(SUM(valor_saldo_devedor)::NUMERIC, 2) AS saldo_solicitado,
    ROUND(SUM(CASE WHEN status_portabilidade = 'PAGA' THEN valor_saldo_devedor ELSE 0 END)::NUMERIC, 2) AS saldo_pago,
    ROUND(SUM(valor_troco_liberado)::NUMERIC, 2) AS troco_liberado,
    ROUND(AVG(taxa_origem)::NUMERIC, 4) AS taxa_origem_media,
    ROUND(AVG(taxa_ofertada)::NUMERIC, 4) AS taxa_ofertada_media,
    ROUND(AVG(ganho_taxa)::NUMERIC, 4) AS ganho_taxa_medio,
    ROUND(
        SUM(CASE WHEN status_portabilidade = 'PAGA' THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0),
        4
    ) AS taxa_conversao
FROM silver.propostas_portabilidade pp
LEFT JOIN silver.bancos_origem bo
    ON pp.banco_origem_id = bo.banco_origem_id
GROUP BY
    safra_solicitacao,
    produto_portabilidade,
    canal,
    origem,
    bo.nome_banco_origem,
    bo.segmento_concorrente;

-- ============================================================
-- 5. SDX — Portabilidade por cliente
-- ============================================================

CREATE TABLE sdx.portabilidade_cliente AS
SELECT
    pp.num_pes,
    COUNT(*) AS qtd_solicitacoes_portabilidade,
    SUM(CASE WHEN pp.status_portabilidade = 'PAGA' THEN 1 ELSE 0 END) AS qtd_portabilidades_pagas,
    SUM(CASE WHEN pp.status_portabilidade <> 'PAGA' THEN 1 ELSE 0 END) AS qtd_portabilidades_nao_pagas,
    ROUND(SUM(pp.valor_saldo_devedor)::NUMERIC, 2) AS saldo_solicitado_portabilidade,
    ROUND(SUM(CASE WHEN pp.status_portabilidade = 'PAGA' THEN pp.valor_saldo_devedor ELSE 0 END)::NUMERIC, 2) AS saldo_pago_portabilidade,
    ROUND(SUM(pp.valor_troco_liberado)::NUMERIC, 2) AS troco_liberado_portabilidade,
    ROUND(AVG(pp.ganho_taxa)::NUMERIC, 4) AS ganho_taxa_medio_portabilidade,
    MAX(pp.data_solicitacao) AS data_ultima_solicitacao_portabilidade,
    MAX(pp.data_pagamento) AS data_ultima_portabilidade_paga,
    CASE
        WHEN SUM(CASE WHEN pp.status_portabilidade = 'PAGA' THEN 1 ELSE 0 END) > 0 THEN 'CONVERTEU_PORTABILIDADE'
        WHEN COUNT(*) >= 2 THEN 'RECORRENTE_NAO_CONVERTIDO'
        ELSE 'SOLICITANTE_PORTABILIDADE'
    END AS cluster_portabilidade
FROM silver.propostas_portabilidade pp
GROUP BY pp.num_pes;

-- ============================================================
-- 6. Cliente 360 V4
-- ============================================================

CREATE TABLE sdx.cliente_360_v4 AS
SELECT
    c360.*,
    COALESCE(pc.qtd_solicitacoes_portabilidade, 0) AS qtd_solicitacoes_portabilidade,
    COALESCE(pc.qtd_portabilidades_pagas, 0) AS qtd_portabilidades_pagas,
    COALESCE(pc.qtd_portabilidades_nao_pagas, 0) AS qtd_portabilidades_nao_pagas,
    COALESCE(pc.saldo_solicitado_portabilidade, 0) AS saldo_solicitado_portabilidade,
    COALESCE(pc.saldo_pago_portabilidade, 0) AS saldo_pago_portabilidade,
    COALESCE(pc.troco_liberado_portabilidade, 0) AS troco_liberado_portabilidade,
    COALESCE(pc.ganho_taxa_medio_portabilidade, 0) AS ganho_taxa_medio_portabilidade,
    pc.data_ultima_solicitacao_portabilidade,
    pc.data_ultima_portabilidade_paga,
    COALESCE(pc.cluster_portabilidade, 'SEM_PORTABILIDADE') AS cluster_portabilidade
FROM sdx.cliente_360_v3 c360
LEFT JOIN sdx.portabilidade_cliente pc
    ON c360.cliente_id = pc.num_pes;

-- ============================================================
-- 7. Gold — KPI mensal de portabilidade
-- ============================================================

CREATE TABLE gold.kpi_portabilidade_mensal AS
SELECT
    safra_solicitacao,
    produto_portabilidade,
    canal,
    origem,
    COUNT(*) AS qtd_solicitacoes,
    SUM(CASE WHEN status_portabilidade = 'PAGA' THEN 1 ELSE 0 END) AS qtd_pagas,
    SUM(CASE WHEN status_portabilidade <> 'PAGA' THEN 1 ELSE 0 END) AS qtd_nao_pagas,
    ROUND(SUM(valor_saldo_devedor)::NUMERIC, 2) AS saldo_solicitado,
    ROUND(SUM(CASE WHEN status_portabilidade = 'PAGA' THEN valor_saldo_devedor ELSE 0 END)::NUMERIC, 2) AS saldo_pago,
    ROUND(SUM(valor_troco_liberado)::NUMERIC, 2) AS troco_liberado,
    ROUND(AVG(taxa_origem)::NUMERIC, 4) AS taxa_origem_media,
    ROUND(AVG(taxa_ofertada)::NUMERIC, 4) AS taxa_ofertada_media,
    ROUND(AVG(ganho_taxa)::NUMERIC, 4) AS ganho_taxa_medio,
    ROUND(
        SUM(CASE WHEN status_portabilidade = 'PAGA' THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0),
        4
    ) AS taxa_conversao
FROM silver.propostas_portabilidade
GROUP BY
    safra_solicitacao,
    produto_portabilidade,
    canal,
    origem;

-- ============================================================
-- 8. Gold — DW Portabilidade
-- ============================================================

CREATE TABLE gold.dw_portabilidade AS
SELECT
    pp.portabilidade_id,
    pp.num_pes,
    pp.contrato_referencia_id,
    cp.contrato_portado_id,
    pp.banco_origem_id,
    bo.nome_banco_origem,
    bo.tipo_instituicao,
    bo.segmento_concorrente,
    bo.flg_banco_digital,

    CASE
        WHEN pp.produto_portabilidade IN ('CONSIGNADO_PRIVADO', 'CONSIGNADO_PUBLICO', 'CONSIGNADO_INSS') THEN 200
        WHEN pp.produto_portabilidade = 'PORTABILIDADE_REFIN' THEN 300
        WHEN pp.produto_portabilidade = 'PORTABILIDADE_CREDITO_PESSOAL' THEN 100
        ELSE 999
    END AS lc_cod,

    pp.produto_portabilidade AS produto,
    CASE
        WHEN pp.produto_portabilidade IN ('CONSIGNADO_PRIVADO', 'CONSIGNADO_PUBLICO', 'CONSIGNADO_INSS') THEN 'CONSIGNADO'
        WHEN pp.produto_portabilidade = 'PORTABILIDADE_REFIN' THEN 'RENOVACAO_REFIN'
        ELSE 'CREDITO_PESSOAL'
    END AS subproduto,

    pp.canal,
    pp.origem,
    pp.data_solicitacao,
    pp.data_envio_banco_origem,
    pp.data_retorno_banco_origem,
    pp.data_pagamento,
    pp.safra_solicitacao,

    pp.valor_saldo_devedor,
    pp.taxa_origem,
    pp.taxa_ofertada,
    pp.ganho_taxa,
    pp.prazo_remanescente,
    pp.valor_troco_estimado,
    pp.valor_troco_liberado,

    pp.status_portabilidade,
    pp.motivo_perda,
    pp.segmento,
    pp.rating_cliente,
    pp.score_credito,
    pp.renda_mensal,
    pp.dias_entre_solicitacao_pagamento,
    pp.dias_retorno_banco_origem,

    CASE WHEN pp.status_portabilidade = 'PAGA' THEN 1 ELSE 0 END AS flg_portabilidade_paga,
    CASE WHEN pp.status_portabilidade <> 'PAGA' THEN 1 ELSE 0 END AS flg_portabilidade_nao_paga,
    CASE WHEN pp.status_portabilidade = 'EM_ANALISE' THEN 1 ELSE 0 END AS flg_em_analise,
    CASE WHEN pp.status_portabilidade = 'RETIDA_BANCO_ORIGEM' THEN 1 ELSE 0 END AS flg_retida_banco_origem,
    CASE WHEN pp.status_portabilidade = 'PERDIDA_TAXA' THEN 1 ELSE 0 END AS flg_perdida_taxa,
    CASE WHEN pp.status_portabilidade = 'REPROVADA_RISCO' THEN 1 ELSE 0 END AS flg_reprovada_risco,

    CASE WHEN pp.ganho_taxa >= 0.015 THEN 1 ELSE 0 END AS flg_oferta_competitiva,
    CASE WHEN pp.valor_troco_liberado > 0 THEN 1 ELSE 0 END AS flg_com_troco,
    CASE WHEN bo.flg_banco_digital = 1 THEN 1 ELSE 0 END AS flg_origem_banco_digital,

    CURRENT_TIMESTAMP AS dt_processamento_dw

FROM silver.propostas_portabilidade pp
LEFT JOIN silver.contratos_portados cp
    ON pp.portabilidade_id = cp.portabilidade_id
LEFT JOIN silver.bancos_origem bo
    ON pp.banco_origem_id = bo.banco_origem_id;

-- ============================================================
-- 9. Índices
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_dw_portabilidade_num_pes
    ON gold.dw_portabilidade (num_pes);

CREATE INDEX IF NOT EXISTS idx_dw_portabilidade_safra
    ON gold.dw_portabilidade (safra_solicitacao);

CREATE INDEX IF NOT EXISTS idx_dw_portabilidade_status
    ON gold.dw_portabilidade (status_portabilidade);

CREATE INDEX IF NOT EXISTS idx_dw_portabilidade_banco_origem
    ON gold.dw_portabilidade (banco_origem_id);

CREATE INDEX IF NOT EXISTS idx_dw_portabilidade_flags
    ON gold.dw_portabilidade (flg_portabilidade_paga, flg_perdida_taxa, flg_retida_banco_origem);

ANALYZE silver.propostas_portabilidade;
ANALYZE silver.contratos_portados;
ANALYZE sdx.funil_portabilidade;
ANALYZE sdx.portabilidade_cliente;
ANALYZE sdx.cliente_360_v4;
ANALYZE gold.kpi_portabilidade_mensal;
ANALYZE gold.dw_portabilidade;

-- ============================================================
-- 10. Quality checks
-- ============================================================

CREATE TABLE meta.quality_portabilidade AS
SELECT 'propostas_portabilidade' AS check_name, COUNT(*) AS qtd
FROM silver.propostas_portabilidade

UNION ALL

SELECT 'contratos_portados', COUNT(*)
FROM silver.contratos_portados

UNION ALL

SELECT 'clientes_com_solicitacao_portabilidade', COUNT(DISTINCT num_pes)
FROM silver.propostas_portabilidade

UNION ALL

SELECT 'clientes_com_portabilidade_paga', COUNT(DISTINCT num_pes)
FROM silver.propostas_portabilidade
WHERE status_portabilidade = 'PAGA'

UNION ALL

SELECT 'portabilidades_pagas', COUNT(*)
FROM silver.propostas_portabilidade
WHERE status_portabilidade = 'PAGA'

UNION ALL

SELECT 'portabilidades_perdidas_taxa', COUNT(*)
FROM silver.propostas_portabilidade
WHERE status_portabilidade = 'PERDIDA_TAXA'

UNION ALL

SELECT 'portabilidades_retidas_banco_origem', COUNT(*)
FROM silver.propostas_portabilidade
WHERE status_portabilidade = 'RETIDA_BANCO_ORIGEM'

UNION ALL

SELECT 'portabilidades_reprovadas_risco', COUNT(*)
FROM silver.propostas_portabilidade
WHERE status_portabilidade = 'REPROVADA_RISCO'

UNION ALL

SELECT 'portabilidades_com_troco', COUNT(*)
FROM silver.propostas_portabilidade
WHERE valor_troco_liberado > 0

UNION ALL

SELECT 'portabilidades_sem_banco_origem', COUNT(*)
FROM silver.propostas_portabilidade pp
LEFT JOIN silver.bancos_origem bo
    ON pp.banco_origem_id = bo.banco_origem_id
WHERE bo.banco_origem_id IS NULL

UNION ALL

SELECT 'dw_portabilidade_linhas', COUNT(*)
FROM gold.dw_portabilidade;

-- ============================================================
-- 11. Comentários
-- ============================================================

COMMENT ON TABLE gold.dw_portabilidade IS
'Tabela flat de portabilidade do Aurora Bank, simulando DW corporativa para análise de funil, banco origem, taxa, troco, conversão e retenção.';

COMMENT ON COLUMN gold.dw_portabilidade.num_pes IS
'Identificador da pessoa/cliente no padrão de DW bancária.';

COMMENT ON COLUMN gold.dw_portabilidade.lc_cod IS
'Código fictício de linha/produto de portabilidade.';

COMMENT ON COLUMN gold.dw_portabilidade.flg_portabilidade_paga IS
'Flag 1/0 que indica portabilidade convertida/paga.';

COMMENT ON COLUMN gold.dw_portabilidade.flg_perdida_taxa IS
'Flag 1/0 que indica perda por taxa não competitiva.';

COMMENT ON COLUMN gold.dw_portabilidade.flg_retida_banco_origem IS
'Flag 1/0 que indica retenção pelo banco de origem.';
