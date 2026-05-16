# Regras de Negócio — Aurora Bank

## Cliente ativo

Um cliente é considerado ativo quando atende pelo menos uma das condições:

- possui conta ativa;
- realizou transação nos últimos 90 dias;
- possui cartão ativo;
- possui contrato de crédito ativo;
- realizou login nos últimos 90 dias.

## Churn

Um cliente pode ser classificado como risco de churn quando:

- está há mais de 120 dias sem transacionar;
- está há mais de 90 dias sem login;
- cancelou cartão recentemente;
- reduziu saldo médio;
- não respondeu campanhas recentes;
- possui atendimento/reclamação recente.

## Inadimplência

Classificação por dias de atraso:

| Bucket | Regra |
|---|---|
| ADIMPLENTE | 0 dias |
| ATRASO_1_30 | 1 a 30 dias |
| ATRASO_31_60 | 31 a 60 dias |
| ATRASO_61_90 | 61 a 90 dias |
| NPL_90_PLUS | Acima de 90 dias |

## Crédito

Uma proposta de crédito passa por:

1. simulação
2. proposta
3. análise
4. aprovação ou recusa
5. contratação
6. liberação
7. geração de parcelas
8. pagamento
9. quitação ou inadimplência

## Portabilidade

Uma proposta de portabilidade passa por:

1. simulação
2. solicitação
3. análise
4. envio ao banco origem
5. retorno
6. aprovação
7. pagamento
8. contrato portado ou perda

## Cartão

Métricas importantes:

- uso do limite
- percentual pago da fatura
- dias de atraso
- rotativo
- pagamento mínimo
- cancelamento
- aumento/redução de limite

## CRM

Funil de campanha:

1. elegível
2. enviado
3. entregue
4. aberto
5. clicado
6. convertido

## Risco

Risco do cliente combina:

- score de crédito
- renda
- histórico de atraso
- uso do cartão
- comportamento transacional
- estabilidade cadastral
- fraude/KYC
- relacionamento com banco
