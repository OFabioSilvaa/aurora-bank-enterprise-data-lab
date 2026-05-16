-- ============================================================
-- Aurora Bank Enterprise Data Lab
-- Patch 10 — Cobrança
-- Banco destino: PostgreSQL
-- ============================================================
--
-- Objetivo:
-- Criar o domínio de cobrança no Aurora Bank V1.
--
-- Tabelas criadas:
-- - silver.acionamentos_cobranca
-- - silver.acordos_cobranca
-- - silver.pagamentos_acordo
-- - sdx.cobranca_cliente
-- - sdx.cliente_360_v7
-- - gold.kpi_cobranca_mensal
-- - gold.dw_cobranca
-- - meta.quality_cobranca
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

DROP TABLE IF EXISTS gold.dw_cobranca;
DROP TABLE IF EXISTS gold.kpi_cobranca_mensal;
DROP TABLE IF EXISTS sdx.cliente_360_v7;
DROP TABLE IF EXISTS sdx.cobranca_cliente;
DROP TABLE IF EXISTS silver.pagamentos_acordo;
DROP TABLE IF EXISTS silver.acordos_cobranca;
DROP TABLE IF EXISTS silver.acionamentos_cobranca;
DROP TABLE IF EXISTS meta.quality_cobranca;

-- ============================================================
-- 1. Acionamentos de cobrança
-- ============================================================
--
-- Geração baseada na gold.dw_contratacao:
-- contratos com atraso, NPL ou parcelas em atraso entram em cobrança.
-- ============================================================

CREATE TABLE silver.acionamentos_cobranca AS
WITH contratos_em_risco AS (
    SELECT
        dc.num_pes,
        dc.ctr_numero,
        dc.lc_cod,
        dc.produto,
        dc.subproduto,
        dc.canal,
        dc.origem,
        dc.nome,
        dc.segmento,
        dc.rating_cliente,
        dc.score_credito,
        dc.valor_contratado,
        dc.saldo_devedor,
        dc.parcela,
        dc.status_contrato,
        dc.dias_atraso_atual,
        dc.bucket_atraso,
        dc.qtd_parcelas_em_atraso,
        dc.valor_parcelas_em_atraso,
        dc.maior_atraso_parcela,
        dc.flg_inadimplente,
        dc.flg_npl_90,
        dc.flg_cliente_ativo
    FROM gold.dw_contratacao dc
    WHERE dc.flg_inadimplente = 1
       OR dc.flg_npl_90 = 1
       OR COALESCE(dc.dias_atraso_atual, 0) > 0
       OR COALESCE(dc.qtd_parcelas_em_atraso, 0) > 0
),

tentativas AS (
    SELECT
        cr.*,
        gs.n AS tentativa_numero
    FROM contratos_em_risco cr
    CROSS JOIN generate_series(1, 5) AS gs(n)
    WHERE random() < CASE
        WHEN cr.flg_npl_90 = 1 THEN 0.90
        WHEN COALESCE(cr.dias_atraso_atual, 0) >= 60 THEN 0.78
        WHEN COALESCE(cr.dias_atraso_atual, 0) >= 30 THEN 0.60
        ELSE 0.42
    END
),

