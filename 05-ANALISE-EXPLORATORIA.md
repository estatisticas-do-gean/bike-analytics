# 📊 Pipeline de Análise Exploratória – Sistema +BIKE

A etapa de Análise Exploratória de Dados (Exploratory Data Analysis – EDA) é responsável por desvendar padrões, tendências e relações dentro do conjunto de dados do sistema +BIKE.

EDA **não é apenas fazer gráficos**.

EDA é um processo investigativo para compreender:

- Estrutura dos dados
- Padrões temporais
- Desequilíbrios operacionais
- Relações causais plausíveis
- Anomalias relevantes
- Hipóteses estruturais

EDA é **indutiva**.

Modelagem é **dedutiva e formal**.

> **EDA → Ponte para Predição**
> 

---

# 🎯 Objetivos

Com os dados limpos e validados, a EDA ataca dois eixos principais:

---

## 1. Diagnóstico e Compreensão do Comportamento

- Perfil demográfico
- Padrões temporais (hora, dia, mês)
- Fluxo origem–destino
- Desequilíbrios operacionais
- Evidências estruturais

---

## 2. Formalização do Problema de Predição

- Definir atraso como variável binária (> 60 min)
- Estimar probabilidade ex-ante
- Definir threshold operacional (Top 20% risco)
- Subsidiar decisões operacionais

---

# 🧭 Metodologia

A EDA foi estruturada sob quatro pilares:

1. **Análise Univariada**
2. **Análise Bivariada**
3. **Visualização Exploratória**
4. **Análise Temporal e de Rede**

Separando claramente:

✔ Fundamentação (Data Quality)

✔ Exploração (Hipóteses)

✔ Modelagem (Próxima Fase)

✔ Narrativa (Decisão)

---

## 1️⃣ Integridade Analítica e Natureza dos Missing

Antes de explorar padrões, foi necessário classificar a natureza das ausências tratadas anteriormente.

```r
# Ação 1: Remover as 56 linhas corrompidas (Violação de Regra de Negócio)
df_rides <- df_rides %>%
  filter(!( !is.na(datetime_end) & is.na(ride_duration) & is.na(ride_late) ))

# NOTA DE ANÁLISE (Ação 2):
# As 42k linhas sem datetime_end são Espacialmente Válidas, mas Temporalmente Inválidas.
# Serão mantidas, mas filtradas em análises de tempo.

# Ação 3: Investigação Missing Gênero ---
# 338 casos (<0.2%). Impacto negligenciável. Mantidos por enquanto.
```


### Tipologia de Missing Identificada

| Variável | Tipo de Missing | Natureza |
| --- | --- | --- |
| `datetime_end` | Operacional | MNAR sistêmico |
| `ride_duration` | Derivado | Dependente |
| `ride_late` | Derivado | Dependente |
| `user_gender` | Cadastro | MNAR estrutural |

---

### 🕒 Caso Crítico: datetime_end

Cerca de **15% das viagens apresentam ausência de horário de encerramento**, apesar da devolução ter sido registrada.

Esses registros são:

✔ Espacialmente válidos

❌ Temporalmente inválidos

#### Interpretação Operacional

Provável falha de sincronização:

- Dock não travou corretamente
- Validação posterior sem timestamp exato
- Evento registrado sem granularidade temporal

---

### 🔬 Decisão Metodológica

Para análise de:

- **Fluxo e rede:** utilizar essas observações
- **Duração e atraso:** removê-las obrigatoriamente

Removê-las da análise temporal evita viés.

Mantê-las na análise espacial evita subestimação de carga.

---

### ⚠ Caso Residual: 56 Observações

Subconjunto de 56 registros com inconsistência estrutural.

Representam <0,03% da base.

Impacto estatístico irrelevante.

Removidas do dataset final.

---

## 2️⃣ Engenharia de Features (Preparação Analítica)
Para que a EDA fosse efetiva e preparasse o terreno para a modelagem preditiva, os dados brutos precisaram ser traduzidos em conceitos comportamentais e físicos.

