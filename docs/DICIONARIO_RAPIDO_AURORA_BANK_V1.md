# Dicionário Rápido — Aurora Bank V1

## Tabelas de análise mais importantes

### gold.kpi_executivo_banco

Resumo executivo do banco. Use para visão macro.

### gold.visao_executiva_cliente

Base mais importante para análise por cliente.

Campos principais:

```text
num_pes
nome
segmento
rating_cliente
score_credito
renda_mensal
classe_risco_relacionamento
faixa_risco_churn
score_churn
perfil_relacionamento
proxima_melhor_acao
acao_retencao_recomendada
saldo_devedor_credito
saldo_npl_90
qtd_cartoes_ativos
qtd_contratos_credito
qtd_portabilidades_pagas
qtd_conversoes_crm
qtd_sessoes_digitais
qtd_acionamentos_cobranca
```

### gold.dw_contratacao

Tabela flat de contratação/crédito.

Campos importantes:

```text
num_pes
ctr_numero
lc_cod
produto
subproduto
canal
origem
valor_contratado
saldo_devedor
flg_apto_renovacao
flg_renovacao
flg_inadimplente
flg_npl_90
```

### gold.dw_portabilidade

Tabela flat de portabilidade.

Campos importantes:

```text
num_pes
portabilidade_id
banco_origem_id
nome_banco_origem
produto
subproduto
canal
origem
valor_saldo_devedor
taxa_origem
taxa_ofertada
ganho_taxa
valor_troco_liberado
flg_portabilidade_paga
flg_perdida_taxa
flg_retida_banco_origem
```

### gold.dw_crm

Tabela flat de CRM.

Campos importantes:

```text
num_pes
campanha_id
nome_campanha
produto_alvo
canal_principal
flg_oferta_enviada
flg_entregue
flg_aberto
flg_clicado
flg_convertido
receita_estimada
```

### gold.dw_canais_digitais

Tabela flat de eventos digitais.

Campos importantes:

```text
num_pes
sessao_id
evento_id
canal_digital
device
jornada
evento
flg_conclusao
flg_abandono
flg_erro
tipo_erro
severidade
```

### gold.dw_cobranca

Tabela flat de cobrança.

Campos importantes:

```text
num_pes
ctr_numero
acionamento_id
carteira_cobranca
canal_acionamento
resultado_acionamento
flg_gerou_acordo
flg_recuperou_valor
flg_acordo_quebrado
valor_recuperado
```

### gold.dw_churn

Tabela flat de churn.

Campos importantes:

```text
num_pes
score_churn
faixa_risco_churn
flg_risco_churn
flg_churn_critico
acao_retencao_recomendada
pontos_inatividade_transacional
pontos_inatividade_digital
pontos_cartao
pontos_credito
pontos_cobranca
pontos_friccao_digital
pontos_crm
```

## Queries rápidas

### Ver todas as tabelas

```sql
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('silver', 'sdx', 'gold', 'meta')
ORDER BY table_schema, table_name;
```

### Contar clientes

```sql
SELECT COUNT(*)
FROM silver.clientes;
```

### Ver KPIs executivos

```sql
SELECT *
FROM gold.kpi_executivo_banco;
```

### Ver clientes críticos

```sql
SELECT *
FROM gold.visao_executiva_cliente
WHERE classe_risco_relacionamento = 'ALTO_RISCO'
   OR flg_churn_critico = 1
LIMIT 100;
```