calc AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY num_pes, ctr_numero, tentativa_numero) AS acionamento_id,
        num_pes,
        ctr_numero,
        lc_cod,
        produto,
        subproduto,
        canal,
        origem,
        nome,
        segmento,
        rating_cliente,
        score_credito,
        valor_contratado,
        saldo_devedor,
        parcela,
        status_contrato,
        dias_atraso_atual,
        bucket_atraso,
        qtd_parcelas_em_atraso,
        valor_parcelas_em_atraso,
        maior_atraso_parcela,
        flg_inadimplente,
        flg_npl_90,
        flg_cliente_ativo,
        tentativa_numero,

        (
            DATE '2026-01-01'
            + ((random() * 364)::INTEGER)
        )::DATE AS data_acionamento,

        CASE
            WHEN COALESCE(dias_atraso_atual, 0) >= 90 OR flg_npl_90 = 1 THEN 'COBRANCA_NPL'
            WHEN COALESCE(dias_atraso_atual, 0) >= 60 THEN 'COBRANCA_61_90'
            WHEN COALESCE(dias_atraso_atual, 0) >= 31 THEN 'COBRANCA_31_60'
            WHEN COALESCE(dias_atraso_atual, 0) >= 1 THEN 'COBRANCA_1_30'
            ELSE 'PREVENTIVA'
        END AS carteira_cobranca,

        CASE
            WHEN random() < 0.34 THEN 'WHATSAPP'
            WHEN random() < 0.58 THEN 'SMS'
            WHEN random() < 0.78 THEN 'CALL_CENTER'
            WHEN random() < 0.90 THEN 'EMAIL'
            ELSE 'APP_PUSH'
        END AS canal_acionamento,

        CASE
            WHEN random() < 0.40 THEN 'COBRANCA_AMIGAVEL'
            WHEN random() < 0.66 THEN 'LEMBRETE_PAGAMENTO'
            WHEN random() < 0.84 THEN 'NEGOCIACAO'
            ELSE 'COBRANCA_INTENSIVA'
        END AS tipo_acionamento,

        random() AS fator_resultado
    FROM tentativas
)

SELECT
    acionamento_id,
    num_pes,
    ctr_numero,
    lc_cod,
    produto,
    subproduto,
    canal,
    origem,
    nome,
    segmento,
    rating_cliente,
    score_credito,
    valor_contratado,
    saldo_devedor,
    parcela,
    status_contrato,
    dias_atraso_atual,
    bucket_atraso,
    qtd_parcelas_em_atraso,
    valor_parcelas_em_atraso,
    maior_atraso_parcela,
    flg_inadimplente,
    flg_npl_90,
    flg_cliente_ativo,
    tentativa_numero,
    data_acionamento,
    TO_CHAR(data_acionamento, 'YYYY-MM') AS safra_acionamento,
    carteira_cobranca,
    canal_acionamento,
    tipo_acionamento,

    CASE
        WHEN fator_resultado < 0.74 THEN 'REALIZADO'
        WHEN fator_resultado < 0.88 THEN 'SEM_CONTATO'
        WHEN fator_resultado < 0.96 THEN 'FALHA_CANAL'
        ELSE 'CANCELADO'
    END AS status_acionamento,

    CASE
        WHEN fator_resultado < 0.18 THEN 'PROMESSA_PAGAMENTO'
        WHEN fator_resultado < 0.31 THEN 'ACORDO_NEGOCIADO'
        WHEN fator_resultado < 0.48 THEN 'CLIENTE_SEM_INTERESSE'
        WHEN fator_resultado < 0.64 THEN 'SEM_RESPOSTA'
        WHEN fator_resultado < 0.78 THEN 'CONTATO_INVALIDO'
        WHEN fator_resultado < 0.90 THEN 'RETORNAR_DEPOIS'
        ELSE 'FALHA_OPERACIONAL'
    END AS resultado_acionamento,

    CASE
        WHEN fator_resultado < 0.31 THEN 1
        ELSE 0
    END AS flg_gerou_negociacao,

    CURRENT_TIMESTAMP AS dt_processamento
FROM calc;

-- ============================================================
-- 2. Acordos de cobrança
-- ============================================================

CREATE TABLE silver.acordos_cobranca AS
WITH base_acordo AS (
    SELECT
        ac.*,
        ROW_NUMBER() OVER (
            PARTITION BY ac.ctr_numero
            ORDER BY ac.data_acionamento, ac.acionamento_id
        ) AS rn_contrato_acordo
    FROM silver.acionamentos_cobranca ac
    WHERE ac.resultado_acionamento IN ('PROMESSA_PAGAMENTO', 'ACORDO_NEGOCIADO')
      AND random() < 0.72
),

