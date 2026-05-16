# Post LinkedIn — Aurora Bank Enterprise Data Lab

Construí a V1 do Aurora Bank Enterprise Data Lab, um projeto fictício de Engenharia de Dados e Analytics aplicado ao setor financeiro.

A ideia foi simular um ambiente bancário completo, com dados 100% sintéticos, para praticar SQL, modelagem analítica, PostgreSQL, DuckDB, Cliente 360, KPIs executivos e regras de negócio.

O projeto inclui domínios como:

- clientes;
- contas e transações;
- cartões;
- crédito;
- portabilidade;
- CRM e campanhas;
- canais digitais;
- cobrança;
- churn;
- visão executiva.

A arquitetura foi organizada em camadas:

- Bronze: dados brutos sintéticos;
- Silver: dados tratados;
- SDX: camada semântica e Cliente 360;
- Gold: DWs, KPIs e bases executivas;
- Meta: quality checks.

Um dos pontos mais importantes foi evoluir o projeto de DuckDB para PostgreSQL. O DuckDB foi usado como base local para geração e estruturação inicial dos dados. Depois, as camadas analíticas foram migradas para PostgreSQL para simular melhor um ambiente relacional corporativo, com schemas, conexão via VSCode e consultas SQL mais próximas do dia a dia.

Com isso, o projeto passou a ter tabelas como:

- gold.visao_executiva_cliente
- gold.kpi_executivo_banco
- gold.dw_contratacao
- gold.dw_portabilidade
- gold.dw_crm
- gold.dw_canais_digitais
- gold.dw_cobranca
- gold.dw_churn
- sdx.cliente_360_v8

Esse projeto foi criado para fortalecer minha prática em dados, engenharia, BI e análise de negócio no contexto financeiro.

Próximos passos: criar dashboards em Power BI, automações de relatórios e evoluir a V2 com investimentos, seguros, consórcio, imobiliário e fraude/KYC.
