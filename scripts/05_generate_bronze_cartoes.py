"""
Aurora Bank Enterprise Data Lab
Patch 04A — Gerador Bronze de Cartões, Compras, Faturas e Pagamentos

Execute dentro da pasta do projeto:

    python .\scripts\05_generate_bronze_cartoes.py --mode dev --overwrite

Pré-requisito:
    Ter rodado antes:
    python .\scripts\01_generate_bronze_clientes.py --mode dev --overwrite

Saídas em Parquet:
    data/bronze/raw_cartoes/
    data/bronze/raw_limites_cartao_historico/
    data/bronze/raw_compras_cartao/
    data/bronze/raw_faturas_cartao/
    data/bronze/raw_pagamentos_fatura/

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

OUT_CARTOES = BRONZE_BASE / "raw_cartoes"
OUT_LIMITES = BRONZE_BASE / "raw_limites_cartao_historico"
OUT_COMPRAS = BRONZE_BASE / "raw_compras_cartao"
OUT_FATURAS = BRONZE_BASE / "raw_faturas_cartao"
OUT_PAGAMENTOS = BRONZE_BASE / "raw_pagamentos_fatura"

MODES = {
    "dev": {
        "avg_purchases_per_card": 28,
        "purchase_chunk_size": 200_000,
    },
    "lab": {
        "avg_purchases_per_card": 55,
        "purchase_chunk_size": 500_000,
    },
    "growth": {
        "avg_purchases_per_card": 75,
        "purchase_chunk_size": 1_000_000,
    },
}

PRODUTOS_CARTAO = np.array(["CLASSIC", "GOLD", "PLATINUM", "BLACK", "CONSIGNADO", "UNIVERSITARIO"])
BANDEIRAS = np.array(["VISA", "MASTERCARD", "ELO"])
STATUS_CARTAO = np.array(["ATIVO", "BLOQUEADO", "CANCELADO", "EM_ANALISE"])
CANAIS = np.array(["APP", "SITE", "AGENCIA", "WHATSAPP", "CALL_CENTER", "PARCEIRO"])
CATEGORIAS_COMPRA = np.array([
    "ALIMENTACAO", "MERCADO", "TRANSPORTE", "SAUDE", "EDUCACAO",
    "LAZER", "VIAGEM", "SERVICOS", "ASSINATURAS", "VESTUARIO",
    "ELETRONICOS", "OUTROS"
])
STATUS_COMPRA = np.array(["APROVADA", "NEGADA", "CANCELADA", "ESTORNADA", "PENDENTE"])
STATUS_FATURA = np.array(["ABERTA", "FECHADA", "PAGA", "PAGA_EM_ATRASO", "EM_ATRASO", "PARCIAL"])
STATUS_PAGAMENTO = np.array(["EFETIVADO", "PENDENTE", "CANCELADO", "ESTORNADO"])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gera dados Bronze de cartão de crédito.")
    parser.add_argument("--mode", choices=list(MODES.keys()), default="dev")
    parser.add_argument("--avg-purchases-per-card", type=float, default=None)
    parser.add_argument("--purchase-chunk-size", type=int, default=None)
    parser.add_argument("--seed", type=int, default=44)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def assert_project_root() -> None:
    if not Path("README.md").exists() or not Path("scripts").exists():
        raise SystemExit("Execute este script dentro da pasta raiz do projeto aurora_bank_enterprise_v1.")


def prepare_dirs(overwrite: bool) -> None:
    for path in [OUT_CARTOES, OUT_LIMITES, OUT_COMPRAS, OUT_FATURAS, OUT_PAGAMENTOS]:
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


def month_range_for_card(data_emissao: pd.Series, max_months: int, rng: np.random.Generator) -> list[list[pd.Timestamp]]:
    months = []
    end = pd.Timestamp("2026-12-01")
    for dt in pd.to_datetime(data_emissao):
        start = pd.Timestamp(dt.year, dt.month, 1)
        all_months = pd.date_range(start=start, end=end, freq="MS")
        if len(all_months) == 0:
            months.append([])
        else:
            qtd = min(len(all_months), int(rng.integers(4, max_months + 1)))
            chosen = all_months[-qtd:]
            months.append(list(chosen))
    return months


def generate_cards_for_clients(
    clients: pd.DataFrame,
    rng: np.random.Generator,
    card_id_start: int,
    part: int,
) -> tuple[pd.DataFrame, pd.DataFrame, int]:
    n = len(clients)

    status = clients["status_cliente_core"].astype(str).str.upper().to_numpy()
    segmento = clients["segmento_core"].astype(str).str.upper().to_numpy()
    renda = pd.to_numeric(clients["renda_mensal"], errors="coerce").fillna(0).to_numpy()
    score = pd.to_numeric(clients["score_credito"], errors="coerce").fillna(550).to_numpy()

    base_prob = np.where(np.isin(status, ["ATIVO", "EM_ANALISE"]), 0.47, 0.18)
    base_prob = np.where(segmento == "ALTA_RENDA", base_prob + 0.25, base_prob)
    base_prob = np.where(segmento == "UNIVERSITARIO", base_prob - 0.10, base_prob)
    base_prob = np.where(score >= 760, base_prob + 0.12, base_prob)
    base_prob = np.clip(base_prob, 0.05, 0.85)

    has_card = rng.random(n) < base_prob
    selected = clients.loc[has_card, ["cliente_id", "data_cadastro", "renda_mensal", "score_credito", "segmento_core"]].copy()
    if selected.empty:
        return pd.DataFrame(), pd.DataFrame(), card_id_start

    qtd_cards = rng.choice([1, 2], size=len(selected), p=[0.94, 0.06])
    expanded = selected.loc[selected.index.repeat(qtd_cards)].reset_index(drop=True)
    qtd = len(expanded)

    card_ids = np.arange(card_id_start, card_id_start + qtd, dtype=np.int64)
    cliente_ids = expanded["cliente_id"].to_numpy(dtype=np.int64)

    renda_exp = pd.to_numeric(expanded["renda_mensal"], errors="coerce").fillna(1800).to_numpy()
    score_exp = pd.to_numeric(expanded["score_credito"], errors="coerce").fillna(550).to_numpy()
    segmento_exp = expanded["segmento_core"].astype(str).str.upper().to_numpy()

    produto = rng.choice(PRODUTOS_CARTAO, qtd, p=[0.43, 0.24, 0.13, 0.03, 0.10, 0.07])
    produto = np.where(segmento_exp == "ALTA_RENDA", rng.choice(["PLATINUM", "BLACK", "GOLD"], qtd, p=[0.55, 0.25, 0.20]), produto)
    produto = np.where(segmento_exp == "UNIVERSITARIO", "UNIVERSITARIO", produto)
    produto = np.where(segmento_exp == "CONSIGNADO", rng.choice(["CONSIGNADO", "CLASSIC"], qtd, p=[0.70, 0.30]), produto)

    limit_factor = rng.uniform(0.35, 3.8, size=qtd)
    limit_factor = np.where(produto == "BLACK", rng.uniform(3.0, 8.0, size=qtd), limit_factor)
    limit_factor = np.where(produto == "PLATINUM", rng.uniform(1.8, 5.5, size=qtd), limit_factor)
    limit_factor = np.where(produto == "UNIVERSITARIO", rng.uniform(0.2, 1.0, size=qtd), limit_factor)

    limite = np.clip((renda_exp * limit_factor + score_exp * rng.uniform(2.5, 8.5, size=qtd)), 300, 200000).round(2)

    # Problemas simulados
    limite_obj = limite.astype(object)
    limite_obj[rng.random(qtd) < 0.004] = None
    mask_outlier = rng.random(qtd) < 0.001
    limite_obj[mask_outlier] = rng.uniform(200000, 1000000, size=mask_outlier.sum()).round(2)

    data_emissao = random_dates_between(rng, expanded["data_cadastro"], "2026-12-31")
    status_cartao = rng.choice(STATUS_CARTAO, qtd, p=[0.78, 0.06, 0.12, 0.04])

    cartoes = pd.DataFrame({
        "cartao_id": card_ids,
        "cliente_id": cliente_ids,
        "produto_cartao": produto,
        "bandeira": rng.choice(BANDEIRAS, qtd, p=[0.43, 0.46, 0.11]),
        "limite_concedido": limite_obj,
        "data_emissao": data_emissao,
        "data_ativacao": pd.to_datetime(data_emissao) + pd.to_timedelta(rng.integers(0, 20, size=qtd), unit="D"),
        "data_cancelamento": None,
        "status_cartao": status_cartao,
        "canal_emissao": rng.choice(CANAIS, qtd, p=[0.58, 0.12, 0.05, 0.08, 0.10, 0.07]),
        "taxa_rotativo": rng.uniform(0.08, 0.19, size=qtd).round(4),
        "dt_ingestao": pd.Timestamp.now(),
        "origem_sistema": "SISTEMA_CARTOES",
        "arquivo_origem": f"cartoes_part_{part:05d}.parquet",
    })

    cancel_mask = cartoes["status_cartao"].eq("CANCELADO")
    if cancel_mask.any():
        cancel_dt = pd.to_datetime(cartoes.loc[cancel_mask, "data_ativacao"]) + pd.to_timedelta(
            rng.integers(30, 1300, size=cancel_mask.sum()), unit="D"
        )
        cancel_dt = pd.Series(np.minimum(cancel_dt.values.astype("datetime64[ns]"), np.datetime64("2026-12-31"))).dt.date
        cartoes.loc[cancel_mask, "data_cancelamento"] = cancel_dt.to_numpy()

    cartoes["data_ativacao"] = pd.to_datetime(cartoes["data_ativacao"]).dt.date

    # Histórico de limites: 3 snapshots por cartão
    limites_parts = []
    snapshots = pd.to_datetime(["2024-12-31", "2025-12-31", "2026-12-31"])
    limite_num = pd.to_numeric(pd.Series(limite_obj), errors="coerce").fillna(1000).to_numpy()
    for i, data_ref in enumerate(snapshots, start=1):
        fator = rng.uniform(0.65, 1.25, size=qtd) if i < 3 else rng.uniform(0.85, 1.35, size=qtd)
        limite_hist = np.clip(limite_num * fator, 100, 250000).round(2)
        limites_parts.append(pd.DataFrame({
            "limite_hist_id": card_ids * 10 + i,
            "cartao_id": card_ids,
            "cliente_id": cliente_ids,
            "data_referencia": data_ref.date(),
            "limite_total": limite_hist,
            "limite_disponivel_estimado": np.clip(limite_hist * rng.uniform(0.02, 0.98, size=qtd), 0, None).round(2),
            "motivo_alteracao": rng.choice(["INICIAL", "AUMENTO", "REDUCAO", "REVISAO_RISCO", "CAMPANHA"], qtd),
            "dt_ingestao": pd.Timestamp.now(),
            "origem_sistema": "SISTEMA_LIMITES",
        }))
    limites = pd.concat(limites_parts, ignore_index=True)

    next_card_id = card_id_start + qtd
    return cartoes, limites, next_card_id


def generate_purchases(
    cartoes: pd.DataFrame,
    rng: np.random.Generator,
    purchase_id_start: int,
    avg_purchases_per_card: float,
    chunk_size: int,
    part_prefix: int,
) -> int:
    if cartoes.empty:
        return purchase_id_start

    qtd = int(len(cartoes) * avg_purchases_per_card)
    generated = 0
    tx_part = 1

    cards_base = cartoes[["cartao_id", "cliente_id", "data_ativacao", "status_cartao"]].copy()
    cards_base["data_ativacao"] = pd.to_datetime(cards_base["data_ativacao"]).fillna(pd.Timestamp("2020-01-01"))

    while generated < qtd:
        n = min(chunk_size, qtd - generated)
        idx = rng.integers(0, len(cards_base), size=n)
        sampled = cards_base.iloc[idx].reset_index(drop=True)

        data_compra = random_dates_between(rng, sampled["data_ativacao"], "2026-12-31")
        data_compra = pd.to_datetime(data_compra) + pd.to_timedelta(rng.integers(0, 24 * 60 * 60, size=n), unit="s")

        valor = rng.lognormal(mean=4.7, sigma=0.9, size=n).round(2)
        valor = np.clip(valor, 5, 30000)
        valor_obj = valor.astype(object)
        valor_obj[rng.random(n) < 0.002] = None
        neg_mask = rng.random(n) < 0.001
        valor_obj[neg_mask] = -np.abs(valor[neg_mask])

        status = rng.choice(STATUS_COMPRA, n, p=[0.89, 0.045, 0.025, 0.02, 0.02])

        compras = pd.DataFrame({
            "compra_id": np.arange(purchase_id_start, purchase_id_start + n, dtype=np.int64),
            "cartao_id": sampled["cartao_id"].to_numpy(dtype=np.int64),
            "cliente_id": sampled["cliente_id"].to_numpy(dtype=np.int64),
            "data_compra": pd.Series(data_compra),
            "valor_compra": valor_obj,
            "categoria_compra": rng.choice(CATEGORIAS_COMPRA, n),
            "canal_compra": rng.choice(["PRESENCIAL", "ONLINE", "APP", "RECORRENTE", "INTERNACIONAL"], n, p=[0.42, 0.31, 0.12, 0.10, 0.05]),
            "parcelas_compra": rng.choice([1, 2, 3, 4, 6, 10, 12], n, p=[0.64, 0.08, 0.08, 0.05, 0.06, 0.05, 0.04]),
            "status_compra": status,
            "dt_ingestao": pd.Timestamp.now(),
            "origem_sistema": "AUTORIZADOR_CARTAO",
            "arquivo_origem": f"compras_cartao_part_{part_prefix:05d}_{tx_part:05d}.parquet",
        })

        dup_qtd = int(n * 0.001)
        if dup_qtd > 0:
            dup = compras.sample(dup_qtd, random_state=int(rng.integers(1, 999999))).copy()
            dup["arquivo_origem"] = f"compras_reprocessadas_part_{part_prefix:05d}_{tx_part:05d}.parquet"
            compras = pd.concat([compras, dup], ignore_index=True)

        out = OUT_COMPRAS / f"part_{part_prefix:05d}_{tx_part:05d}.parquet"
        compras.to_parquet(out, index=False)

        purchase_id_start += n
        generated += n
        print(f"    compras part {part_prefix:05d}_{tx_part:05d}: {len(compras):,} linhas".replace(",", "."))
        tx_part += 1

    return purchase_id_start


def generate_invoices_payments(
    cartoes: pd.DataFrame,
    rng: np.random.Generator,
    invoice_id_start: int,
    payment_id_start: int,
    part: int,
) -> tuple[int, int]:
    if cartoes.empty:
        return invoice_id_start, payment_id_start

    records_faturas = []
    records_pagamentos = []

    month_lists = month_range_for_card(cartoes["data_emissao"], max_months=30, rng=rng)

    for row, months in zip(cartoes.itertuples(index=False), month_lists):
        limite = pd.to_numeric(pd.Series([row.limite_concedido]), errors="coerce").fillna(1000).iloc[0]
        limite = min(max(float(limite), 300), 250000)

        for competencia in months:
            fatura_id = invoice_id_start
            invoice_id_start += 1

            uso = rng.uniform(0.03, 0.92)
            valor_fatura = round(limite * uso * rng.uniform(0.15, 0.75), 2)
            valor_fatura = max(valor_fatura, round(rng.uniform(25, 500), 2))
            valor_minimo = round(valor_fatura * rng.uniform(0.10, 0.20), 2)

            data_fechamento = competencia + pd.DateOffset(days=int(rng.integers(1, 8)))
            data_vencimento = competencia + pd.DateOffset(days=int(rng.integers(10, 25)))

            atraso = int(rng.choice([0, 0, 0, 0, 3, 7, 15, 30, 60, 90, 120], p=[0.30,0.20,0.14,0.10,0.05,0.05,0.05,0.04,0.03,0.025,0.015]))
            status_fat = "PAGA" if atraso == 0 else rng.choice(["PAGA_EM_ATRASO", "EM_ATRASO", "PARCIAL"], p=[0.58, 0.26, 0.16])

            if status_fat == "EM_ATRASO":
                data_pagamento = None
                valor_pago = round(valor_fatura * rng.uniform(0, 0.35), 2)
            elif status_fat == "PARCIAL":
                data_pagamento = (data_vencimento + pd.DateOffset(days=atraso)).date()
                valor_pago = round(valor_fatura * rng.uniform(0.10, 0.80), 2)
            else:
                data_pagamento = (data_vencimento + pd.DateOffset(days=atraso)).date()
                valor_pago = round(valor_fatura * rng.uniform(0.80, 1.05), 2)

            # Problemas simulados
            valor_fatura_obj = valor_fatura
            if rng.random() < 0.002:
                valor_fatura_obj = None
            if rng.random() < 0.001:
                valor_pago = round(valor_fatura * rng.uniform(1.2, 2.2), 2)

            flag_rotativo = bool(valor_pago < valor_fatura and valor_pago >= valor_minimo)
            flag_pagamento_minimo = bool(abs(valor_pago - valor_minimo) <= 5 or (valor_pago >= valor_minimo and valor_pago <= valor_minimo * 1.2))

            records_faturas.append({
                "fatura_id": fatura_id,
                "cartao_id": row.cartao_id,
                "cliente_id": row.cliente_id,
                "competencia": competencia.date(),
                "data_fechamento": data_fechamento.date(),
                "data_vencimento": data_vencimento.date(),
                "data_pagamento": data_pagamento,
                "valor_fatura": valor_fatura_obj,
                "valor_pago": valor_pago,
                "valor_minimo": valor_minimo,
                "dias_atraso_fatura": atraso if data_pagamento is not None else int(rng.choice([15, 30, 60, 90, 120])),
                "status_fatura": status_fat,
                "flag_rotativo": flag_rotativo,
                "flag_pagamento_minimo": flag_pagamento_minimo,
                "dt_ingestao": pd.Timestamp.now(),
                "origem_sistema": "FATURAMENTO_CARTAO",
                "arquivo_origem": f"faturas_cartao_part_{part:05d}.parquet",
            })

            if data_pagamento is not None or rng.random() < 0.20:
                records_pagamentos.append({
                    "pagamento_fatura_id": payment_id_start,
                    "fatura_id": fatura_id,
                    "cartao_id": row.cartao_id,
                    "cliente_id": row.cliente_id,
                    "data_pagamento": data_pagamento if data_pagamento is not None else (data_vencimento + pd.DateOffset(days=int(rng.integers(1, 60)))).date(),
                    "valor_pagamento": valor_pago,
                    "canal_pagamento": rng.choice(["APP", "DEBITO_CONTA", "PIX", "BOLETO", "AGENCIA"], p=[0.52, 0.19, 0.15, 0.11, 0.03]),
                    "status_pagamento": rng.choice(STATUS_PAGAMENTO, p=[0.94, 0.02, 0.025, 0.015]),
                    "dt_ingestao": pd.Timestamp.now(),
                    "origem_sistema": "PAGAMENTOS_CARTAO",
                    "arquivo_origem": f"pagamentos_fatura_part_{part:05d}.parquet",
                })
                payment_id_start += 1

    faturas = pd.DataFrame(records_faturas)
    pagamentos = pd.DataFrame(records_pagamentos)

    # Fatura órfã proposital
    orphan_qtd = max(1, int(len(faturas) * 0.001)) if len(faturas) else 0
    if orphan_qtd:
        orphan = faturas.sample(orphan_qtd, random_state=int(rng.integers(1, 999999))).copy()
        orphan["fatura_id"] = np.arange(invoice_id_start, invoice_id_start + orphan_qtd)
        orphan["cartao_id"] = orphan["cartao_id"] + 999_000_000
        orphan["arquivo_origem"] = f"faturas_orfas_part_{part:05d}.parquet"
        faturas = pd.concat([faturas, orphan], ignore_index=True)
        invoice_id_start += orphan_qtd

    faturas.to_parquet(OUT_FATURAS / f"part_{part:05d}.parquet", index=False)
    pagamentos.to_parquet(OUT_PAGAMENTOS / f"part_{part:05d}.parquet", index=False)

    print(f"    faturas part {part:05d}: {len(faturas):,} linhas".replace(",", "."))
    print(f"    pagamentos part {part:05d}: {len(pagamentos):,} linhas".replace(",", "."))

    return invoice_id_start, payment_id_start


def main() -> None:
    args = parse_args()
    assert_project_root()

    client_files = load_client_parts()
    prepare_dirs(args.overwrite)

    rng = np.random.default_rng(args.seed)
    mode_conf = MODES[args.mode]
    avg_purchases = args.avg_purchases_per_card or mode_conf["avg_purchases_per_card"]
    purchase_chunk_size = args.purchase_chunk_size or mode_conf["purchase_chunk_size"]

    next_card_id = 1
    next_purchase_id = 1
    next_invoice_id = 1
    next_payment_id = 1

    print("Aurora Bank — Gerador Bronze Cartões")
    print("=" * 70)
    print(f"Modo: {args.mode}")
    print(f"Média de compras por cartão: {avg_purchases}")
    print(f"Arquivos de clientes encontrados: {len(client_files)}")
    print("=" * 70)

    total_cards = 0

    for part, file in enumerate(client_files, start=1):
        print(f"\nLendo clientes: {file}")
        clients = pd.read_parquet(
            file,
            columns=["cliente_id", "data_cadastro", "status_cliente_core", "renda_mensal", "score_credito", "segmento_core"]
        )

        cartoes, limites, next_card_id = generate_cards_for_clients(
            clients=clients,
            rng=rng,
            card_id_start=next_card_id,
            part=part,
        )

        cartoes.to_parquet(OUT_CARTOES / f"part_{part:05d}.parquet", index=False)
        limites.to_parquet(OUT_LIMITES / f"part_{part:05d}.parquet", index=False)

        total_cards += len(cartoes)
        print(f"  cartões gerados: {len(cartoes):,}".replace(",", "."))
        print(f"  histórico de limites: {len(limites):,}".replace(",", "."))

        next_purchase_id = generate_purchases(
            cartoes=cartoes,
            rng=rng,
            purchase_id_start=next_purchase_id,
            avg_purchases_per_card=avg_purchases,
            chunk_size=purchase_chunk_size,
            part_prefix=part,
        )

        next_invoice_id, next_payment_id = generate_invoices_payments(
            cartoes=cartoes,
            rng=rng,
            invoice_id_start=next_invoice_id,
            payment_id_start=next_payment_id,
            part=part,
        )

    print("\nGeração concluída.")
    print(f"Total de cartões: {total_cards:,}".replace(",", "."))
    print("\nPróximo passo:")
    print(r"python .\scripts\06_create_bronze_silver_cartoes.py")


if __name__ == "__main__":
    main()