calc AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY acionamento_id) AS acordo_id,
        acionamento_id,
        num_pes,
        ctr_numero,
        lc_cod,
        produto,
        subproduto,
        carteira_cobranca,
        canal_acionamento,
        data_acionamento,
        (data_acionamento + ((random() * 5)::INTEGER))::DATE AS data_acordo,

        ROUND(
            GREATEST(
                100,
                COALESCE(saldo_devedor, valor_parcelas_em_atraso, valor_contratado) * (0.25 + random() * 0.75)
            )::NUMERIC,
            2
        ) AS valor_acordo,

        CASE
            WHEN COALESCE(dias_atraso_atual, 0) >= 90 THEN 1 + (random() * 11)::INTEGER
            WHEN COALESCE(dias_atraso_atual, 0) >= 30 THEN 1 + (random() * 7)::INTEGER
            ELSE 1 + (random() * 4)::INTEGER
        END AS qtd_parcelas_acordo,

        random() AS fator_status
    FROM base_acordo
    WHERE rn_contrato_acordo = 1
)

SELECT
    acordo_id,
    acionamento_id,
    num_pes,
    ctr_numero,
    lc_cod,
    produto,
    subproduto,
    carteira_cobranca,
    canal_acionamento,
    data_acionamento,
    data_acordo,
    TO_CHAR(data_acordo, 'YYYY-MM') AS safra_acordo,
    valor_acordo,
    qtd_parcelas_acordo,
    ROUND((valor_acordo / NULLIF(qtd_parcelas_acordo, 0))::NUMERIC, 2) AS valor_parcela_acordo,
    (data_acordo + INTERVAL '7 days')::DATE AS data_vencimento_primeira,

    CASE
        WHEN fator_status < 0.42 THEN 'CUMPRIDO'
        WHEN fator_status < 0.70 THEN 'EM_ABERTO'
        WHEN fator_status < 0.92 THEN 'QUEBRADO'
        ELSE 'CANCELADO'
    END AS status_acordo,

    CASE
        WHEN fator_status < 0.70 THEN 1
        ELSE 0
    END AS flg_acordo_ativo,

    CURRENT_TIMESTAMP AS dt_processamento
FROM calc;

-- ============================================================
-- 3. Pagamentos de acordo
-- ============================================================

CREATE TABLE silver.pagamentos_acordo AS
WITH parcelas_acordo AS (
    SELECT
        a.*,
        gs.n AS numero_parcela_acordo,
        (a.data_vencimento_primeira + ((gs.n - 1) * INTERVAL '1 month'))::DATE AS data_vencimento_parcela
    FROM silver.acordos_cobranca a
    CROSS JOIN LATERAL generate_series(1, a.qtd_parcelas_acordo) AS gs(n)
),

pagaveis AS (
    SELECT
        *,
        CASE
            WHEN status_acordo = 'CUMPRIDO' THEN 1
            WHEN status_acordo = 'EM_ABERTO' AND numero_parcela_acordo <= GREATEST(1, FLOOR(qtd_parcelas_acordo * 0.45)) THEN 1
            WHEN status_acordo = 'QUEBRADO' AND numero_parcela_acordo = 1 AND random() < 0.65 THEN 1
            ELSE 0
        END AS flg_deve_gerar_pagamento
    FROM parcelas_acordo
)

SELECT
    ROW_NUMBER() OVER (ORDER BY acordo_id, numero_parcela_acordo) AS pagamento_acordo_id,
    acordo_id,
    acionamento_id,
    num_pes,
    ctr_numero,
    numero_parcela_acordo,
    data_vencimento_parcela,
    CASE
        WHEN flg_deve_gerar_pagamento = 1
            THEN (data_vencimento_parcela + ((random() * 12)::INTEGER))::DATE
        ELSE NULL
    END AS data_pagamento,
    ROUND(
        CASE
            WHEN flg_deve_gerar_pagamento = 1
                THEN valor_parcela_acordo * (0.95 + random() * 0.10)
            ELSE 0
        END::NUMERIC,
        2
    ) AS valor_pagamento,
    CASE
        WHEN flg_deve_gerar_pagamento = 1 AND random() < 0.86 THEN 'EFETIVADO'
        WHEN flg_deve_gerar_pagamento = 1 THEN 'PENDENTE'
        ELSE 'NAO_PAGO'
    END AS status_pagamento,
    CASE
        WHEN random() < 0.45 THEN 'PIX'
        WHEN random() < 0.72 THEN 'DEBITO_CONTA'
        WHEN random() < 0.90 THEN 'BOLETO'
        ELSE 'AGENCIA'
    END AS canal_pagamento,
    CURRENT_TIMESTAMP AS dt_processamento
