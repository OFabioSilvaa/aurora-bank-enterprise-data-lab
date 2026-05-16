-- Quality checks de contas e transações

SELECT *
FROM meta.quality_contas_transacoes
ORDER BY check_name;

-- Contas órfãs
SELECT *
FROM silver.contas
WHERE flag_cliente_orfao = TRUE
LIMIT 100;

-- Transações com problema
SELECT
    transacao_id,
    conta_id,
    cliente_id,
    data_transacao,
    tipo_transacao,
    valor_original,
    valor_tratado,
    status_transacao,
    flag_conta_orfa,
    flag_cliente_orfao,
    flag_valor_nulo,
    flag_valor_negativo,
    flag_data_futura
FROM silver.transacoes
WHERE flag_conta_orfa = TRUE
   OR flag_cliente_orfao = TRUE
   OR flag_valor_nulo = TRUE
   OR flag_valor_negativo = TRUE
   OR flag_data_futura = TRUE
LIMIT 100;