Foram criadas três frentes de features:

Demográficas (Idade): Cálculo exato via interval e categorização não-linear (buckets) para capturar riscos específicos em extremos de idade.

Geográficas (Familiaridade): Clusterização baseada na residência.

Temporais (Ciclicidade): Conversão do tempo linear em componentes trigonométricos (seno/cosseno) para capturar a continuidade entre 23h e 00h, além da extração de dias da semana e finais de semana.

```r
df_rides <- df_rides %>%
  mutate(
    # --------------------------------------------------------------------------
    # IDADE — manter sinal contínuo e permitir não-linearidade
    # --------------------------------------------------------------------------
    
    # Idade contínua (variável principal)
    user_age = as.integer(interval(user_birthdate, ride_date) / years(1)),
    
    # Versão normalizada (útil para modelos e comparações)
    user_age_scaled = as.numeric(scale(user_age)),
    
    # Buckets PROVISÓRIOS (exploratórios, não definitivos)
    # Corrigido para usar a função cut() mantendo suas faixas originais
    user_age_group_exp = cut(
      user_age,
      breaks = c(8, 18, 25, 35, 45, 55, 65, 91),
      labels = c("08–17", "18–24", "25–34", "35–44", "45–54", "55–64", "65–90"),
      right  = FALSE
    ),
    
    # --------------------------------------------------------------------------
    # GEOGRAFIA — separar informação, familiaridade e localidade
    # --------------------------------------------------------------------------
    
    # Flag simples: residência informada?
    has_residence_info = user_residence != "NAO INFORMADO",
    
    # Cluster geográfico conceitual (hipótese de familiaridade)
    geo_cluster = case_when(
      user_residence == "BRASILIA (DF)" ~ "Local (DF)",
      user_residence == "NAO INFORMADO" ~ "Não Informado",
      TRUE                              ~ "Outros / Turistas"
    ),
    
    # Versão binária útil para modelos
    is_local_df = user_residence == "BRASILIA (DF)",
    
    # --------------------------------------------------------------------------
    # TEMPO — tratar hora como fenômeno cíclico
    # --------------------------------------------------------------------------
    
    # Hora simples (EDA, gráficos, tabelas)
    hora_inicio = hour(datetime_start),
    
# Componentes cíclicos (modelagem futura)
    hora_inicio_sin = sin(2 * pi * hora_inicio / 24),
    hora_inicio_cos = cos(2 * pi * hora_inicio / 24)
  )
message("✅ Processamento concluído. Dimensões finais: ", nrow(df_rides), " linhas e" , ncol(df_rides), " colunas.")
```

---


## 3️⃣ Análise do Perfil do Usuário (O "Quem")
A análise univariada e bivariada do perfil revelou que o risco de atraso (ride_late) não está distribuído uniformemente na população. Gênero e Idade atuam como moderadores reais do risco operacional.

### 📊 Principais Descobertas:
* Idade: A maior concentração de usuários está em jovens adultos (18-34 anos). Contudo, os extremos apresentam comportamentos atípicos. Usuários na faixa de 08-17 anos e idosos (55-64 anos) possuem taxas de atraso sistematicamente maiores (podendo ultrapassar 20%).

* Gênero: Há uma predominância masculina no uso do sistema (74%), mas as mulheres tendem a fazer viagens mais longas e apresentam uma taxa de atraso média superior à dos homens.

### 💡 Insight de Modelagem:
O gênero e a idade segmentam padrões de uso distintos. Essas variáveis não podem ser ignoradas no modelo, pois capturam a vulnerabilidade do usuário perante falhas do sistema.

---

## 4️⃣ Geografia e a Descoberta da "Familiaridade"
Uma das maiores dúvidas do projeto era como lidar com os 63,9% de usuários com residência "NAO INFORMADA". A EDA revelou um padrão comportamental claro:

* Padrão de Duração: As medianas de duração de viagem dos "Locais (DF)" e dos "Não Informados" são idênticas (~12 min), com baixíssima dispersão.

