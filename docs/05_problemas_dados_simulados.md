# Problemas de Dados Simulados

A base do Aurora Bank será criada com falhas propositais.

## Problemas cadastrais

- CPF duplicado
- nome com acento e sem acento
- cidade divergente
- UF ausente
- renda nula
- renda zerada
- score ausente
- estado civil ausente
- cliente com múltiplos cadastros

## Problemas temporais

- data de contratação antes da proposta
- data de pagamento antes do vencimento
- data futura
- data de nascimento inválida
- data de atualização cadastral ausente

## Problemas financeiros

- valor pago maior que valor devido
- parcela sem contrato
- contrato sem parcela
- fatura sem cartão
- pagamento sem fatura
- status financeiro divergente
- saldo devedor negativo

## Problemas de origem

- canal escrito de várias formas: APP, App, Mobile, Aplicativo
- produto com nome diferente entre sistemas
- status em português e inglês
- registros duplicados por reprocessamento
- dados atrasados na ingestão

## Objetivo

Esses problemas existem para treinar:

- ETL
- tratamento de nulos
- deduplicação
- padronização
- conciliação
- data quality
- investigação analítica
