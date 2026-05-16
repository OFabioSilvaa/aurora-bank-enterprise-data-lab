"""
Aurora Bank Enterprise Data Lab
Patch 03A — Gerador Bronze de Contas e Transações

Execute dentro da pasta do projeto:

    python .\scripts\03_generate_bronze_contas_transacoes.py --mode dev --overwrite

Pré-requisito:
    Ter rodado antes:
    python .\scripts\01_generate_bronze_clientes.py --mode dev --overwrite

Saídas em Parquet:
    data/bronze/raw_contas/
    data/bronze/raw_transacoes/

Observação:
    Este script cria dados fictícios/sintéticos e injeta imperfeições propositais.
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path
from datetime import datetime

import numpy as np
import pandas as pd


BRONZE_BASE = Path("data/bronze")
CLIENTES_CORE_DIR = BRONZE_BASE / "raw_clientes_core"

OUT_CONTAS = BRONZE_BASE / "raw_contas"
OUT_TRANSACOES = BRONZE_BASE / "raw_transacoes"

MODES = {
    "dev": {
        "avg_transactions_per_account": 18,
        "transaction_chunk_size": 200_000,
    },
    "lab": {
        "avg_transactions_per_account": 35,
        "transaction_chunk_size": 500_000,
    },
    "growth": {
        "avg_transactions_per_account": 45,
        "transaction_chunk_size": 1_000_000,
    },
}

TIPOS_CONTA = np.array(["CONTA_DIGITAL", "CONTA_CORRENTE", "CONTA_SALARIO", "CONTA_PAGAMENTO"])
STATUS_CONTA = np.array(["ATIVA", "INATIVA", "BLOQUEADA", "ENCERRADA", "EM_ANALISE"])
CANAIS = np.array(["APP", "SITE", "AGENCIA", "CORRESPONDENTE", "WHATSAPP", "OPEN_FINANCE", "CALL_CENTER"])
TIPOS_TRANSACAO = np.array([
    "PIX_ENVIADO", "PIX_RECEBIDO", "TED", "BOLETO_PAGO", "COMPRA_DEBITO",
    "SAQUE", "TRANSFERENCIA_INTERNA", "TARIFA", "CASHBACK", "DEPOSITO"
])
STATUS_TRANSACAO = np.array(["EFETIVADA", "CANCELADA", "NEGADA", "PENDENTE", "ESTORNADA"])
CATEGORIAS = np.array([
    "ALIMENTACAO", "TRANSPORTE", "MORADIA", "SAUDE", "EDUCACAO", "LAZER",
    "SERVICOS", "INVESTIMENTOS", "CREDITO", "TARIFAS", "OUTROS"
])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Gera dados Bronze de contas e transações.")
    parser.add_argument("--mode", choices=list(MODES.keys()), default="dev")
    parser.add_argument("--avg-transactions-per-account", type=float, default=None)
    parser.add_argument("--transaction-chunk-size", type=int, default=None)
    parser.add_argument("--seed", type=int, default=43)
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


def assert_project_root() -> None:
    if not Path("README.md").exists() or not Path("scripts").exists():
        raise SystemExit("Execute este script dentro da pasta raiz do projeto aurora_bank_enterprise_v1.")


def prepare_dirs(overwrite: bool) -> None:
    for path in [OUT_CONTAS, OUT_TRANSACOES]:
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


def generate_accounts_for_clients(
    clients: pd.DataFrame,
    rng: np.random.Generator,
    account_id_start: int,
    part: int,
) -> tuple[pd.DataFrame, int]:
    n = len(clients)
    ids = clients["cliente_id"].to_numpy(dtype=np.int64)

    status_cliente = clients["status_cliente_core"].astype(str).str.upper().to_numpy()
    prob_account = np.where(np.isin(status_cliente, ["ATIVO", "EM_ANALISE"]), 0.90, 0.55)
    has_account = rng.random(n) < prob_account

    selected = clients.loc[has_account, ["cliente_id", "data_cadastro"]].copy()
    if selected.empty:
        return pd.DataFrame(), account_id_start

    # 88% uma conta, 11% duas, 1% três
    qtd_contas = rng.choice([1, 2, 3], size=len(selected), p=[0.88, 0.11, 0.01])
    expanded = selected.loc[selected.index.repeat(qtd_contas)].reset_index(drop=True)
    qtd = len(expanded)

    conta_ids = np.arange(account_id_start, account_id_start + qtd, dtype=np.int64)

    data_abertura = random_dates_between(rng, expanded["data_cadastro"], "2026-12-31")
    status = rng.choice(STATUS_CONTA, qtd, p=[0.78, 0.08, 0.04, 0.07, 0.03])

    saldo = rng.normal(loc=1250, scale=4200, size=qtd).round(2)
    saldo = np.clip(saldo, -5000, 80000)

    # Injeta alguns saldos extremos e nulos
    saldo_obj = saldo.astype(object)
    saldo_obj[rng.random(qtd) < 0.006] = None
    mask_outlier = rng.random(qtd) < 0.001
    saldo_obj[mask_outlier] = rng.uniform(100000, 900000, size=mask_outlier.sum()).round(2)

    contas = pd.DataFrame({
        "conta_id": conta_ids,
        "cliente_id": expanded["cliente_id"].to_numpy(dtype=np.int64),
        "tipo_conta": rng.choice(TIPOS_CONTA, qtd, p=[0.68, 0.17, 0.09, 0.06]),
        "agencia": rng.integers(1, 9999, size=qtd).astype(str),
        "numero_conta": rng.integers(100000, 99999999, size=qtd).astype(str),
        "data_abertura": data_abertura,
        "data_encerramento": None,
        "status_conta": status,
        "saldo_atual": saldo_obj,
        "canal_abertura": rng.choice(CANAIS, qtd, p=[0.53, 0.16, 0.06, 0.08, 0.06, 0.04, 0.07]),
        "dt_ingestao": pd.Timestamp.now(),
        "origem_sistema": "CORE_CONTAS",
        "arquivo_origem": f"contas_part_{part:05d}.parquet",
    })

    encerrada_mask = contas["status_conta"].isin(["ENCERRADA", "INATIVA"])
    if encerrada_mask.any():
        encerramento = pd.to_datetime(contas.loc[encerrada_mask, "data_abertura"]) + pd.to_timedelta(
            rng.integers(30, 1600, size=encerrada_mask.sum()),
            unit="D"
        )
        encerramento = pd.Series(np.minimum(encerramento.values.astype("datetime64[ns]"), np.datetime64("2026-12-31"))).dt.date
        contas.loc[encerrada_mask, "data_encerramento"] = encerramento.to_numpy()

    # Injeta contas órfãs, sem cliente existente
    orphan_qtd = max(1, int(qtd * 0.0015))
    max_cliente = int(clients["cliente_id"].max())
    orphan_ids = np.arange(account_id_start + qtd, account_id_start + qtd + orphan_qtd, dtype=np.int64)
    orphan = pd.DataFrame({
        "conta_id": orphan_ids,
        "cliente_id": rng.integers(max_cliente + 10_000_000, max_cliente + 20_000_000, size=orphan_qtd),
        "tipo_conta": rng.choice(TIPOS_CONTA, orphan_qtd),
        "agencia": rng.integers(1, 9999, size=orphan_qtd).astype(str),
        "numero_conta": rng.integers(100000, 99999999, size=orphan_qtd).astype(str),
        "data_abertura": pd.Timestamp("2024-01-01").date(),
        "data_encerramento": None,
        "status_conta": "ATIVA",
        "saldo_atual": rng.normal(500, 1000, size=orphan_qtd).round(2),
        "canal_abertura": "APP",
        "dt_ingestao": pd.Timestamp.now(),
        "origem_sistema": "CORE_CONTAS",
        "arquivo_origem": f"contas_part_{part:05d}.parquet",
    })

    contas = pd.concat([contas, orphan], ignore_index=True)
    next_account_id = account_id_start + qtd + orphan_qtd

    return contas, next_account_id


def generate_transactions(
    contas: pd.DataFrame,
    rng: np.random.Generator,
    transaction_id_start: int,
    total_transactions: int,
    chunk_size: int,
    part_prefix: int,
) -> int:
    if contas.empty or total_transactions <= 0:
        return transaction_id_start

    valid_contas = contas[["conta_id", "cliente_id", "data_abertura", "status_conta"]].copy()
    valid_contas["data_abertura"] = pd.to_datetime(valid_contas["data_abertura"]).fillna(pd.Timestamp("2020-01-01"))

    generated = 0
    tx_part = 1

    while generated < total_transactions:
        n = min(chunk_size, total_transactions - generated)

        sample_idx = rng.integers(0, len(valid_contas), size=n)
        sampled = valid_contas.iloc[sample_idx].reset_index(drop=True)

        data_transacao = random_dates_between(rng, sampled["data_abertura"], "2026-12-31")
        data_transacao = pd.to_datetime(data_transacao) + pd.to_timedelta(
            rng.integers(0, 24 * 60 * 60, size=n),
            unit="s"
        )

        tipo = rng.choice(
            TIPOS_TRANSACAO,
            n,
            p=[0.30, 0.18, 0.03, 0.16, 0.15, 0.04, 0.06, 0.025, 0.015, 0.04]
        )

        valor = rng.lognormal(mean=5.45, sigma=1.05, size=n).round(2)
        valor = np.clip(valor, 1, 85000)

        # Ajusta por tipo
        valor = np.where(tipo == "TARIFA", rng.uniform(2.5, 90, size=n).round(2), valor)
        valor = np.where(tipo == "CASHBACK", rng.uniform(0.5, 80, size=n).round(2), valor)
        valor = np.where(tipo == "SAQUE", rng.uniform(20, 2500, size=n).round(2), valor)

        valor_obj = valor.astype(object)

        # Problemas simulados
        valor_obj[rng.random(n) < 0.002] = None
        mask_neg = rng.random(n) < 0.002
        valor_obj[mask_neg] = -np.abs(valor[mask_neg])

        status = rng.choice(STATUS_TRANSACAO, n, p=[0.91, 0.025, 0.025, 0.025, 0.015])

        # Algumas datas futuras por erro de origem
        future_mask = rng.random(n) < 0.001
        if future_mask.any():
            data_transacao = pd.Series(data_transacao)
            data_transacao.loc[future_mask] = pd.Timestamp("2027-01-15")

        tx_ids = np.arange(transaction_id_start, transaction_id_start + n, dtype=np.int64)

        df = pd.DataFrame({
            "transacao_id": tx_ids,
            "conta_id": sampled["conta_id"].to_numpy(dtype=np.int64),
            "cliente_id": sampled["cliente_id"].to_numpy(dtype=np.int64),
            "data_transacao": pd.Series(data_transacao),
            "tipo_transacao": tipo,
            "canal": rng.choice(CANAIS, n, p=[0.58, 0.09, 0.03, 0.05, 0.10, 0.05, 0.10]),
            "categoria_transacao": rng.choice(CATEGORIAS, n),
            "valor": valor_obj,
            "status_transacao": status,
            "descricao": [f"Transacao ficticia {t}" for t in tipo],
            "dt_ingestao": pd.Timestamp.now(),
            "origem_sistema": "CORE_TRANSACOES",
            "arquivo_origem": f"transacoes_part_{part_prefix:05d}_{tx_part:05d}.parquet",
        })

        # Duplica pequena parte para simular reprocessamento
        dup_qtd = int(n * 0.001)
        if dup_qtd > 0:
            dup = df.sample(dup_qtd, random_state=int(rng.integers(1, 999999))).copy()
            dup["arquivo_origem"] = f"transacoes_reprocessadas_part_{part_prefix:05d}_{tx_part:05d}.parquet"
            df = pd.concat([df, dup], ignore_index=True)

        out = OUT_TRANSACOES / f"part_{part_prefix:05d}_{tx_part:05d}.parquet"
        df.to_parquet(out, index=False)

        transaction_id_start += n
        generated += n
        print(f"    transações part {part_prefix:05d}_{tx_part:05d}: {len(df):,} linhas".replace(",", "."))
        tx_part += 1

    return transaction_id_start


def main() -> None:
    args = parse_args()
    assert_project_root()
    client_files = load_client_parts()

    mode_conf = MODES[args.mode]
    avg_tx = args.avg_transactions_per_account or mode_conf["avg_transactions_per_account"]
    tx_chunk_size = args.transaction_chunk_size or mode_conf["transaction_chunk_size"]

    prepare_dirs(args.overwrite)

    rng = np.random.default_rng(args.seed)
    next_account_id = 1
    next_transaction_id = 1

    print("Aurora Bank — Gerador Bronze Contas e Transações")
    print("=" * 70)
    print(f"Modo: {args.mode}")
    print(f"Média de transações por conta: {avg_tx}")
    print(f"Arquivos de clientes encontrados: {len(client_files)}")
    print("=" * 70)

    total_accounts = 0
    total_transactions_target = 0

    for part, file in enumerate(client_files, start=1):
        print(f"\nLendo clientes: {file}")
        clients = pd.read_parquet(file, columns=["cliente_id", "data_cadastro", "status_cliente_core"])

        contas, next_account_id = generate_accounts_for_clients(
            clients=clients,
            rng=rng,
            account_id_start=next_account_id,
            part=part,
        )

        contas_file = OUT_CONTAS / f"part_{part:05d}.parquet"
        contas.to_parquet(contas_file, index=False)

        qtd_accounts = len(contas)
        total_accounts += qtd_accounts

        total_tx = int(qtd_accounts * avg_tx)
        total_transactions_target += total_tx

        print(f"  contas geradas: {qtd_accounts:,}".replace(",", "."))
        print(f"  transações alvo: {total_tx:,}".replace(",", "."))

        next_transaction_id = generate_transactions(
            contas=contas,
            rng=rng,
            transaction_id_start=next_transaction_id,
            total_transactions=total_tx,
            chunk_size=tx_chunk_size,
            part_prefix=part,
        )

    print("\nGeração concluída.")
    print(f"Total de contas: {total_accounts:,}".replace(",", "."))
    print(f"Total alvo de transações, sem duplicidades de reprocessamento: {total_transactions_target:,}".replace(",", "."))
    print("\nPróximo passo:")
    print(r"python .\scripts\04_create_bronze_silver_contas_transacoes.py")


if __name__ == "__main__":
    main()