FROM pagaveis
WHERE flg_deve_gerar_pagamento = 1;

-- ============================================================
-- 4. SDX — Cobrança por cliente
-- ============================================================

CREATE TABLE sdx.cobranca_cliente AS
WITH acionamentos AS (
    SELECT
        num_pes,
        COUNT(*) AS qtd_acionamentos_cobranca,
        COUNT(DISTINCT ctr_numero) AS qtd_contratos_acionados,
        SUM(CASE WHEN status_acionamento = 'REALIZADO' THEN 1 ELSE 0 END) AS qtd_acionamentos_realizados,
        SUM(CASE WHEN status_acionamento = 'SEM_CONTATO' THEN 1 ELSE 0 END) AS qtd_sem_contato,
        SUM(flg_gerou_negociacao) AS qtd_negociacoes_geradas,
        MAX(data_acionamento) AS data_ultimo_acionamento,
        MAX(dias_atraso_atual) AS maior_atraso_cobranca,
        SUM(COALESCE(valor_parcelas_em_atraso, 0)) AS valor_total_em_atraso_acionado
    FROM silver.acionamentos_cobranca
    GROUP BY num_pes
),

acordos AS (
    SELECT
        num_pes,
        COUNT(*) AS qtd_acordos,
        SUM(CASE WHEN status_acordo = 'CUMPRIDO' THEN 1 ELSE 0 END) AS qtd_acordos_cumpridos,
        SUM(CASE WHEN status_acordo = 'QUEBRADO' THEN 1 ELSE 0 END) AS qtd_acordos_quebrados,
        SUM(CASE WHEN status_acordo = 'EM_ABERTO' THEN 1 ELSE 0 END) AS qtd_acordos_em_aberto,
        ROUND(SUM(valor_acordo)::NUMERIC, 2) AS valor_total_acordado,
        MAX(data_acordo) AS data_ultimo_acordo
    FROM silver.acordos_cobranca
    GROUP BY num_pes
),

pagamentos AS (
    SELECT
        num_pes,
        COUNT(*) AS qtd_pagamentos_acordo,
        ROUND(SUM(CASE WHEN status_pagamento = 'EFETIVADO' THEN valor_pagamento ELSE 0 END)::NUMERIC, 2) AS valor_recuperado,
        MAX(data_pagamento) AS data_ultimo_pagamento_acordo
    FROM silver.pagamentos_acordo
    GROUP BY num_pes
)

SELECT
    COALESCE(ac.num_pes, ag.num_pes, pg.num_pes) AS num_pes,
    COALESCE(ac.qtd_acionamentos_cobranca, 0) AS qtd_acionamentos_cobranca,
    COALESCE(ac.qtd_contratos_acionados, 0) AS qtd_contratos_acionados,
    COALESCE(ac.qtd_acionamentos_realizados, 0) AS qtd_acionamentos_realizados,
    COALESCE(ac.qtd_sem_contato, 0) AS qtd_sem_contato,
    COALESCE(ac.qtd_negociacoes_geradas, 0) AS qtd_negociacoes_geradas,
    ac.data_ultimo_acionamento,
    COALESCE(ac.maior_atraso_cobranca, 0) AS maior_atraso_cobranca,
    ROUND(COALESCE(ac.valor_total_em_atraso_acionado, 0)::NUMERIC, 2) AS valor_total_em_atraso_acionado,
    COALESCE(ag.qtd_acordos, 0) AS qtd_acordos,
    COALESCE(ag.qtd_acordos_cumpridos, 0) AS qtd_acordos_cumpridos,
    COALESCE(ag.qtd_acordos_quebrados, 0) AS qtd_acordos_quebrados,
    COALESCE(ag.qtd_acordos_em_aberto, 0) AS qtd_acordos_em_aberto,
    COALESCE(ag.valor_total_acordado, 0) AS valor_total_acordado,
    ag.data_ultimo_acordo,
    COALESCE(pg.qtd_pagamentos_acordo, 0) AS qtd_pagamentos_acordo,
    COALESCE(pg.valor_recuperado, 0) AS valor_recuperado,
    pg.data_ultimo_pagamento_acordo,

    CASE
        WHEN COALESCE(ag.qtd_acordos_quebrados, 0) > 0 THEN 'ACORDO_QUEBRADO'
        WHEN COALESCE(pg.valor_recuperado, 0) > 0 THEN 'RECUPERADO'
        WHEN COALESCE(ag.qtd_acordos_em_aberto, 0) > 0 THEN 'ACORDO_EM_ABERTO'
        WHEN COALESCE(ac.qtd_sem_contato, 0) >= 3 THEN 'DIFICIL_CONTATO'
        WHEN COALESCE(ac.qtd_acionamentos_cobranca, 0) > 0 THEN 'EM_COBRANCA'
        ELSE 'SEM_COBRANCA'
    END AS cluster_cobranca

