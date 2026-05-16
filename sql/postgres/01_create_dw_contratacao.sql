-- ============================================================
-- Aurora Bank Enterprise Data Lab
-- Patch 06 — Criação da tabela gold.dw_contratacao
-- Banco destino: PostgreSQL
-- ============================================================
--
-- Objetivo:
-- Criar uma tabela flat de contratação, parecida com uma tabela
-- corporativa usada por analistas de dados em banco.
--
-- Essa tabela consolida:
-- - cliente
-- - proposta
-- - contrato
-- - produto / subproduto / origem
-- - flags de negócio
-- - risco e inadimplência
-- - elegibilidade de renovação
--
-- Execute no PostgreSQL conectado ao banco:
-- aurora_bank
--
-- ============================================================

CREATE SCHEMA IF NOT EXISTS gold;
CREATE SCHEMA IF NOT EXISTS meta;

DROP TABLE IF EXISTS gold.dw_contratacao;

CREATE TABLE gold.dw_contratacao AS
WITH base_contrato AS (
    SELECT
        ct.contrato_id,
        ct.proposta_id,
        ct.cliente_id,

        ct.produto_credito,
        ct.canal_contratacao,

        ct.data_proposta,
        ct.data_contratacao,
        ct.safra_contratacao,
        ct.data_liberacao_credito,
        ct.data_primeiro_vencimento,

        ct.valor_contratado,
        ct.valor_liberado,
        ct.saldo_devedor_tratado,
        ct.saldo_devedor_original,
        ct.taxa_mensal,
        ct.prazo_meses,
        ct.parcela,

        ct.status_contrato,
        ct.dias_atraso_atual,
        ct.bucket_atraso,

        ct.flag_cliente_orfao,
        ct.flag_proposta_orfa,
        ct.flag_saldo_negativo,
        ct.flag_data_contratacao_inconsistente

    FROM silver.contratos_credito ct
),

base_proposta AS (
    SELECT
        p.proposta_id,
        p.cliente_id,
        p.canal_proposta,
        p.status_proposta,
        p.motivo_recusa,
        p.valor_solicitado,
        p.taxa_ofertada,
        p.parcela_estimada,
        p.renda_mensal_informada,
        p.comprometimento_renda_estimado,
        p.score_motor,
        p.rating_motor,
        p.flag_score_motor_nulo,
        p.flag_data_futura AS flag_proposta_data_futura,
        p.flag_valor_invalido AS flag_proposta_valor_invalido
    FROM silver.propostas_credito p
),

base_cliente AS (
    SELECT
        c.cliente_id,
        c.cpf_hash,
        c.nome,
        c.idade_atual,
        c.faixa_etaria,
        c.genero,
        c.estado_civil,
        c.cidade,
        c.uf,
        c.regiao,
        c.renda_mensal_tratada,
        c.renda_mensal_original,
        c.faixa_renda,
        c.profissao,
        c.tipo_ocupacao,
        c.escolaridade,
        c.score_credito,
        c.rating_cliente,
        c.segmento,
        c.canal_aquisicao,
        c.data_cadastro,
        c.data_inicio_relacionamento,
        c.status_cliente_core,
        c.status_app,
        c.flag_cliente_ativo,
        c.dias_desde_cadastro,
        c.dias_relacionamento,
        c.dias_desde_ultimo_login,
        c.flag_renda_nula,
        c.flag_score_ausente,
        c.flag_data_nascimento_ausente,
        c.flag_uf_ausente
    FROM silver.clientes c
),

