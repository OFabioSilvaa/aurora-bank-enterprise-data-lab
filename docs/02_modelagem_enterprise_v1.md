# Modelagem Enterprise V1 — Aurora Bank

## Visão geral

A modelagem do Aurora Bank será dividida em domínios de negócio e camadas analíticas.

Camadas:

```text
Bronze -> Silver -> SDX -> Gold
```

## Domínios principais

1. Clientes
2. Contas
3. Transações
4. Cartão de crédito
5. Crédito pessoal
6. Crédito consignado
7. Portabilidade
8. Crédito imobiliário
9. Consórcio
10. Investimentos
11. Seguros
12. CRM e marketing
13. Canais digitais
14. Atendimento
15. Cobrança
16. Inadimplência
17. Churn
18. Risco de crédito
19. Fraude e KYC
20. Precificação

---

# 1. Clientes

## Bronze

- bronze.raw_clientes_core
- bronze.raw_clientes_app
- bronze.raw_enderecos
- bronze.raw_contatos
- bronze.raw_scores_cliente
- bronze.raw_segmentos_cliente

## Silver

- silver.clientes
- silver.enderecos
- silver.contatos
- silver.scores_cliente_historico
- silver.segmentos_cliente_historico

## Campos principais

### silver.clientes

- cliente_id
- cpf_hash
- nome
- data_nascimento
- idade_atual
- faixa_etaria
- genero
- estado_civil
- cidade
- uf
- regiao
- renda_mensal
- faixa_renda
- profissao
- tipo_ocupacao
- escolaridade
- score_credito
- rating_cliente
- segmento
- canal_aquisicao
- data_cadastro
- data_inicio_relacionamento
- data_ultima_atualizacao_cadastral
- status_cliente
- flag_cliente_ativo

## Problemas simulados

- CPF duplicado
- renda nula
- score faltante
- cidade inconsistente
- UF ausente
- cliente ativo no core e inativo no app
- data de nascimento nula
- segmento divergente entre origens

## Análises possíveis

- perfil da carteira
- clientes ativos e inativos
- churn
- segmentação
- risco por faixa etária
- renda por região
- comportamento por canal de aquisição

---

# 2. Contas e Transações

## Bronze

- bronze.raw_contas
- bronze.raw_transacoes
- bronze.raw_saldos_diarios
- bronze.raw_pix
- bronze.raw_boletos
- bronze.raw_tarifas

## Silver

- silver.contas
- silver.transacoes
- silver.saldos_diarios
- silver.pix
- silver.boletos
- silver.tarifas

## Campos principais — silver.transacoes

- transacao_id
- conta_id
- cliente_id
- data_transacao
- data_ref
- ano_mes
- tipo_transacao
- canal
- valor
- status_transacao
- descricao
- categoria_transacao
- flag_transacao_financeira

## Problemas simulados

- transação duplicada
- transação cancelada entrando em cálculo
- valor negativo indevido
- conta inexistente
- data futura
- canal mal padronizado

## Análises possíveis

- volume transacional
- cliente ativo
- receita de tarifas
- comportamento financeiro
- movimentação média
- abandono de conta

---

# 3. Cartão de Crédito

## Bronze

- bronze.raw_cartoes
- bronze.raw_compras_cartao
- bronze.raw_faturas_cartao
- bronze.raw_pagamentos_fatura
- bronze.raw_limites_cartao_historico

## Silver

- silver.cartoes
- silver.compras_cartao
- silver.faturas_cartao
- silver.pagamentos_fatura
- silver.limites_cartao_historico

## Campos principais — silver.faturas_cartao

- fatura_id
- cartao_id
- cliente_id
- competencia
- data_fechamento
- data_vencimento
- data_pagamento
- valor_fatura
- valor_pago
- valor_minimo
- dias_atraso_fatura
- status_fatura
- flag_rotativo
- flag_pagamento_minimo

## Análises possíveis

- uso de limite
- atraso de fatura
- pagamento mínimo
- rotativo
- aumento de limite
- risco por comportamento de cartão

---