FROM acionamentos ac
FULL OUTER JOIN acordos ag
    ON ac.num_pes = ag.num_pes
FULL OUTER JOIN pagamentos pg
    ON COALESCE(ac.num_pes, ag.num_pes) = pg.num_pes;

-- ============================================================
-- 5. Cliente 360 V7
-- ============================================================

CREATE TABLE sdx.cliente_360_v7 AS
SELECT
    c360.*,
    COALESCE(cb.qtd_acionamentos_cobranca, 0) AS qtd_acionamentos_cobranca,
    COALESCE(cb.qtd_contratos_acionados, 0) AS qtd_contratos_acionados,
    COALESCE(cb.qtd_acionamentos_realizados, 0) AS qtd_acionamentos_realizados,
    COALESCE(cb.qtd_sem_contato, 0) AS qtd_sem_contato_cobranca,
    COALESCE(cb.qtd_negociacoes_geradas, 0) AS qtd_negociacoes_geradas,
    cb.data_ultimo_acionamento,
    COALESCE(cb.maior_atraso_cobranca, 0) AS maior_atraso_cobranca,
    COALESCE(cb.valor_total_em_atraso_acionado, 0) AS valor_total_em_atraso_acionado,
    COALESCE(cb.qtd_acordos, 0) AS qtd_acordos_cobranca,
    COALESCE(cb.qtd_acordos_cumpridos, 0) AS qtd_acordos_cumpridos,
    COALESCE(cb.qtd_acordos_quebrados, 0) AS qtd_acordos_quebrados,
    COALESCE(cb.valor_total_acordado, 0) AS valor_total_acordado,
    COALESCE(cb.valor_recuperado, 0) AS valor_recuperado_cobranca,
    COALESCE(cb.cluster_cobranca, 'SEM_COBRANCA') AS cluster_cobranca,
    CASE
        WHEN COALESCE(cb.qtd_acordos_quebrados, 0) > 0 THEN TRUE
        WHEN COALESCE(cb.maior_atraso_cobranca, 0) >= 90 THEN TRUE
        WHEN COALESCE(cb.qtd_sem_contato, 0) >= 3 THEN TRUE
        ELSE FALSE
    END AS flag_risco_cobranca
FROM sdx.cliente_360_v6 c360
LEFT JOIN sdx.cobranca_cliente cb
    ON c360.cliente_id = cb.num_pes;

-- ============================================================
-- 6. Gold — KPI cobrança mensal
-- ============================================================