* Curva Horária: Ambos os grupos apresentam picos de uso nos horários de commuting (ida e volta do trabalho).

* Curva de Risco: As taxas de atraso ao longo do dia andam "coladas".

Em contraste, os "Outros / Turistas" apresentam viagens mais longas, curvas de uso à tarde (lazer) e taxas de atraso isoladamente mais altas (~12,5% contra ~8,9% dos locais).

### ✅ Decisão Estratégica:
A variável "Não Informado" não é um missing ruidoso, mas sim uma manifestação de usuários frequentes que pularam o cadastro. Eles devem ser tratados como "Locais" na modelagem, enquanto "Turistas" formam um cluster de alto risco.

---

## 5️⃣ Padrões Temporais e Sazonalidade

A análise temporal respondeu à pergunta: **Quando o sistema falha mais?**

### O Efeito "Fim de Semana"

A descoberta mais contundente da análise temporal foi a diferença brutal entre dias úteis e finais de semana.
Enquanto em dias úteis a taxa de atraso orbita a casa dos 6% a 8% (uso funcional), nos **finais de semana o risco explode para valores entre 16% e 24%** (uso recreativo).

### Sazonalidade Mensal

O sistema sofre pressões sazonais claras. Meses de férias e feriados (Janeiro, Abril e Julho) apresentam picos de risco operacional.

> **🚦 Síntese Temporal:**
O atraso não é um ruído estocástico. É um evento previsível, altamente condicionado à janela de tempo (hora/dia) em que a viagem ocorre.

---

# 6️⃣ Diagnóstico Causal: Rede, Estações e Gargalos Físicos

A etapa final da EDA mudou o paradigma do problema. A hipótese inicial era de que o atraso fosse puramente comportamental (o usuário pedala devagar ou perde a noção do tempo). **A análise de rede provou o contrário.**

### A Dinâmica do Colapso

1. **Origem vs. Destino:** O atraso nasce majoritariamente na **DEVOLUÇÃO**. O usuário consegue retirar a bicicleta sem problemas, mas falha ao tentar devolvê-la.
2. **Desequilíbrio de Fluxo (Saldo Positivo):** Estações onde "entram mais bicicletas do que saem" (saldo positivo de fluxo) concentram as maiores taxas de atraso.
3. **Saturação Física:** Durante os picos horários (10h e 16h), estações centrais enchem completamente. Sem docas livres, o usuário não consegue encerrar a viagem.

```r
# Prova causal do Excesso de Duração
df_rides %>%
  filter(!is.na(ride_late), excesso_duracao > -5, excesso_duracao < 60) %>%
  ggplot(aes(x = excesso_duracao, fill = ride_late)) +
  geom_histogram(binwidth = 2, alpha = 0.6, position = "identity")
```
---

## **7️⃣ Padrões Temporais – Assinatura de Uso do Sistema**

A dimensão temporal revelou que o sistema +BIKE possui duas lógicas de uso distintas:

**### 🔹 Dias Úteis – Mobilidade Funcional**

* Maior volume absoluto de viagens.
* Taxa de atraso significativamente menor (~6%).
* Padrão compatível com deslocamento pendular (*commuting*).
Essas viagens apresentam horários concentrados (início do expediente e fim da tarde), menor variabilidade de duração e menor probabilidade de exceder 60 minutos. É o **uso orientado a transporte**.
****

**###  🔹 Fins de Semana – Mobilidade Recreativa**

* Volume menor que dias úteis.
* Taxa de atraso significativamente maior (~22%).
* Maior dispersão horária e maior duração média.

Aqui observamos um uso mais prolongado, maior permanência nas bicicletas e, consequentemente, **maior exposição à saturação de estações**.

🧠 **Insight Estrutural:** O risco de atraso não é homogêneo ao longo do tempo. Ele é estritamente condicionado ao contexto comportamental.
****

## **8️⃣ Perfil Demográfico – Quem Usa o Sistema?**

