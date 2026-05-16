"""
Aurora Bank Enterprise Data Lab
Patch 05A — Gerador Bronze de Crédito

Execute dentro da pasta do projeto:

    python .\scripts\07_generate_bronze_credito.py --mode dev --overwrite

Pré-requisito:
    Ter rodado antes:
    python .\scripts\01_generate_bronze_clientes.py --mode dev --overwrite

Saídas em Parquet:
    data/bronze/raw_propostas_credito/
    data/bronze/raw_contratos_credito/
    data/bronze/raw_parcelas_credito/
    data/bronze/raw_pagamentos_credito/
    data/bronze/raw_politicas_credito/
    data/bronze/raw_politicas_precificacao/
    data/bronze/raw_renegociacoes/

Observação:
    Este script cria dados fictícios/sintéticos e injeta imperfeições propositais.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
import pandas as pd


BRONZE_BASE = Path("data/bronze")
CLIENTES_CORE_DIR = BRONZE_BASE / "raw_clientes_core"

OUT_PROPOSTAS = BRONZE_BASE / "raw_propostas_credito"
OUT_CONTRATOS = BRONZE_BASE / "raw_contratos_credito"
OUT_PARCELAS = BRONZE_BASE / "raw_parcelas_credito"
OUT_PAGAMENTOS = BRONZE_BASE / "raw_pagamentos_credito"
OUT_POLITICAS_CREDITO = BRONZE_BASE / "raw_politicas_credito"
OUT_POLITICAS_PRECIFICACAO = BRONZE_BASE / "raw_politicas_precificacao"
OUT_RENEGOCIACOES = BRONZE_BASE / "raw_renegociacoes"

MODES = {
    "dev": {
        "proposal_rate": 0.75,
        "max_proposals_per_customer": 3,
        "installment_chunk_size": 200_000,
    },
    "lab": {
        "proposal_rate": 0.80,
        "max_proposals_per_customer": 4,
        "installment_chunk_size": 500_000,
    },
    "growth": {
        "proposal_rate": 0.85,
        "max_proposals_per_customer": 5,
        "installment_chunk_size": 1_000_000,
    },
}

PRODUTOS_CREDITO = np.array([
    "EMPRESTIMO_PESSOAL",
    "CONSIGNADO_PRIVADO",
    "CONSIGNADO_PUBLICO",
    "CONSIGNADO_INSS",
    "REFINANCIAMENTO",
    "ANTECIPACAO_FGTS"
])

CANAIS = np.array(["APP", "SITE", "AGENCIA", "CORRESPONDENTE", "WHATSAPP", "CALL_CENTER", "OPEN_FINANCE"])
STATUS_PROPOSTA = np.array(["APROVADA", "REPROVADA", "EM_ANALISE", "CANCELADA", "EXPIRADA"])
MOTIVOS_RECUSA = np.array([
    "SCORE_BAIXO",
    "RENDA_INSUFICIENTE",
    "RESTRICAO_CADASTRAL",
    "POLITICA_INTERNA",
    "ENDIVIDAMENTO_ALTO",
    "DOCUMENTACAO_PENDENTE"
])
STATUS_CONTRATO = np.array(["ATIVO", "QUITADO", "INADIMPLENTE", "CANCELADO", "RENEGOCIADO"])
STATUS_PARCELA = np.array(["ABERTA", "PAGA", "PAGA_EM_ATRASO", "EM_ATRASO", "RENEGOCIADA"])
STATUS_PAGAMENTO = np.array(["EFETIVADO", "PENDENTE", "CANCELADO", "ESTORNADO"])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gera dados Bronze de crédito.")
    parser.add_argument("--mode", choices=list(MODES.keys()), default="dev")
    parser.add_argument("--seed", type=int, default=45)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def assert_project_root() -> None:
    if not Path("README.md").exists() or not Path("scripts").exists():
        raise SystemExit("Execute este script dentro da pasta raiz do projeto aurora_bank_enterprise_v1.")


def prepare_dirs(overwrite: bool) -> None:
    for path in [
        OUT_PROPOSTAS,
        OUT_CONTRATOS,
        OUT_PARCELAS,
        OUT_PAGAMENTOS,
        OUT_POLITICAS_CREDITO,
        OUT_POLITICAS_PRECIFICACAO,
        OUT_RENEGOCIACOES,
    ]:
        if overwrite and path.exists():
            shutil.rmtree(path)
        path.mkdir(parents=True, exist_ok=True)


def load_client_parts() -> list[Path]:
    files = sorted(CLIENTES_CORE_DIR.glob("*.parquet"))
    if not files:
        raise SystemExit(
            "Não encontrei clientes Bronze. Rode antes:\n"
            r"python .\scripts\01_generate_bronze_clientes.py --mode dev --overwrite"
        )
    return files


def random_dates_between(rng: np.random.Generator, start_dates: pd.Series, end_date: str) -> pd.Series:
    start = pd.to_datetime(start_dates).fillna(pd.Timestamp("2020-01-01"))
    end = pd.Timestamp(end_date)
    delta_days = (end - start).dt.days.clip(lower=0)
    offsets = rng.integers(0, np.maximum(delta_days.to_numpy(), 1))
    return (start + pd.to_timedelta(offsets, unit="D")).dt.date


def rating_from_score(score: np.ndarray) -> np.ndarray:
    out = np.full(len(score), "D", dtype=object)
    out[score >= 520] = "C"
    out[score >= 650] = "B"
    out[score >= 760] = "A"
    return out


def create_policy_files(rng: np.random.Generator) -> None:
    segmentos = ["VAREJO", "RENDA_MEDIA", "ALTA_RENDA", "DIGITAL", "CONSIGNADO", "UNIVERSITARIO", "EMPREENDEDOR", "INVESTIDOR"]
    ratings = ["A", "B", "C", "D"]
    produtos = list(PRODUTOS_CREDITO)

    rows_credito = []
    rows_preco = []
    policy_id = 1
    price_id = 1

    for produto in produtos:
        for segmento in segmentos:
            for rating in ratings:
                if rating == "A":
                    score_min, score_max = 760, 1000
                    taxa_min, taxa_max = 0.012, 0.026
                    max_comprometimento = 0.38
                elif rating == "B":
                    score_min, score_max = 650, 759
                    taxa_min, taxa_max = 0.020, 0.040
                    max_comprometimento = 0.32
                elif rating == "C":
                    score_min, score_max = 520, 649
                    taxa_min, taxa_max = 0.035, 0.065
                    max_comprometimento = 0.26
                else:
                    score_min, score_max = 0, 519
                    taxa_min, taxa_max = 0.060, 0.110
                    max_comprometimento = 0.18

                if "CONSIGNADO" in produto:
                    taxa_min *= 0.55
                    taxa_max *= 0.70
                    max_comprometimento += 0.05

                rows_credito.append({
                    "politica_credito_id": policy_id,
                    "produto_credito": produto,
                    "segmento": segmento,
                    "rating": rating,
                    "score_min": score_min,
                    "score_max": score_max,
                    "renda_minima": 1412 if produto != "ANTECIPACAO_FGTS" else 0,
                    "prazo_min": 6,
                    "prazo_max": 96 if "CONSIGNADO" in produto else 72,
                    "valor_min": 300,
                    "valor_max": 200000 if produto != "ANTECIPACAO_FGTS" else 20000,
                    "comprometimento_renda_max": round(max_comprometimento, 4),
                    "vigencia_inicio": pd.Timestamp("2020-01-01").date(),
                    "vigencia_fim": pd.Timestamp("2026-12-31").date(),
                    "flag_ativa": True,
                    "dt_ingestao": pd.Timestamp.now(),
                    "origem_sistema": "MOTOR_POLITICAS"
                })
                policy_id += 1

                rows_preco.append({
                    "politica_precificacao_id": price_id,
                    "produto_credito": produto,
                    "segmento": segmento,
                    "rating": rating,
                    "taxa_min": round(taxa_min, 4),
                    "taxa_max": round(taxa_max, 4),
                    "spread_alvo": round(rng.uniform(0.004, 0.026), 4),
                    "custo_funding": round(rng.uniform(0.006, 0.018), 4),
                    "vigencia_inicio": pd.Timestamp("2020-01-01").date(),
                    "vigencia_fim": pd.Timestamp("2026-12-31").date(),
                    "flag_ativa": True,
                    "dt_ingestao": pd.Timestamp.now(),
                    "origem_sistema": "MOTOR_PRECIFICACAO"
                })
                price_id += 1

    pd.DataFrame(rows_credito).to_parquet(OUT_POLITICAS_CREDITO / "part_00001.parquet", index=False)
    pd.DataFrame(rows_preco).to_parquet(OUT_POLITICAS_PRECIFICACAO / "part_00001.parquet", index=False)


def calc_payment(principal: np.ndarray, rate: np.ndarray, months: np.ndarray) -> np.ndarray:
    rate = np.maximum(rate, 0.0001)
    return principal * (rate * (1 + rate) ** months) / (((1 + rate) ** months) - 1)


def generate_credit_for_clients(
    clients: pd.DataFrame,
    rng: np.random.Generator,
    conf: dict,
    part: int,
    ids_state: dict,
) -> None:
    n = len(clients)
    status = clients["status_cliente_core"].astype(str).str.upper().to_numpy()
    segmento = clients["segmento_core"].astype(str).str.upper().to_numpy()
    renda = pd.to_numeric(clients["renda_mensal"], errors="coerce").fillna(0).to_numpy()
    score = pd.to_numeric(clients["score_credito"], errors="coerce").fillna(500).to_numpy()
    rating = rating_from_score(score)

    prob = np.full(n, conf["proposal_rate"])
    prob = np.where(np.isin(status, ["ATIVO", "EM_ANALISE"]), prob, prob * 0.35)
    prob = np.where(score >= 760, prob + 0.08, prob)
    prob = np.where(score < 520, prob - 0.20, prob)
    prob = np.clip(prob, 0.05, 0.95)

    has_proposal = rng.random(n) < prob
    selected = clients.loc[has_proposal, ["cliente_id", "data_cadastro", "renda_mensal", "score_credito", "segmento_core"]].copy()

    if selected.empty:
        return

    qtd_prop = rng.integers(1, conf["max_proposals_per_customer"] + 1, size=len(selected))
    expanded = selected.loc[selected.index.repeat(qtd_prop)].reset_index(drop=True)
    qtd = len(expanded)

    proposta_ids = np.arange(ids_state["proposta_id"], ids_state["proposta_id"] + qtd, dtype=np.int64)
    ids_state["proposta_id"] += qtd

    cliente_ids = expanded["cliente_id"].to_numpy(dtype=np.int64)
    renda_e = pd.to_numeric(expanded["renda_mensal"], errors="coerce").fillna(1800).to_numpy()
    score_e = pd.to_numeric(expanded["score_credito"], errors="coerce").fillna(500).to_numpy()
    segmento_e = expanded["segmento_core"].astype(str).str.upper().to_numpy()
    rating_e = rating_from_score(score_e)

    produto = rng.choice(PRODUTOS_CREDITO, qtd, p=[0.34, 0.16, 0.12, 0.16, 0.15, 0.07])
    produto = np.where(segmento_e == "CONSIGNADO", rng.choice(["CONSIGNADO_INSS", "CONSIGNADO_PUBLICO", "CONSIGNADO_PRIVADO"], qtd), produto)
    produto = np.where(segmento_e == "UNIVERSITARIO", rng.choice(["EMPRESTIMO_PESSOAL", "ANTECIPACAO_FGTS"], qtd, p=[0.55, 0.45]), produto)

    prazo = rng.choice([6, 12, 18, 24, 36, 48, 60, 72, 84, 96], qtd, p=[0.06, 0.12, 0.08, 0.16, 0.20, 0.15, 0.12, 0.07, 0.025, 0.015])
    prazo = np.where(produto == "ANTECIPACAO_FGTS", rng.choice([3, 6, 12, 18], qtd), prazo)

    mult = rng.uniform(0.8, 12, size=qtd)
    mult = np.where(np.char.find(produto.astype(str), "CONSIGNADO") >= 0, rng.uniform(2, 20, size=qtd), mult)
    mult = np.where(produto == "ANTECIPACAO_FGTS", rng.uniform(0.3, 4, size=qtd), mult)

    valor = np.clip(renda_e * mult, 300, 220000).round(2)
    valor = np.where(produto == "ANTECIPACAO_FGTS", np.clip(valor, 300, 20000), valor)

    base_taxa = np.where(rating_e == "A", rng.uniform(0.012, 0.027, size=qtd),
                 np.where(rating_e == "B", rng.uniform(0.020, 0.043, size=qtd),
                 np.where(rating_e == "C", rng.uniform(0.038, 0.068, size=qtd),
                          rng.uniform(0.060, 0.115, size=qtd))))
    base_taxa = np.where(np.char.find(produto.astype(str), "CONSIGNADO") >= 0, base_taxa * rng.uniform(0.50, 0.72, size=qtd), base_taxa)
    base_taxa = np.round(base_taxa, 4)

    parcela_estimada = calc_payment(valor, base_taxa, prazo).round(2)
    comprometimento = np.divide(parcela_estimada, renda_e, out=np.full(qtd, 9.99), where=renda_e > 0)

    # Score motor com ruído
    score_motor = np.clip(score_e + rng.normal(0, 60, size=qtd), 1, 1000).round().astype(int)
    rating_motor = rating_from_score(score_motor)

    aprova_prob = np.where(score_motor >= 760, 0.82,
                   np.where(score_motor >= 650, 0.66,
                   np.where(score_motor >= 520, 0.42, 0.16)))
    aprova_prob = np.where(comprometimento > 0.40, aprova_prob * 0.25, aprova_prob)
    aprova_prob = np.where(renda_e <= 0, aprova_prob * 0.10, aprova_prob)
    aprovada_mask = rng.random(qtd) < aprova_prob

    status_prop = np.where(aprovada_mask, "APROVADA", rng.choice(["REPROVADA", "EM_ANALISE", "CANCELADA", "EXPIRADA"], qtd, p=[0.60, 0.15, 0.13, 0.12]))
    motivo_recusa = np.where(status_prop == "REPROVADA", rng.choice(MOTIVOS_RECUSA, qtd), None)

    data_proposta = random_dates_between(rng, expanded["data_cadastro"], "2026-12-31")
    data_proposta_dt = pd.to_datetime(data_proposta)

    proposta = pd.DataFrame({
        "proposta_id": proposta_ids,
        "cliente_id": cliente_ids,
        "produto_credito": produto,
        "canal_proposta": rng.choice(CANAIS, qtd, p=[0.46, 0.12, 0.06, 0.12, 0.10, 0.10, 0.04]),
        "data_proposta": data_proposta,
        "valor_solicitado": valor,
        "prazo_meses": prazo,
        "taxa_ofertada": base_taxa,
        "parcela_estimada": parcela_estimada,
        "renda_mensal_informada": renda_e,
        "comprometimento_renda_estimado": np.round(comprometimento, 4),
        "score_motor": score_motor,
        "rating_motor": rating_motor,
        "status_proposta": status_prop,
        "motivo_recusa": motivo_recusa,
        "dt_ingestao": pd.Timestamp.now(),
        "origem_sistema": "MOTOR_CREDITO",
        "arquivo_origem": f"propostas_credito_part_{part:05d}.parquet",
    })

    # Problemas simulados em propostas
    if len(proposta) > 0:
        null_score_mask = rng.random(len(proposta)) < 0.008
        proposta.loc[null_score_mask, "score_motor"] = None
        future_mask = rng.random(len(proposta)) < 0.001
        proposta.loc[future_mask, "data_proposta"] = pd.Timestamp("2027-01-10").date()

    proposta.to_parquet(OUT_PROPOSTAS / f"part_{part:05d}.parquet", index=False)

    # Contratos: parte das propostas aprovadas vira contrato
    contracted_mask = (status_prop == "APROVADA") & (rng.random(qtd) < 0.78)
    prop_contract = proposta.loc[contracted_mask].copy()

    if prop_contract.empty:
        return

    qtd_c = len(prop_contract)
    contrato_ids = np.arange(ids_state["contrato_id"], ids_state["contrato_id"] + qtd_c, dtype=np.int64)
    ids_state["contrato_id"] += qtd_c

    data_contratacao = pd.to_datetime(prop_contract["data_proposta"], errors="coerce").fillna(pd.Timestamp("2020-01-01")) + pd.to_timedelta(rng.integers(0, 12, size=qtd_c), unit="D")
    data_liberacao = data_contratacao + pd.to_timedelta(rng.integers(0, 5, size=qtd_c), unit="D")
    data_primeiro_venc = data_liberacao + pd.to_timedelta(rng.integers(25, 45, size=qtd_c), unit="D")

    valor_contratado = pd.to_numeric(prop_contract["valor_solicitado"], errors="coerce").fillna(1000).to_numpy()
    taxa = pd.to_numeric(prop_contract["taxa_ofertada"], errors="coerce").fillna(0.035).to_numpy()
    prazo_c = pd.to_numeric(prop_contract["prazo_meses"], errors="coerce").fillna(24).astype(int).to_numpy()
    parcela = calc_payment(valor_contratado, taxa, prazo_c).round(2)

    meses_passados = np.clip(((pd.Timestamp("2026-12-31") - data_contratacao).dt.days // 30).to_numpy(), 0, prazo_c)
    saldo_devedor = np.clip(valor_contratado - (valor_contratado / prazo_c) * meses_passados + rng.normal(0, 300, size=qtd_c), 0, None).round(2)

    atraso_atual = rng.choice([0, 0, 0, 0, 5, 15, 30, 60, 90, 120], qtd_c, p=[0.38,0.20,0.13,0.07,0.06,0.05,0.04,0.03,0.025,0.015])
    status_contrato = np.where(saldo_devedor <= 50, "QUITADO",
                       np.where(atraso_atual >= 90, "INADIMPLENTE",
                       rng.choice(["ATIVO", "ATIVO", "ATIVO", "RENEGOCIADO", "CANCELADO"], qtd_c, p=[0.66,0.12,0.10,0.08,0.04])))

    contratos = pd.DataFrame({
        "contrato_id": contrato_ids,
        "proposta_id": prop_contract["proposta_id"].to_numpy(dtype=np.int64),
        "cliente_id": prop_contract["cliente_id"].to_numpy(dtype=np.int64),
        "produto_credito": prop_contract["produto_credito"].to_numpy(),
        "canal_contratacao": prop_contract["canal_proposta"].to_numpy(),
        "data_proposta": prop_contract["data_proposta"].to_numpy(),
        "data_contratacao": data_contratacao.dt.date.to_numpy(),
        "data_liberacao_credito": data_liberacao.dt.date.to_numpy(),
        "data_primeiro_vencimento": data_primeiro_venc.dt.date.to_numpy(),
        "valor_contratado": valor_contratado.round(2),
        "valor_liberado": (valor_contratado * rng.uniform(0.90, 1.0, size=qtd_c)).round(2),
        "prazo_meses": prazo_c,
        "taxa_mensal": taxa,
        "parcela": parcela,
        "saldo_devedor": saldo_devedor,
        "dias_atraso_atual": atraso_atual.astype(int),
        "status_contrato": status_contrato,
        "dt_ingestao": pd.Timestamp.now(),
        "origem_sistema": "CORE_CREDITO",
        "arquivo_origem": f"contratos_credito_part_{part:05d}.parquet",
    })

    # Problemas simulados em contratos
    if len(contratos) > 0:
        bad_date_mask = rng.random(len(contratos)) < 0.001
        contratos.loc[bad_date_mask, "data_contratacao"] = pd.to_datetime(contratos.loc[bad_date_mask, "data_proposta"]) - pd.to_timedelta(5, unit="D")
        contratos.loc[bad_date_mask, "data_contratacao"] = pd.to_datetime(contratos.loc[bad_date_mask, "data_contratacao"]).dt.date

        saldo_neg_mask = rng.random(len(contratos)) < 0.001
        contratos.loc[saldo_neg_mask, "saldo_devedor"] = -abs(contratos.loc[saldo_neg_mask, "saldo_devedor"])

    contratos.to_parquet(OUT_CONTRATOS / f"part_{part:05d}.parquet", index=False)

    # Parcelas e pagamentos
    parcel_records = []
    payment_records = []
    reneg_records = []

    for row in contratos.itertuples(index=False):
        data_primeiro = pd.Timestamp(row.data_primeiro_vencimento)
        parcelas_pagas_estimadas = int(min(max((pd.Timestamp("2026-12-31") - pd.Timestamp(row.data_contratacao)).days // 30, 0), row.prazo_meses))

        for numero in range(1, int(row.prazo_meses) + 1):
            parcela_id = ids_state["parcela_id"]
            ids_state["parcela_id"] += 1

            venc = data_primeiro + pd.DateOffset(months=numero - 1)
            valor_parcela = float(row.parcela)

            if numero <= parcelas_pagas_estimadas:
                atraso = int(rng.choice([0, 0, 0, 0, 3, 7, 15, 30, 60, 90, 120], p=[0.36,0.22,0.12,0.08,0.06,0.05,0.04,0.03,0.02,0.015,0.005]))
                data_pag = venc + pd.DateOffset(days=atraso)
                status_parcela = "PAGA" if atraso == 0 else "PAGA_EM_ATRASO"
                valor_pago = round(valor_parcela + (valor_parcela * 0.02 if atraso > 0 else 0), 2)
            else:
                atraso = int(max((pd.Timestamp("2026-12-31") - venc).days, 0))
                if atraso > 0 and row.status_contrato == "INADIMPLENTE":
                    status_parcela = "EM_ATRASO"
                else:
                    status_parcela = "ABERTA"
                    atraso = 0
                data_pag = None
                valor_pago = 0

            parcel_records.append({
                "parcela_id": parcela_id,
                "contrato_id": row.contrato_id,
                "cliente_id": row.cliente_id,
                "numero_parcela": numero,
                "data_vencimento": venc.date(),
                "data_pagamento": data_pag.date() if data_pag is not None else None,
                "valor_parcela": round(valor_parcela, 2),
                "valor_pago": valor_pago,
                "valor_juros": round(valor_parcela * float(row.taxa_mensal), 2),
                "valor_multa": round(valor_parcela * 0.02, 2) if atraso > 0 else 0,
                "dias_atraso": atraso,
                "status_parcela": status_parcela,
                "dt_ingestao": pd.Timestamp.now(),
                "origem_sistema": "CORE_PARCELAS",
                "arquivo_origem": f"parcelas_credito_part_{part:05d}.parquet",
            })

            if data_pag is not None:
                payment_records.append({
                    "pagamento_credito_id": ids_state["pagamento_id"],
                    "parcela_id": parcela_id,
                    "contrato_id": row.contrato_id,
                    "cliente_id": row.cliente_id,
                    "data_pagamento": data_pag.date(),
                    "valor_pagamento": valor_pago,
                    "canal_pagamento": rng.choice(["DEBITO_CONTA", "PIX", "BOLETO", "AGENCIA", "APP"], p=[0.45,0.20,0.22,0.04,0.09]),
                    "status_pagamento": rng.choice(STATUS_PAGAMENTO, p=[0.95,0.02,0.02,0.01]),
                    "dt_ingestao": pd.Timestamp.now(),
                    "origem_sistema": "CORE_PAGAMENTOS_CREDITO",
                    "arquivo_origem": f"pagamentos_credito_part_{part:05d}.parquet",
                })
                ids_state["pagamento_id"] += 1

        if row.status_contrato == "RENEGOCIADO" or (row.dias_atraso_atual >= 60 and rng.random() < 0.20):
            reneg_records.append({
                "renegociacao_id": ids_state["renegociacao_id"],
                "contrato_id": row.contrato_id,
                "cliente_id": row.cliente_id,
                "data_renegociacao": (pd.Timestamp(row.data_contratacao) + pd.Timedelta(days=int(rng.integers(90, 1100)))).date(),
                "saldo_renegociado": max(float(row.saldo_devedor), 0),
                "novo_prazo_meses": int(rng.choice([12, 24, 36, 48, 60])),
                "nova_taxa_mensal": round(float(row.taxa_mensal) * rng.uniform(0.85, 1.20), 4),
                "motivo_renegociacao": rng.choice(["ATRASO", "REDUCAO_PARCELA", "RETENCAO", "REESTRUTURACAO"]),
                "status_renegociacao": rng.choice(["EFETIVADA", "EM_ANALISE", "CANCELADA"], p=[0.72,0.18,0.10]),
                "dt_ingestao": pd.Timestamp.now(),
                "origem_sistema": "CORE_RENEGOCIACAO",
                "arquivo_origem": f"renegociacoes_part_{part:05d}.parquet",
            })
            ids_state["renegociacao_id"] += 1

    parcelas = pd.DataFrame(parcel_records)
    pagamentos = pd.DataFrame(payment_records)
    renegociacoes = pd.DataFrame(reneg_records)

    # Parcela órfã proposital
    if len(parcelas):
        orphan_qtd = max(1, int(len(parcelas) * 0.0008))
        orphan = parcelas.sample(orphan_qtd, random_state=int(rng.integers(1, 999999))).copy()
        orphan["parcela_id"] = np.arange(ids_state["parcela_id"], ids_state["parcela_id"] + orphan_qtd)
        ids_state["parcela_id"] += orphan_qtd
        orphan["contrato_id"] = orphan["contrato_id"] + 999_000_000
        orphan["arquivo_origem"] = f"parcelas_orfas_part_{part:05d}.parquet"
        parcelas = pd.concat([parcelas, orphan], ignore_index=True)

    parcelas.to_parquet(OUT_PARCELAS / f"part_{part:05d}.parquet", index=False)
    pagamentos.to_parquet(OUT_PAGAMENTOS / f"part_{part:05d}.parquet", index=False)

    if not renegociacoes.empty:
        renegociacoes.to_parquet(OUT_RENEGOCIACOES / f"part_{part:05d}.parquet", index=False)
    else:
        pd.DataFrame(columns=[
            "renegociacao_id", "contrato_id", "cliente_id", "data_renegociacao",
            "saldo_renegociado", "novo_prazo_meses", "nova_taxa_mensal",
            "motivo_renegociacao", "status_renegociacao", "dt_ingestao",
            "origem_sistema", "arquivo_origem"
        ]).to_parquet(OUT_RENEGOCIACOES / f"part_{part:05d}.parquet", index=False)

    print(f"  propostas: {len(proposta):,}".replace(",", "."))
    print(f"  contratos: {len(contratos):,}".replace(",", "."))
    print(f"  parcelas: {len(parcelas):,}".replace(",", "."))
    print(f"  pagamentos: {len(pagamentos):,}".replace(",", "."))
    print(f"  renegociações: {len(renegociacoes):,}".replace(",", "."))


def main() -> None:
    args = parse_args()
    assert_project_root()
    client_files = load_client_parts()
    prepare_dirs(args.overwrite)

    rng = np.random.default_rng(args.seed)
    conf = MODES[args.mode]
    create_policy_files(rng)

    ids_state = {
        "proposta_id": 1,
        "contrato_id": 1,
        "parcela_id": 1,
        "pagamento_id": 1,
        "renegociacao_id": 1,
    }

    print("Aurora Bank — Gerador Bronze Crédito")
    print("=" * 70)
    print(f"Modo: {args.mode}")
    print(f"Arquivos de clientes encontrados: {len(client_files)}")
    print("=" * 70)

    for part, file in enumerate(client_files, start=1):
        print(f"\nLendo clientes: {file}")
        clients = pd.read_parquet(
            file,
            columns=["cliente_id", "data_cadastro", "status_cliente_core", "renda_mensal", "score_credito", "segmento_core"]
        )

        generate_credit_for_clients(
            clients=clients,
            rng=rng,
            conf=conf,
            part=part,
            ids_state=ids_state,
        )

    print("\nGeração concluída.")
    print("\nPróximo passo:")
    print(r"python .\scripts\08_create_bronze_silver_credito.py")


if __name__ == "__main__":
    main()