CREATE TABLE gold.kpi_cobranca_mensal AS
SELECT
    safra_acionamento,
    carteira_cobranca,
    canal_acionamento,
    tipo_acionamento,
    COUNT(*) AS qtd_acionamentos,
    COUNT(DISTINCT num_pes) AS qtd_clientes_acionados,
    COUNT(DISTINCT ctr_numero) AS qtd_contratos_acionados,
    SUM(CASE WHEN status_acionamento = 'REALIZADO' THEN 1 ELSE 0 END) AS qtd_realizados,
    SUM(CASE WHEN status_acionamento = 'SEM_CONTATO' THEN 1 ELSE 0 END) AS qtd_sem_contato,
    SUM(CASE WHEN resultado_acionamento IN ('PROMESSA_PAGAMENTO', 'ACORDO_NEGOCIADO') THEN 1 ELSE 0 END) AS qtd_promessas_negociacoes,
    ROUND(SUM(COALESCE(valor_parcelas_em_atraso, 0))::NUMERIC, 2) AS valor_em_atraso_acionado,
    ROUND(
        SUM(CASE WHEN resultado_acionamento IN ('PROMESSA_PAGAMENTO', 'ACORDO_NEGOCIADO') THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0),
        4
    ) AS taxa_sucesso_acionamento
FROM silver.acionamentos_cobranca
GROUP BY
    safra_acionamento,
    carteira_cobranca,
    canal_acionamento,
    tipo_acionamento;

-- ============================================================
-- 7. Gold — DW Cobrança
-- ============================================================

CREATE TABLE gold.dw_cobranca AS
WITH acordo_por_acionamento AS (
    SELECT
        a.acionamento_id,
        MAX(a.acordo_id) AS acordo_id,
        MAX(a.data_acordo) AS data_acordo,
        MAX(a.safra_acordo) AS safra_acordo,
        SUM(a.valor_acordo) AS valor_acordo,
        MAX(a.qtd_parcelas_acordo) AS qtd_parcelas_acordo,
        MAX(a.status_acordo) AS status_acordo
    FROM silver.acordos_cobranca a
    GROUP BY a.acionamento_id
),

pagamento_por_acordo AS (
    SELECT
        acordo_id,
        COUNT(*) AS qtd_pagamentos_acordo,
        SUM(CASE WHEN status_pagamento = 'EFETIVADO' THEN valor_pagamento ELSE 0 END) AS valor_recuperado,
        MAX(data_pagamento) AS data_ultimo_pagamento
    FROM silver.pagamentos_acordo
    GROUP BY acordo_id
)

SELECT
    ac.acionamento_id,
    ac.num_pes,
    ac.ctr_numero,
    ac.lc_cod,
    ac.produto,
    ac.subproduto,
    ac.canal,
    ac.origem,
    ac.nome,
    ac.segmento,
    ac.rating_cliente,
    ac.score_credito,
    ac.valor_contratado,
    ac.saldo_devedor,
    ac.valor_parcelas_em_atraso,
    ac.parcela,
    ac.status_contrato,
    ac.dias_atraso_atual,
    ac.bucket_atraso,
    ac.qtd_parcelas_em_atraso,
    ac.maior_atraso_parcela,
    ac.flg_inadimplente,
    ac.flg_npl_90,
    ac.flg_cliente_ativo,

    ac.tentativa_numero,
    ac.data_acionamento,
    ac.safra_acionamento,
    ac.carteira_cobranca,
    ac.canal_acionamento,
    ac.tipo_acionamento,
    ac.status_acionamento,
    ac.resultado_acionamento,
    ac.flg_gerou_negociacao,

    ag.acordo_id,
    ag.data_acordo,
    ag.safra_acordo,
    COALESCE(ag.valor_acordo, 0) AS valor_acordo,
    COALESCE(ag.qtd_parcelas_acordo, 0) AS qtd_parcelas_acordo,
    COALESCE(ag.status_acordo, 'SEM_ACORDO') AS status_acordo,

    COALESCE(pg.qtd_pagamentos_acordo, 0) AS qtd_pagamentos_acordo,
    ROUND(COALESCE(pg.valor_recuperado, 0)::NUMERIC, 2) AS valor_recuperado,
    pg.data_ultimo_pagamento,

    CASE WHEN ag.acordo_id IS NOT NULL THEN 1 ELSE 0 END AS flg_gerou_acordo,
    CASE WHEN COALESCE(pg.valor_recuperado, 0) > 0 THEN 1 ELSE 0 END AS flg_recuperou_valor,
    CASE WHEN ag.status_acordo = 'QUEBRADO' THEN 1 ELSE 0 END AS flg_acordo_quebrado,
    CASE WHEN ag.status_acordo = 'CUMPRIDO' THEN 1 ELSE 0 END AS flg_acordo_cumprido,

    CURRENT_TIMESTAMP AS dt_processamento_dw

