# Guia para subir o Aurora Bank no GitHub

## 1. Conferir arquivos que NÃO devem subir

Antes de subir, garanta que estes arquivos/pastas estão no `.gitignore`:

```text
database/*.duckdb
data/bronze/*
data/silver/*
data/sdx/*
data/gold/*
data/exports_excel/*
data/postgres_exports/*
*.csv
*.parquet
*.xlsx
.env
```

## 2. Entrar na pasta do projeto

```powershell
cd D:\aurora_bank\aurora_bank_enterprise_v1
```

## 3. Iniciar repositório Git

```powershell
git init
```

## 4. Verificar arquivos

```powershell
git status
```

## 5. Adicionar arquivos

```powershell
git add .
```

## 6. Criar commit

```powershell
git commit -m "feat: add Aurora Bank Enterprise Data Lab V1"
```

## 7. Criar repositório no GitHub

Sugestão de nome:

```text
aurora-bank-enterprise-data-lab
```

## 8. Conectar repositório local ao GitHub

Troque `SEU_USUARIO` pelo seu usuário do GitHub:

```powershell
git remote add origin https://github.com/SEU_USUARIO/aurora-bank-enterprise-data-lab.git
```

## 9. Subir para o GitHub

```powershell
git branch -M main
git push -u origin main
```

## 10. Verificar no GitHub

Depois de subir, abra o repositório no navegador e confira:

- README aparecendo corretamente;
- imagens carregando;
- scripts SQL visíveis;
- pasta `docs/` organizada;
- dados pesados não foram enviados.
