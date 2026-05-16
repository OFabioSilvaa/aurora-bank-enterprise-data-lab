-- Quality checks de crédito

SELECT *
FROM meta.quality_credito
ORDER BY check_name;

-- Propostas com problema
SELECT
    proposta_id,
    cliente_id,
    produto_credito,
    data_proposta,
    valor_solicitado,
    score_motor,
    status_proposta,
    flag_cliente_orfao,
    flag_score_motor_nulo,
    flag_data_futura
FROM silver.propostas_credito
WHERE flag_cliente_orfao = TRUE
   OR flag_score_motor_nulo = TRUE
   OR flag_data_futura = TRUE
LIMIT 100;

-- Contratos com problema
SELECT
    contrato_id,
    proposta_id,
    cliente_id,
    produto_credito,
    data_proposta,
    data_contratacao,
    saldo_devedor_original,
    saldo_devedor_tratado,
    flag_proposta_orfa,
    flag_saldo_negativo,
    flag_data_contratacao_inconsistente
FROM silver.contratos_credito
WHERE flag_proposta_orfa = TRUE
   OR flag_saldo_negativo = TRUE
   OR flag_data_contratacao_inconsistente = TRUE
LIMIT 100;

-- Parcelas órfãs
SELECT *
FROM silver.parcelas_credito
WHERE flag_contrato_orfao = TRUE
LIMIT 100;