FROM silver.acionamentos_cobranca ac
LEFT JOIN acordo_por_acionamento ag
    ON ac.acionamento_id = ag.acionamento_id
LEFT JOIN pagamento_por_acordo pg
    ON ag.acordo_id = pg.acordo_id;

-- ============================================================
-- 8. Índices
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_dw_cobranca_num_pes
    ON gold.dw_cobranca (num_pes);

CREATE INDEX IF NOT EXISTS idx_dw_cobranca_ctr_numero
    ON gold.dw_cobranca (ctr_numero);

CREATE INDEX IF NOT EXISTS idx_dw_cobranca_safra
    ON gold.dw_cobranca (safra_acionamento);

CREATE INDEX IF NOT EXISTS idx_dw_cobranca_flags
    ON gold.dw_cobranca (flg_gerou_acordo, flg_recuperou_valor, flg_acordo_quebrado);

ANALYZE silver.acionamentos_cobranca;
ANALYZE silver.acordos_cobranca;
ANALYZE silver.pagamentos_acordo;
ANALYZE sdx.cobranca_cliente;
ANALYZE sdx.cliente_360_v7;
ANALYZE gold.kpi_cobranca_mensal;
ANALYZE gold.dw_cobranca;

-- ============================================================
-- 9. Quality checks
-- ============================================================

CREATE TABLE meta.quality_cobranca AS
SELECT 'acionamentos_cobranca' AS check_name, COUNT(*) AS qtd
FROM silver.acionamentos_cobranca

UNION ALL

SELECT 'acordos_cobranca', COUNT(*)
FROM silver.acordos_cobranca

UNION ALL

SELECT 'pagamentos_acordo', COUNT(*)
FROM silver.pagamentos_acordo

UNION ALL

SELECT 'clientes_acionados', COUNT(DISTINCT num_pes)
FROM silver.acionamentos_cobranca

UNION ALL

SELECT 'contratos_acionados', COUNT(DISTINCT ctr_numero)
FROM silver.acionamentos_cobranca

UNION ALL

SELECT 'acionamentos_realizados', COUNT(*)
FROM silver.acionamentos_cobranca
WHERE status_acionamento = 'REALIZADO'

UNION ALL

SELECT 'acionamentos_sem_contato', COUNT(*)
FROM silver.acionamentos_cobranca
WHERE status_acionamento = 'SEM_CONTATO'

UNION ALL

SELECT 'acordos_cumpridos', COUNT(*)
FROM silver.acordos_cobranca
WHERE status_acordo = 'CUMPRIDO'

UNION ALL

SELECT 'acordos_quebrados', COUNT(*)
FROM silver.acordos_cobranca
WHERE status_acordo = 'QUEBRADO'

UNION ALL

SELECT 'clientes_com_valor_recuperado', COUNT(DISTINCT num_pes)
FROM sdx.cobranca_cliente
WHERE valor_recuperado > 0

UNION ALL

SELECT 'dw_cobranca_linhas', COUNT(*)
FROM gold.dw_cobranca

UNION ALL

SELECT 'cliente_360_v7_linhas', COUNT(*)
FROM sdx.cliente_360_v7;

-- ============================================================
-- 10. Comentários
-- ============================================================

COMMENT ON TABLE gold.dw_cobranca IS
'Tabela flat de cobrança do Aurora Bank, simulando DW corporativa para análise de acionamentos, acordos, recuperação, quebra de acordo e eficiência de cobrança.';

COMMENT ON COLUMN gold.dw_cobranca.num_pes IS
'Identificador da pessoa/cliente no padrão de DW bancária.';

COMMENT ON COLUMN gold.dw_cobranca.ctr_numero IS
'Número do contrato acionado em cobrança.';

COMMENT ON COLUMN gold.dw_cobranca.flg_recuperou_valor IS
'Flag 1/0 que indica se houve recuperação financeira associada ao acordo.';