contratos_anteriores AS (
    SELECT
        ct.cliente_id,
        ct.contrato_id,
        COUNT(*) OVER (
            PARTITION BY ct.cliente_id
            ORDER BY ct.data_contratacao, ct.contrato_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS qtd_contratos_anteriores_cliente
    FROM silver.contratos_credito ct
),

parcelas_resumo AS (
    SELECT
        p.contrato_id,
        COUNT(*) AS qtd_parcelas,
        SUM(CASE WHEN p.status_parcela IN ('PAGA', 'PAGA_EM_ATRASO') THEN 1 ELSE 0 END) AS qtd_parcelas_pagas,
        SUM(CASE WHEN p.status_parcela = 'EM_ATRASO' THEN 1 ELSE 0 END) AS qtd_parcelas_em_atraso,
        MAX(COALESCE(p.dias_atraso, 0)) AS maior_atraso_parcela,
        SUM(CASE WHEN COALESCE(p.dias_atraso, 0) > 0 THEN 1 ELSE 0 END) AS qtd_parcelas_com_atraso,
        SUM(CASE WHEN p.status_parcela = 'EM_ATRASO' THEN COALESCE(p.valor_parcela, 0) ELSE 0 END) AS valor_parcelas_em_atraso,
        SUM(COALESCE(p.valor_parcela, 0)) AS valor_total_parcelas,
        SUM(COALESCE(p.valor_pago, 0)) AS valor_total_pago_parcelas
    FROM silver.parcelas_credito p
    WHERE p.flag_contrato_orfao = FALSE
    GROUP BY p.contrato_id
)

SELECT
    -- ========================================================
    -- Identificadores no padrão "DW bancária"
    -- ========================================================
    bc.cliente_id AS num_pes,
    bc.contrato_id AS ctr_numero,
    bc.proposta_id,
    cli.cpf_hash,

    -- ========================================================
    -- Produto / subproduto / códigos
    -- ========================================================
    CASE
        WHEN bc.produto_credito = 'EMPRESTIMO_PESSOAL' THEN 101
        WHEN bc.produto_credito = 'CONSIGNADO_PRIVADO' THEN 201
        WHEN bc.produto_credito = 'CONSIGNADO_PUBLICO' THEN 202
        WHEN bc.produto_credito = 'CONSIGNADO_INSS' THEN 203
        WHEN bc.produto_credito = 'REFINANCIAMENTO' THEN 301
        WHEN bc.produto_credito = 'ANTECIPACAO_FGTS' THEN 401
        ELSE 999
    END AS lc_cod,

    bc.produto_credito AS produto,

    CASE
        WHEN bc.produto_credito IN ('CONSIGNADO_PRIVADO', 'CONSIGNADO_PUBLICO', 'CONSIGNADO_INSS') THEN 'CONSIGNADO'
        WHEN bc.produto_credito = 'REFINANCIAMENTO' THEN 'RENOVACAO_REFIN'
        WHEN bc.produto_credito = 'ANTECIPACAO_FGTS' THEN 'FGTS'
        WHEN bc.produto_credito = 'EMPRESTIMO_PESSOAL' THEN 'CREDITO_PESSOAL'
        ELSE 'OUTROS'
    END AS subproduto,

    CASE
        WHEN bc.produto_credito IN ('CONSIGNADO_PRIVADO', 'CONSIGNADO_PUBLICO', 'CONSIGNADO_INSS') THEN 1
        ELSE 0
    END AS flg_produto_consignado,

    CASE
        WHEN bc.produto_credito = 'REFINANCIAMENTO' THEN 1
        ELSE 0
    END AS flg_produto_refinanciamento,

    CASE
        WHEN bc.produto_credito = 'ANTECIPACAO_FGTS' THEN 1
        ELSE 0
    END AS flg_produto_fgts,

    -- ========================================================
    -- Canal / origem
    -- ========================================================
    bc.canal_contratacao AS canal,

    CASE
        WHEN bc.canal_contratacao IN ('APP', 'SITE') THEN 'DIGITAL'
        WHEN bc.canal_contratacao IN ('CORRESPONDENTE', 'AGENCIA') THEN 'PARCEIRO_FISICO'
        WHEN bc.canal_contratacao IN ('WHATSAPP', 'CALL_CENTER') THEN 'ATENDIMENTO'
        WHEN bc.canal_contratacao = 'OPEN_FINANCE' THEN 'OPEN_FINANCE'
        ELSE 'OUTROS'
    END AS origem,

    prop.canal_proposta,

    -- ========================================================
    -- Datas / safra
    -- ========================================================
    prop.status_proposta,
    prop.motivo_recusa,
    bc.data_proposta,
    bc.data_contratacao,
    bc.safra_contratacao,
    bc.data_liberacao_credito,
    bc.data_primeiro_vencimento,

    EXTRACT(YEAR FROM bc.data_contratacao)::INTEGER AS ano_contratacao,
    EXTRACT(MONTH FROM bc.data_contratacao)::INTEGER AS mes_contratacao,

    CASE
        WHEN bc.data_contratacao IS NOT NULL AND bc.data_proposta IS NOT NULL
        THEN bc.data_contratacao - bc.data_proposta
        ELSE NULL
    END AS dias_entre_proposta_contratacao,

    CASE
        WHEN bc.data_liberacao_credito IS NOT NULL AND bc.data_contratacao IS NOT NULL
        THEN bc.data_liberacao_credito - bc.data_contratacao
        ELSE NULL
    END AS dias_entre_contratacao_liberacao,

    -- ========================================================
    -- Valores / taxa / prazo
    -- ========================================================
    prop.valor_solicitado,
    bc.valor_contratado,
    bc.valor_liberado,
    bc.saldo_devedor_tratado AS saldo_devedor,
    bc.saldo_devedor_original,
    bc.taxa_mensal,
    bc.prazo_meses,
    bc.parcela,
    prop.parcela_estimada,
    prop.comprometimento_renda_estimado,

    -- ========================================================
    -- Status e risco do contrato
    -- ========================================================
    bc.status_contrato,
    bc.dias_atraso_atual,
    bc.bucket_atraso,

    COALESCE(pr.qtd_parcelas, 0) AS qtd_parcelas,
    COALESCE(pr.qtd_parcelas_pagas, 0) AS qtd_parcelas_pagas,
    COALESCE(pr.qtd_parcelas_em_atraso, 0) AS qtd_parcelas_em_atraso,
    COALESCE(pr.qtd_parcelas_com_atraso, 0) AS qtd_parcelas_com_atraso,
    COALESCE(pr.maior_atraso_parcela, 0) AS maior_atraso_parcela,
    COALESCE(pr.valor_parcelas_em_atraso, 0) AS valor_parcelas_em_atraso,
    COALESCE(pr.valor_total_parcelas, 0) AS valor_total_parcelas,
    COALESCE(pr.valor_total_pago_parcelas, 0) AS valor_total_pago_parcelas,

    -- ========================================================
    -- Dados do cliente
    -- ========================================================
    cli.nome,
    cli.idade_atual,
    cli.faixa_etaria,
    cli.genero,
    cli.estado_civil,
    cli.cidade,
    cli.uf,
    cli.regiao,
    cli.renda_mensal_tratada AS renda_mensal,
    cli.renda_mensal_original,
    cli.faixa_renda,
    cli.profissao,
    cli.tipo_ocupacao,
    cli.escolaridade,
    cli.score_credito,
    cli.rating_cliente,
    prop.score_motor,
    prop.rating_motor,
    cli.segmento,
    cli.canal_aquisicao,
    cli.data_cadastro,
    cli.data_inicio_relacionamento,
    cli.status_cliente_core,
    cli.status_app,
    cli.flag_cliente_ativo,
    cli.dias_desde_cadastro,
    cli.dias_relacionamento,
    cli.dias_desde_ultimo_login,

    COALESCE(ca.qtd_contratos_anteriores_cliente, 0) AS qtd_contratos_anteriores_cliente,

    -- ========================================================
    -- Flags principais de negócio
    -- ========================================================
    CASE WHEN bc.contrato_id IS NOT NULL THEN 1 ELSE 0 END AS flg_contratado,
    CASE WHEN prop.status_proposta = 'APROVADA' THEN 1 ELSE 0 END AS flg_aprovado,

    CASE
        WHEN COALESCE(ca.qtd_contratos_anteriores_cliente, 0) > 0 THEN 1
        ELSE 0
    END AS flg_cliente_ja_possuia_contrato,

    CASE
        WHEN bc.status_contrato = 'RENEGOCIADO'
          OR bc.produto_credito = 'REFINANCIAMENTO'
          OR COALESCE(ca.qtd_contratos_anteriores_cliente, 0) > 0
        THEN 1
        ELSE 0
    END AS flg_renovacao,

    CASE
        WHEN bc.status_contrato = 'ATIVO'
         AND COALESCE(bc.dias_atraso_atual, 0) = 0
         AND COALESCE(bc.saldo_devedor_tratado, 0) > 0
         AND COALESCE(cli.score_credito, 0) >= 650
         AND cli.flag_cliente_ativo = TRUE
         AND COALESCE(prop.comprometimento_renda_estimado, 0) <= 0.35
        THEN 1
        ELSE 0
    END AS flg_apto_renovacao,

    CASE
        WHEN COALESCE(bc.dias_atraso_atual, 0) > 0
          OR COALESCE(pr.qtd_parcelas_em_atraso, 0) > 0
        THEN 1
        ELSE 0
    END AS flg_inadimplente,

    CASE
        WHEN bc.bucket_atraso = 'NPL_90_PLUS'
          OR COALESCE(bc.dias_atraso_atual, 0) > 90
          OR COALESCE(pr.maior_atraso_parcela, 0) > 90
        THEN 1
        ELSE 0
    END AS flg_npl_90,

    CASE WHEN COALESCE(cli.score_credito, 0) >= 650 THEN 1 ELSE 0 END AS flg_score_bom,
    CASE WHEN cli.renda_mensal_tratada IS NOT NULL THEN 1 ELSE 0 END AS flg_renda_informada,
    CASE WHEN cli.flag_cliente_ativo = TRUE THEN 1 ELSE 0 END AS flg_cliente_ativo,

    CASE
        WHEN bc.status_contrato = 'ATIVO'
         AND COALESCE(bc.saldo_devedor_tratado, 0) > 0
        THEN 1
        ELSE 0
    END AS flg_carteira_ativa,

    CASE
        WHEN bc.status_contrato = 'QUITADO' THEN 1
        ELSE 0
    END AS flg_quitado,

    CASE
        WHEN prop.motivo_recusa IS NOT NULL THEN 1
        ELSE 0
    END AS flg_possui_motivo_recusa,

    -- ========================================================
    -- Flags de qualidade / inconsistência
    -- ========================================================
    CASE WHEN bc.flag_cliente_orfao = TRUE THEN 1 ELSE 0 END AS flg_cliente_orfao,
    CASE WHEN bc.flag_proposta_orfa = TRUE THEN 1 ELSE 0 END AS flg_proposta_orfa,
    CASE WHEN bc.flag_saldo_negativo = TRUE THEN 1 ELSE 0 END AS flg_saldo_negativo,
    CASE WHEN bc.flag_data_contratacao_inconsistente = TRUE THEN 1 ELSE 0 END AS flg_data_contratacao_inconsistente,
    CASE WHEN prop.flag_score_motor_nulo = TRUE THEN 1 ELSE 0 END AS flg_score_motor_nulo,
    CASE WHEN prop.flag_proposta_data_futura = TRUE THEN 1 ELSE 0 END AS flg_proposta_data_futura,
    CASE WHEN prop.flag_proposta_valor_invalido = TRUE THEN 1 ELSE 0 END AS flg_proposta_valor_invalido,
    CASE WHEN cli.flag_renda_nula = TRUE THEN 1 ELSE 0 END AS flg_renda_nula,
    CASE WHEN cli.flag_score_ausente = TRUE THEN 1 ELSE 0 END AS flg_score_ausente,
    CASE WHEN cli.flag_data_nascimento_ausente = TRUE THEN 1 ELSE 0 END AS flg_data_nascimento_ausente,
    CASE WHEN cli.flag_uf_ausente = TRUE THEN 1 ELSE 0 END AS flg_uf_ausente,

    CURRENT_TIMESTAMP AS dt_processamento_dw

FROM base_contrato bc
LEFT JOIN base_proposta prop
    ON bc.proposta_id = prop.proposta_id
LEFT JOIN base_cliente cli
    ON bc.cliente_id = cli.cliente_id
LEFT JOIN contratos_anteriores ca
    ON bc.contrato_id = ca.contrato_id
LEFT JOIN parcelas_resumo pr
    ON bc.contrato_id = pr.contrato_id;

-- ============================================================
-- Índices para melhorar consulta no PostgreSQL
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_dw_contratacao_num_pes
    ON gold.dw_contratacao (num_pes);

CREATE INDEX IF NOT EXISTS idx_dw_contratacao_ctr_numero
    ON gold.dw_contratacao (ctr_numero);

CREATE INDEX IF NOT EXISTS idx_dw_contratacao_lc_cod
    ON gold.dw_contratacao (lc_cod);

CREATE INDEX IF NOT EXISTS idx_dw_contratacao_safra
    ON gold.dw_contratacao (safra_contratacao);

CREATE INDEX IF NOT EXISTS idx_dw_contratacao_produto
    ON gold.dw_contratacao (produto);

CREATE INDEX IF NOT EXISTS idx_dw_contratacao_flags
    ON gold.dw_contratacao (flg_apto_renovacao, flg_renovacao, flg_inadimplente, flg_npl_90);

ANALYZE gold.dw_contratacao;

-- ============================================================
-- Checks de qualidade da nova DW
-- ============================================================

DROP TABLE IF EXISTS meta.quality_dw_contratacao;

CREATE TABLE meta.quality_dw_contratacao AS
SELECT 'linhas_dw_contratacao' AS check_name, COUNT(*) AS qtd
FROM gold.dw_contratacao

UNION ALL

SELECT 'clientes_distintos', COUNT(DISTINCT num_pes)
FROM gold.dw_contratacao

UNION ALL

SELECT 'contratos_distintos', COUNT(DISTINCT ctr_numero)
FROM gold.dw_contratacao

UNION ALL

SELECT 'contratos_sem_cliente', COUNT(*)
FROM gold.dw_contratacao
WHERE num_pes IS NULL

UNION ALL

SELECT 'contratos_sem_produto', COUNT(*)
FROM gold.dw_contratacao
WHERE produto IS NULL

UNION ALL

SELECT 'contratos_apto_renovacao', COUNT(*)
FROM gold.dw_contratacao
WHERE flg_apto_renovacao = 1

UNION ALL

SELECT 'contratos_renovacao', COUNT(*)
FROM gold.dw_contratacao
WHERE flg_renovacao = 1

UNION ALL

SELECT 'contratos_inadimplentes', COUNT(*)
FROM gold.dw_contratacao
WHERE flg_inadimplente = 1

UNION ALL

SELECT 'contratos_npl_90', COUNT(*)
FROM gold.dw_contratacao
WHERE flg_npl_90 = 1

UNION ALL

SELECT 'contratos_com_inconsistencia_data', COUNT(*)
FROM gold.dw_contratacao
WHERE flg_data_contratacao_inconsistente = 1

UNION ALL

SELECT 'contratos_com_saldo_negativo_origem', COUNT(*)
FROM gold.dw_contratacao
WHERE flg_saldo_negativo = 1;

-- ============================================================
-- Comentários de documentação no PostgreSQL
-- ============================================================

COMMENT ON TABLE gold.dw_contratacao IS
'Tabela flat de contratação do Aurora Bank, simulando uma DW corporativa de crédito para análise de produto, canal, renovação, inadimplência e risco.';

COMMENT ON COLUMN gold.dw_contratacao.num_pes IS
'Identificador da pessoa/cliente no padrão de DW bancária. Origem: silver.clientes.cliente_id.';

COMMENT ON COLUMN gold.dw_contratacao.lc_cod IS
'Código fictício de linha/produto de crédito.';

COMMENT ON COLUMN gold.dw_contratacao.flg_apto_renovacao IS
'Flag 1/0 que indica se o contrato está elegível para renovação conforme regra simulada.';

COMMENT ON COLUMN gold.dw_contratacao.flg_renovacao IS
'Flag 1/0 que indica contrato associado a renovação, refinanciamento ou cliente com histórico anterior.';

COMMENT ON COLUMN gold.dw_contratacao.flg_npl_90 IS
'Flag 1/0 que indica atraso superior a 90 dias ou bucket NPL_90_PLUS.';