### **📊 Distribuição Etária**

A maior concentração de usuários está entre **25–34 anos** e **35–44 anos** (perfil predominantemente adulto jovem). A participação de usuários acima de 60 anos é marginal, porém crítica em termos de risco operacional.
****

### **🚺 Gênero como Proxy de Infraestrutura**

A proporção de mulheres no sistema é consideravelmente inferior à masculina. Em planejamento de mobilidade urbana, essa proporção é frequentemente utilizada como um indicador indireto (*proxy*) de segurança e qualidade da infraestrutura cicloviária.
Cidades com forte cultura ciclística apresentam um equilíbrio próximo de 50/50. Quando há forte predominância masculina, o sistema acusa:
* Maior percepção de risco na malha viária.
* Infraestrutura segregada insuficiente.
* Uso majoritariamente utilitário/agressivo em detrimento do recreativo/seguro.

**## 9️⃣ Fluxo Origem–Destino e Desequilíbrio Operacional**

A análise de rede e espacialidade foi o ponto de virada da EDA, revelando gargalos fixos:
✔ Estações com forte assimetria entre entradas e saídas.
✔ Concentração de devoluções em polos específicos de atração.
✔ Indícios fortes de acúmulo local de bicicletas.
****

### **📉 Cadeia Estrutural Identificada**

1. Desequilíbrio de fluxo geográfico.
2.  Acúmulo de bicicletas no destino.
3. Saturação física de vagas (*docks* ocupados).
4. Tempo adicional rodando para encontrar uma estação alternativa.
5.  **Atraso registrado.**

🔍 **Evidência Definitiva:** O atraso surge predominantemente na devolução, não na retirada. O problema é operacional, não comportamental.
****

## **🔟 Duração vs. Atraso – Separando Sintoma de Causa**

Um dos blocos mais críticos da exploração foi testar a hipótese primária: *"Viagens longas causam atraso?"*
A análise mostrou que viagens curtas quase nunca atrasam, enquanto viagens longas apresentam uma taxa de atraso superior (~19%). **Porém, a duração observada não explica o atraso.** Ela apenas registra o tempo adicional imposto ao usuário quando há uma falha sistêmica na devolução.

📌 **Conclusão Conceitual:** A duração não é causa, é consequência. O atraso não decorre primariamente de uma escolha individual do usuário, mas emerge das restrições físicas e estruturais da rede.
****

## **1️⃣1️⃣ Linha de Base para Modelagem**

Após a limpeza e validação analítica, estabelecemos a *baseline* do sistema:
📌 **~9 a 10% das viagens resultam em atraso.**
Isso define as regras do jogo para a próxima etapa:
* Temos um **problema de classificação desbalanceada**.
* A métrica de Acurácia é perigosa e inadequada (um modelo que chute "sempre no prazo" teria 90% de acurácia, mas valor de negócio zero).
* A avaliação exigirá métricas focadas na classe minoritária, como **AUC-ROC**, **Precision** e **Recall**.
****

## **1️⃣2️⃣ Transição para Modelagem: Encerramento da EDA**

A Análise Exploratória demonstrou que o atraso no sistema +BIKE:
✔ Não é ruído aleatório.
✔ Não é predominantemente erro do usuário.
✔ Está associado ao contexto temporal (Sazonalidade/Finais de semana).
✔ Emerge do desequilíbrio operacional (Saturação de docas).
A próxima etapa formaliza o problema de Machine Learning para estimar o risco ex-ante:

$$

P(\text{Atraso} = 1 \mid X)

$$

Onde $X$ inclui **apenas variáveis observáveis no momento da retirada da bicicleta**. O modelo é expressamente proibido de aprender com sintomas pós-evento (como a duração final da viagem). Ele deve aprender a mapear o **risco estrutural prévio**.
A modelagem preditiva que se segue não buscará punir o usuário por viagens longas, mas sim antecipar situações de saturação e munir a operação com inteligência de remanejamento preventivo.