# 4. Crédito Pessoal e Consignado

## Bronze

- bronze.raw_propostas_credito
- bronze.raw_contratos_credito
- bronze.raw_parcelas_credito
- bronze.raw_pagamentos_credito
- bronze.raw_consignado
- bronze.raw_renegociacoes
- bronze.raw_politicas_credito

## Silver

- silver.propostas_credito
- silver.contratos_credito
- silver.parcelas_credito
- silver.pagamentos_credito
- silver.renegociacoes
- silver.politicas_credito

## Campos principais — silver.contratos_credito

- contrato_id
- proposta_id
- cliente_id
- produto_credito
- subproduto_credito
- data_proposta
- data_aprovacao
- data_contratacao
- data_liberacao_credito
- safra_contratacao
- valor_contratado
- valor_liberado
- prazo_meses
- taxa_mensal
- parcela
- saldo_devedor
- status_contrato
- dias_atraso_atual
- bucket_atraso
- canal_contratacao

## Análises possíveis

- aprovação
- conversão
- carteira
- saldo devedor
- inadimplência
- NPL 90+
- safra
- política de aprovação
- perda esperada

---

# 5. Portabilidade

## Bronze

- bronze.raw_propostas_portabilidade
- bronze.raw_contratos_portados
- bronze.raw_bancos_origem
- bronze.raw_ofertas_retencao
- bronze.raw_motivos_perda_portabilidade

## Silver

- silver.propostas_portabilidade
- silver.contratos_portados
- silver.bancos_origem
- silver.ofertas_retencao
- silver.motivos_perda_portabilidade

## Análises possíveis

- conversão por banco origem
- taxa ofertada x taxa origem
- troco liberado
- motivo de perda
- eficiência operacional
- canal com maior conversão

---

# 6. Crédito Imobiliário

## Bronze

- bronze.raw_propostas_imobiliario
- bronze.raw_imoveis
- bronze.raw_contratos_imobiliario
- bronze.raw_parcelas_imobiliario
- bronze.raw_pagamentos_imobiliario
- bronze.raw_avaliacao_imovel

## Silver

- silver.propostas_imobiliario
- silver.imoveis
- silver.contratos_imobiliario
- silver.parcelas_imobiliario
- silver.pagamentos_imobiliario
- silver.avaliacao_imovel

## Análises possíveis

- LTV
- valor financiado
- prazo médio
- inadimplência imobiliária
- região com maior demanda
- aprovação por perfil

---

# 7. Consórcio

## Bronze

- bronze.raw_grupos_consorcio
- bronze.raw_cotas_consorcio
- bronze.raw_pagamentos_consorcio
- bronze.raw_contemplados_consorcio
- bronze.raw_lances_consorcio

## Silver

- silver.grupos_consorcio
- silver.cotas_consorcio
- silver.pagamentos_consorcio
- silver.contemplados_consorcio
- silver.lances_consorcio

## Análises possíveis

- cotas ativas
- inadimplência em consórcio
- contemplação
- lances
- cancelamentos
- churn em consórcio

---

# 8. CRM, Canais Digitais, Atendimento, Cobrança e Risco

## Bronze

- bronze.raw_campanhas_crm
- bronze.raw_interacoes_crm
- bronze.raw_ofertas
- bronze.raw_eventos_app
- bronze.raw_eventos_web
- bronze.raw_sessoes_digitais
- bronze.raw_atendimentos
- bronze.raw_acionamentos_cobranca
- bronze.raw_acordos_cobranca
- bronze.raw_alertas_fraude
- bronze.raw_kyc

## Silver

- silver.campanhas_crm
- silver.interacoes_crm
- silver.ofertas
- silver.eventos_digitais
- silver.sessoes_digitais
- silver.atendimentos
- silver.acionamentos_cobranca
- silver.acordos_cobranca
- silver.alertas_fraude
- silver.kyc

## Análises possíveis

- ROI de campanha
- propensão
- abandono digital
- erro no app
- eficiência de cobrança
- recuperação de crédito
- fraude por canal
- churn
- NPS/reclamações
