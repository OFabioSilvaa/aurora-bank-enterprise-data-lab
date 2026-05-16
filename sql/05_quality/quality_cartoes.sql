-- Quality checks de cartões

SELECT *
FROM meta.quality_cartoes
ORDER BY check_name;

-- Cartões com problemas
SELECT
    cartao_id,
    cliente_id,
    produto_cartao,
    limite_concedido_original,
    limite_concedido_tratado,
    status_cartao,
    flag_cliente_orfao,
    flag_limite_nulo,
    flag_limite_outlier
FROM silver.cartoes
WHERE flag_cliente_orfao = TRUE
   OR flag_limite_nulo = TRUE
   OR flag_limite_outlier = TRUE
LIMIT 100;

-- Faturas com problema
SELECT
    fatura_id,
    cartao_id,
    cliente_id,
    ano_mes,
    valor_fatura_original,
    valor_fatura_tratado,
    valor_pago,
    dias_atraso_fatura,
    status_fatura,
    flag_cartao_orfao,
    flag_pagamento_maior_que_fatura
FROM silver.faturas_cartao
WHERE flag_cartao_orfao = TRUE
   OR flag_valor_fatura_nulo = TRUE
   OR flag_pagamento_maior_que_fatura = TRUE
LIMIT 100;
