# 🚲 Sistema +BIKE: Otimização Operacional e Preditiva

Uma abordagem estatística para otimização logística e previsão de churn involuntário em sistemas de *bike-sharing*.

---

## 🧠 Contexto Pessoal e Acadêmico

Destaco este projeto como um dos trabalhos acadêmicos mais significativos que desenvolvi.
A análise do sistema **BIKE+** foi uma **“consultoria simulada”**, proposta pelo excelente professor da disciplina **EST020 - Laboratório Supervisionado (7º período da graduação em Estatística)**.

O desafio foi resolvido **como se estivéssemos atuando profissionalmente**, com **poucas instruções diretas**, demandando autonomia total.

Este projeto é **didático e detalhado de forma excessiva** — não por acaso. É o **primeiro que compartilho no GitHub** (ainda estou aprendendo a usar a plataforma) e sou naturalmente **perfeccionista** (reformulando o que está pronto).

Os próximos repositórios terão uma abordagem mais objetiva e profissional, mas acredito que este formato possa **ajudar outras pessoas** a entender todo o processo envolvido em transformar **dados brutos em informação útil** — o que, por sinal, consome bastante tempo.

> 🎯 Meu objetivo inicial com este projeto é demonstrar que sei o que estou fazendo,
> e que estou pronto para gerar resultados mensuráveis que possam, de alguma forma, **ajudar a sociedade (e conseguir um emprego!)**.

---

## 📊 Visão Geral do Projeto

A **+BIKE** enfrenta desafios operacionais devido à falta de inteligência analítica sobre sua base de usuários.  
O sistema sofre com desequilíbrio logístico e um ponto de atrito crítico: **viagens que excedem 60 minutos**, gerando **cobranças surpresa e insatisfação**.

Este projeto aplica **técnicas de Ciência de Dados e Estatística** para transformar dados brutos em decisões estratégicas.

---

## 🎯 Objetivos Principais

1. **Diagnóstico Operacional**
   - Mapear quem usa, como usa e onde estão os gargalos logísticos.

2. **Modelagem Preditiva**
   - Desenvolver um algoritmo capaz de calcular, no momento da retirada,
     a probabilidade de uma viagem exceder o tempo limite (Atraso > 60 min).

---

## 🗂 Estrutura do Repositório

A documentação foi desenhada para garantir **reprodutibilidade e rastreabilidade**, seguindo o ciclo de vida dos dados:

| Arquivo | Descrição | Status |
|----------|------------|--------|
| `00-PROBLEMA.md` | Definição técnica do problema, escopo e restrições de negócio (RFP). | ✅ Concluído |
| `01-ESTRUTURA_DADOS.md` | Dicionário de dados, schema e diagnóstico inicial de qualidade. | ✅ Concluído |
| `03-PLANO.md` | Planejamento metodológico e estratégia estatística. | ✅ Concluído |
| `04-LIMPEZA_DADOS.md` | Relatório de Engenharia de Dados (Recuperação e Sanitização). | ✅ Concluído |
| `05-ANALISE-EXPLORATORIA.md` | EDA: Teste de hipóteses e descoberta de padrões. | 🚧 Em andamento |

---

## 🔧 Metodologia e Tech Stack

O projeto segue um fluxo adaptado do **CRISP-DM**, com foco rigoroso na **validação dos dados antes da modelagem**.

**Principais tecnologias:**
- 🧮 R (tidyverse ecosystem)
- 📘 Documentação em Quarto / Markdown
- 💾 Controle de Versão com Git & GitHub

---

## 💡 Destaques da Engenharia de Dados (Fase 1)

Antes de qualquer modelagem, foi realizado um processo de **sanitização forense** dos dados (`04-LIMPEZA_DADOS.md`), resultando em:

- 🧩 **Recuperação de dados críticos:**
  Identificação de erro de inversão temporal que permitiu **recuperar 29.886 registros** que seriam descartados.

- 👶 **Validade biológica:**
  Remoção de **2,9%** da base contendo idades impossíveis (ex: nascidos em 2028).

- 🔍 **Tratamento de missing values:**
  Estratégia de *explicitação* para os **62%** de dados demográficos ausentes,  
  transformando ausência em categoria analítica interpretável.

> “Limpar dados não é apagar erros,
> é **interpretar vestígios** para maximizar a informação disponível.”

---

## 🚀 Como Reproduzir

Este projeto foi construído para ser totalmente **reprodutível**.

### 1️⃣ Clone o repositório:
```bash
git clone https://github.com/estatisticas-do-gean/sistema-bike.git
```
2️⃣ Abra o projeto no RStudio:

Clique no arquivo Sistema_+Bike.Rproj

3️⃣ Instale as dependências:

Os scripts verificam e instalam os pacotes automaticamente via pacman.

4️⃣ Execute o pipeline de limpeza:

Abra e rode o script principal:

```r
source("analise-R/01_data_cleaning.R")
```
5️⃣ Explore os relatórios:
Abra os arquivos `.md` na pasta raiz para acompanhar cada etapa da análise.

---

⚠️ Sobre os Dados

Os dados utilizados foram detalhados e analisados conforme o projeto documenta,
porém não são fornecidos neste repositório por questões de confidencialidade.
Quem precisar, pode entrar em contato diretamente.

✉️ Contato

👤 Gean Gabriel
📊 Estatístico & Analista & Cientista de Dados
📧 Gean.estatisticas@gmail.com
🌐 ---

> “Transformar dados em decisões é mais do que técnica — é responsabilidade.”

---
---

