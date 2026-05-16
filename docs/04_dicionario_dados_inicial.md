# Dicionário de Dados Inicial

Este dicionário será expandido durante a construção do banco.

## Campos temporais importantes

| Campo | Descrição |
|---|---|
| data_nascimento | Data de nascimento do cliente |
| idade_atual | Idade calculada a partir da data de nascimento |
| faixa_etaria | Agrupamento da idade |
| data_cadastro | Data de entrada do cliente no banco |
| data_inicio_relacionamento | Data do primeiro vínculo financeiro |
| data_contratacao | Data em que um contrato foi formalizado |
| data_liberacao_credito | Data de liberação do crédito |
| data_vencimento | Data prevista de pagamento |
| data_pagamento | Data real de pagamento |
| dias_atraso | Diferença entre pagamento e vencimento |
| safra_contratacao | Ano/mês da contratação |
| ano_mes | Competência mensal para análise |

## Campos analíticos

| Campo | Descrição |
|---|---|
| score_credito | Score sintético de crédito |
| rating_cliente | Rating derivado do score |
| segmento | Segmento comercial do cliente |
| faixa_renda | Agrupamento de renda |
| bucket_atraso | Classificação do atraso |
| flag_cliente_ativo | Indica cliente ativo |
| flag_churn | Indica cliente em churn |
| flag_rotativo | Indica uso do rotativo do cartão |
| flag_pagamento_minimo | Indica pagamento mínimo da fatura |
| flag_fraude | Indica alerta de fraude |
| flag_dado_inconsistente | Indica problema de qualidade |
