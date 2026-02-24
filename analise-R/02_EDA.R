# ==============================================================================
# SISTEMA +BIKE – FASE 2: ANÁLISE EXPLORATÓRIA DE DADOS (EDA)
# ==============================================================================
# Autor: Gean Gabriel
# Data: 10/12/2025
# Objetivo: Descobrir padrões, detectar anomalias, testar hipóteses (Perfil/Uso)
# ==============================================================================
# Limpeza opcional do ambiente
# rm(list = ls(), envir = .GlobalEnv)

# ------------------------------------------------------------------------------
# 0. AMBIENTE E CONFIGURAÇÕES INICIAIS
# ------------------------------------------------------------------------------

# Controle de impressão e encoding
options(max.print = 5.5e5, encoding = "UTF-8")

# Reprodutibilidade
set.seed(1234)

# Gestão de Diretórios e Pacotes
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
library(here)

# Caminhos
dir_data <- here("arquivos")
root_dir <- here()

# Pacotes
required_pkgs <- c("tidyverse", "skimr", "DataExplorer", "janitor", 
                   "lubridate", "forcats", "naniar", "scales", "patchwork")

load_pkgs <- function(pkgs){
  for(p in pkgs){
    if (!requireNamespace(p, quietly = TRUE)) install.packages(p)
    library(p, character.only = TRUE)
  }
}
load_pkgs(required_pkgs)

message("✅ Ambiente configurado. R Version: ", R.version.string)

# ------------------------------------------------------------------------------
# 1. IMPORTAÇÃO E LEITURA SEGURA (ETL)
# ------------------------------------------------------------------------------

read_data_safe <- function(path) {
  if (!file.exists(path)) stop(glue::glue("❌ Arquivo não encontrado: {path}"))
  
  ext <- tools::file_ext(path)
  if (ext == "rds") {
    data <- read_rds(file = path)
  } else if (ext == "csv") {
    data <- read_csv(file = path, show_col_types = FALSE, na = c("", "NA", "N/A", "<NA>"))
  } else {
    stop("❌ Formato não suportado.")
  }
  return(clean_names(data))
}

# Carregamento
df_rides    <- read_data_safe(here("arquivos/outputs", "df_rides_clean_20251129.rds"))
df_stations <- read_data_safe(here("arquivos/outputs", "df_stations_clean_20251202.rds"))

# Checagem Rápida
# glimpse(df_rides)
# skim(df_rides)

# ------------------------------------------------------------------------------
# 2. AUDITORIA DE QUALIDADE DE DADOS
# ------------------------------------------------------------------------------

# --- 2.1 Investigação: Missing Semântico (Residência) ---
message("🔍 Auditando Residência...")

# Validação de 'NAO INFORMADO' como categoria válida
# miss_var_summary(df_rides %>% select(user_residence_raw, user_residence))

# NOTA DE ANÁLISE:
# O problema de missing (63%) é estrutural do sistema, não erro de ETL.
# A padronização reduziu a cardinalidade de 231 para 15 categorias úteis.

# Ação: Remover coluna bruta antiga
df_rides <- df_rides %>% select(-user_residence_raw)

# --- 2.2 Investigação: Missing Técnico (Fim da Viagem) ---
message("🔍 Auditando Timestamps...")

# Diagnóstico dos 3 grupos de dados:
# 1. Dados Completos
# 2. Dados Fantasmas (42k): Têm estação fim, mas sem hora fim.
# 3. Dados Corrompidos (56): Têm hora fim, mas sem duração.

# Ação 1: Remover as 56 linhas corrompidas (Violação de Regra de Negócio)
df_rides <- df_rides %>%
  filter(!( !is.na(datetime_end) & is.na(ride_duration) & is.na(ride_late) ))

# Ação 2: Diagnóstico das 42.239 linhas "Sem Fim"
# df_rides %>% filter(is.na(datetime_end)) %>% count(station_end, sort = TRUE)

# NOTA DE ANÁLISE:
# As 42k linhas são Espacialmente Válidas (sabemos origem e destino), 
# mas Temporalmente Inválidas. Serão mantidas, mas filtradas em análises de tempo.

# Ação 3: Investigação Missing Gênero ---
# 338 casos (<0.2%). Impacto negligenciável. Mantidos por enquanto.

# ------------------------------------------------------------------------------
# 3. ENGENHARIA DE FEATURES (PREPARAÇÃO ANALÍTICA APRIMORADA)
# ------------------------------------------------------------------------------
message("⚙️ Criando Variáveis Analíticas (versão analítica avançada)...")

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
    user_age_group_exp = case_when(
      user_age >= 8  & user_age <= 17 ~ "08–17",
      user_age >= 18 & user_age <= 24 ~ "18–24",
      user_age >= 25 & user_age <= 34 ~ "25–34",
      user_age >= 35 & user_age <= 44 ~ "35–44",
      user_age >= 45 & user_age <= 54 ~ "45–54",
      user_age >= 55 & user_age <= 64 ~ "55–64",
      user_age >= 65 & user_age <= 90 ~ "65–90",
      TRUE ~ NA_character_
    ),
    
    # --------------------------------------------------------------------------
    #  GEOGRAFIA — separar informação, familiaridade e localidade
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
    #  TEMPO — tratar hora como fenômeno cíclico
    # --------------------------------------------------------------------------
    
    # Hora simples (EDA, gráficos, tabelas)
    hora_inicio = hour(datetime_start),
    
    # Componentes cíclicos (modelagem futura)
    hora_inicio_sin = sin(2 * pi * hora_inicio / 24),
    hora_inicio_cos = cos(2 * pi * hora_inicio / 24)
      )

# Idade
df_rides %>%
  summarise(
    n = n(),
    na_age = sum(is.na(user_age)),
    na_age_group = sum(is.na(user_age_group_exp))
  )

  

# --------------------------------------------------------------------------
#  FILTRO DE SANIDADE BIOLÓGICA 
# --------------------------------------------------------------------------
df_rides <- df_rides %>%
  filter(user_age >= 8 & user_age <= 90)

# Atraso
df_rides %>%
  count(ride_late)

# ------------------------------------------------------------------------------
# 4. ANÁLISE DO PERFIL DO USUÁRIO ("O QUEM")
# ------------------------------------------------------------------------------

# ==============================================================================
#  IDADE
# ==============================================================================

# Estatísticas descritivas da idade
df_rides %>%
  summarise(
    n = n(),
    idade_media   = mean(user_age, na.rm = TRUE),
    idade_mediana = median(user_age, na.rm = TRUE),
    idade_sd      = sd(user_age, na.rm = TRUE),
    idade_min     = min(user_age, na.rm = TRUE),
    idade_q1      = quantile(user_age, 0.25, na.rm = TRUE),
    idade_q3      = quantile(user_age, 0.75, na.rm = TRUE),
    idade_max     = max(user_age, na.rm = TRUE)
  )


# Distribuição da idade (histograma)
ggplot(df_rides, aes(x = user_age)) +
  geom_histogram(
    binwidth = 2,
    fill = "#3498DB",
    color = "white"
  ) +
  geom_vline(
    xintercept = mean(df_rides$user_age, na.rm = TRUE),
    color = "#E74C3C",
    linewidth = 0.6
  ) +
  geom_vline(
    xintercept = median(df_rides$user_age, na.rm = TRUE),
    color = "#2C3E50",
    linetype = "dashed",
    linewidth = 0.6
  ) +
  labs(
    title = "Distribuição de Idade dos Usuários",
    subtitle = "Linha vermelha = média | Linha tracejada = mediana",
    x = "Idade",
    y = "Número de Viagens"
  ) +
  theme_minimal()

# Boxplot (dispersão e assimetria)
ggplot(df_rides, aes(y = user_age)) +
  geom_boxplot(
    fill = "#2E86AB",
    color = "#1C3A59",
    alpha = 0.8,
    outlier.alpha = 0.2
  ) +
  labs(
    title = "Boxplot da Idade dos Usuários",
    y = "Idade"
  ) +
  theme_minimal()
# * Apesar da mediana em 25 anos, a média levemente maior sugere cauda à direita,
# * indicando usuários mais velhos com menor frequência,
# * mas impacto relevante na distribuição.

# Faixas etárias
df_rides %>%
  filter(!is.na(user_age_group_exp)) %>%
  count(user_age_group_exp) %>%
  mutate(pct = n / sum(n)) %>%
  ggplot(aes(x = user_age_group_exp, y = n)) +
  geom_col(fill = "#3498DB", width = 0.7) +
  geom_text(
    aes(label = scales::percent(pct, accuracy = 0.1)),
    vjust = -0.3,
    size = 3
  ) +
  scale_y_continuous(labels = scales::comma,
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Distribuição por Faixa Etária",
    subtitle = "Maior concentração em jovens adultos",
    x = "Faixa Etária",
    y = "Número de Viagens"
  ) +
  theme_minimal()

#  Idade x Taxa de Atraso (Risco Operacional)
df_rides %>%
  filter(!is.na(user_age_group_exp)) %>% # Filtra antes
  group_by(user_age_group_exp) %>%
  summarise(
    total = n(),
    atrasos = sum(ride_late, na.rm = TRUE),
    taxa_atraso = mean(ride_late, na.rm = TRUE)
  ) %>%
  ggplot(aes(x = user_age_group_exp, y = taxa_atraso)) +
  geom_col(aes(fill = taxa_atraso > mean(df_rides$ride_late, na.rm=TRUE)), width = 0.7) +
  geom_hline(yintercept = mean(df_rides$ride_late, na.rm=TRUE), linetype = "dashed", color = "gray40") +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_manual(values = c("FALSE" = "gray70", "TRUE" = "#E74C3C"), labels = c("Abaixo da Média", "Acima da Média")) +
  labs(
    title = "Quem gera mais multas por atraso?",
    subtitle = "Linha tracejada = Média Geral do Sistema",
    x = "Faixa Etária",
    y = "% de Viagens Atrasadas",
    fill = "Risco"
  ) +
  theme_minimal()


# Idade × tipo de uso
df_rides %>%
  mutate(
    periodo = case_when(
      hora_inicio %in% 8:11  ~ "Pico Manhã",
      hora_inicio %in% 15:18 ~ "Pico Tarde",
      TRUE ~ "Fora do Pico"
    )
  ) %>%
  group_by(user_age_group_exp, periodo) %>%
  summarise(n = n(), .groups = "drop") %>%
  ggplot(aes(x = user_age_group_exp, y = n, fill = periodo)) +
  geom_col(position = "fill") +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Faixa Etária × Tipo de Uso (proxy por horário)",
    y = "Proporção"
  ) +
  theme_minimal()


# Interação: Idade x Duração (focando em viagens < 60min para limpar ruído)
df_rides %>%
  filter(ride_duration < 60, !is.na(user_age_group_exp)) %>%
  ggplot(aes(x = user_age_group_exp, y = ride_duration, fill = user_age_group_exp)) +
  geom_boxplot(alpha = 0.7, outlier.shape = NA) +
  # Adiciona média para ver se descola da mediana
  stat_summary(fun = mean, geom = "point", shape = 18, size = 3, color = "black") +
  labs(
    title = "Duração mediana por faixa etária",
    y = "Duração (min)",
    x = "Faixa Etária"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

# A idade entra melhor no modelo como contínua ou em buckets?
#df_rides %>%
#  filter(!is.na(ride_late)) %>%
#  ggplot(aes(x = user_age, y = ride_late)) +
#  geom_jitter(alpha = 0.05, height = 0.02, color = "#C0392B") +
#  labs(
#    title = "Atraso vs Idade (visão contínua)",
#    x = "Idade",
#    y = "Atraso? (FALSE = não, TRUE = sim)"
#  ) +
#  theme_minimal()
# * Para qualquer idade observada,
# * existem viagens com atraso e sem atraso em proporções semelhantes

# ==============================================================================
#  GÊNERO
# ==============================================================================

# Divisão Geral (Frequência Relativa)
df_rides %>%
  filter(!is.na(user_gender)) %>%
  count(user_gender) %>%
  mutate(pct = n / sum(n), label = scales::percent(pct, accuracy = 0.1)) %>%
  ggplot(aes(x = user_gender, y = n, fill = user_gender)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = label), vjust = -0.5, fontface = "bold") +
  scale_fill_manual(values = c("F" = "#E74C3C", "M" = "#3498DB")) +
  labs(title = "Divisão por Gênero", subtitle = "Predominância Masculina (74%)", 
       x = "Gênero", y = "Viagens") +
  theme_minimal()

# Gênero x Horário (Segurança)
df_rides %>%
  filter(!is.na(user_gender)) %>%
  ggplot(aes(x = hora_inicio, color = user_gender, fill = user_gender)) +
  geom_density(alpha = 0.3) +
  scale_color_manual(values = c("F" = "#E74C3C", "M" = "#3498DB")) +
  scale_fill_manual(values = c("F" = "#E74C3C", "M" = "#3498DB")) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  labs(title = "Rotina Diária: Homens vs Mulheres", x = "Hora", y = "Densidade") +
  theme_minimal()
# * Curvas similares indicam que não há barreira de horário específica
# * Não há evidência forte de restrição temporal feminina no uso do sistema.

# Gênero x Duração (Comportamento)
df_rides %>%
  filter(!is.na(user_gender), ride_duration < 60) %>%
  ggplot(aes(x = user_gender, y = ride_duration, fill = user_gender)) +
  geom_boxplot(alpha = 0.7, width = 0.5, outlier.shape = NA) +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 3, color = "white") +
  scale_fill_manual(values = c("F" = "#E74C3C", "M" = "#3498DB")) +
  labs(title = "Duração por Gênero", y = "Minutos") +
  theme_minimal() + theme(legend.position = "none")

# * Mulheres tendem a viagens mais longas (Cuidado/Lazer?)

# Pirâmide Etária (Interação Idade x Gênero)
ggplot(df_rides, aes(x = user_age, fill = user_gender)) +
  geom_histogram(data = subset(df_rides, user_gender == "F"), 
                 aes(y = after_stat(count)), binwidth = 2, alpha = 0.7) +
  geom_histogram(data = subset(df_rides, user_gender == "M"), 
                 aes(y = -after_stat(count)), binwidth = 2, alpha = 0.7) +
  coord_flip() +
  scale_y_continuous(labels = abs) +
  scale_fill_manual(values = c("F" = "#E74C3C", "M" = "#3498DB")) +
  labs(title = "Pirâmide Etária", x = "Idade", y = "Usuários", fill = "Gênero") +
  theme_minimal()
# * Distribuições etárias semelhantes
# * Diferença maior é volume, não forma

# Gênero × Atraso (a pergunta de negócio central)
df_rides %>%
  filter(!is.na(user_gender), !is.na(ride_late)) %>%
  group_by(user_gender) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late, na.rm = TRUE)
  )

df_rides %>%
  filter(!is.na(user_gender), !is.na(ride_late)) %>%
  group_by(user_gender) %>%
  summarise(taxa_atraso = mean(ride_late)) %>%
  ggplot(aes(x = user_gender, y = taxa_atraso, fill = user_gender)) +
  geom_col(width = 0.6) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_manual(values = c("F" = "#E74C3C", "M" = "#3498DB")) +
  labs(
    title = "Taxa de Atraso por Gênero",
    y = "% de Atrasos",
    x = "Gênero"
  ) +
  theme_minimal()
# * O gênero está associado ao atraso, mas não é causal isolado
# * O feminino tende a atrasar mais que o masculino

# Gênero × horário × atraso (interação simples, alto valor)
df_rides %>%
  filter(!is.na(user_gender), !is.na(ride_late)) %>%
  group_by(user_gender, hora_inicio) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = hora_inicio, y = taxa_atraso, color = user_gender)) +
  geom_line(linewidth = 0.8) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  labs(
    title = "Risco de Atraso ao Longo do Dia por Gênero",
    x = "Hora",
    y = "% de Atrasos"
  ) +
  theme_minimal()
# * Entre 6h e 22h, as curvas são: paralelas, estáveis, com risco entre ~7% e 20%.
# * Nos horários 0h–5h, aparecem picos absurdos (50%–100%). baixíssimo volume, altamente instáveis,(não devem orientar decisões de negócio)
# * O comportamento “normal” do sistema ocorre entre 6h e 22h.

# Gênero × idade × atraso (última checagem)
df_rides %>%
  filter(!is.na(user_gender), !is.na(ride_late)) %>%
  group_by(user_gender, user_age_group_exp) %>%
  summarise(taxa_atraso = mean(ride_late, na.rm=T), .groups = "drop") %>%
  ggplot(aes(x = user_age_group_exp, y = taxa_atraso, fill = user_gender)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_manual(values = c("F" = "#E74C3C", "M" = "#3498DB")) +
  labs(
    title = "Taxa de Atraso por Idade e Gênero",
    x = "Faixa Etária",
    y = "% de Atrasos"
  ) +
  theme_minimal()
# * Diferenças grandes na maioria grupos → gênero é moderador real 
# * gênero segmenta padrões de uso, esses padrões têm consequências operacionais mensuráveis.
# * mulheres de 55-64 anos possuem taxa de atraso > 20%, enquanto os homens < 10%.

## 

# ==============================================================================
#  GEOGRAFIA/RESIDENCIA
# ==============================================================================

# Residência dos Usuários
ggplot(df_rides, aes(x = fct_infreq(user_residence))) +
  geom_bar(fill = "gray70") +
  geom_bar(
    data = subset(df_rides, user_residence == "NAO INFORMADO"),
    fill = "#E74C3C"
  ) +
  labs(
    title = "Distribuição da Variável user_residence_std",
    subtitle = "A barra vermelha indica volume de dados não informados (~63%)",
    x = "Residência (Agrupada)",
    y = "Número de Viagens"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
## * A maior dúvida era: Quem são os 63,9% que não informaram residência?

# Perfil geográfico entre registros válidos
df_rides%>%
  filter(user_residence != "NAO INFORMADO") %>%
  ggplot(aes(x = fct_infreq(user_residence))) +
  geom_bar(fill = "steelblue") +
  geom_text(stat = 'count', aes(label = after_stat(count)),
            vjust = -0.5, size = 3) +
  labs(
    title = "Perfil Geográfico dos Usuários Identificados",
    subtitle = "Distribuição entre localidades válidas (37% dos registros)",
    x = "Residência (Agrupada)",
    y = "Total de Viagens"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
## * Depois do DF, a maior origem é Goiás (GO) com 3.355 viagens. Isso confirma o uso pendular (moram no entorno, trabalham no DF)

# Composição Etária por Região (Geografia x Idade)
df_rides %>%
  ggplot(aes(x = user_residence, fill = user_age_group_exp)) +
  geom_bar(position = "fill", width = 0.8) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_brewer(palette = "Blues") +
  labs(title = "Perfil Etário por Região", y = "Proporção", x = NULL) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5))
# * Residência está capturando vínculo com a cidade, não localização física pontual.

# Frequência por cluster geográfico
df_rides %>%
  count(geo_cluster) %>%
  mutate(pct = n / sum(n)) %>%
  ggplot(aes(x = geo_cluster, y = n, fill = geo_cluster)) +
  geom_col(width = 0.7) +
  geom_text(
    aes(label = scales::percent(pct, accuracy = 0.1)),
    vjust = -0.3,
    size = 3
  ) +
  scale_y_continuous(labels = scales::comma,
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title = "Distribuição de Usuários por Residência",
    x = NULL,
    y = "Número de Viagens"
  ) +
  theme_minimal() +
  theme(legend.position = "none")
# > geo_cluster ≈ familiaridade operacional com o sistema

# Residência × Duração (familiaridade em ação)
df_rides %>%
  filter(ride_duration < 60) %>%
  ggplot(aes(x = geo_cluster, y = ride_duration, fill = geo_cluster)) +
  geom_boxplot(alpha = 0.7, outlier.shape = NA) +
  labs(
    title = "Duração da Viagem por Tipo de Residência",
    x = NULL,
    y = "Minutos"
  ) +
  theme_minimal() +
  theme(legend.position = "none")
# * Locais (DF) → viagens mais curtas e concentradas
# * Não Informado → é quase idêntica à vermelha, a mediana é baixa (~12 min) e a dispersão é pequena.
# * Outros / Turistas → maior dispersão e medianas mais altas

# > Familiaridade reduz risco de atraso

##> Tratar “Não Informado” como Local é defensável
##> Isso reduz ruído, melhora poder estatístico e evita que o modelo aprenda “ausência de dado” como padrão espúrio.

# Residência × Horário (uso funcional vs recreativo)
df_rides %>%
  ggplot(aes(x = hora_inicio, fill = geo_cluster)) +
  geom_density(alpha = 0.25) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  labs(
    title = "Padrões Horários por Residência",
    x = "Hora do Dia",
    y = "Densidade"
  ) +
  theme_minimal()
# * a curva azul é baixa pela manhã e sobe suavemente até um pico no final da tarde (16h-18h), típico de quem está passeando
# * O grupo "Não Informado" NÃO é ruído. São residentes locais que apenas pularam o cadastro.

# Residência × Atraso (pergunta de negócio direta)
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(geo_cluster) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  )

df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(geo_cluster) %>%
  summarise(taxa_atraso = mean(ride_late)) %>%
  ggplot(aes(x = geo_cluster, y = taxa_atraso, fill = geo_cluster)) +
  geom_col(width = 0.6) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Taxa de Atraso por Tipo de Residência",
    x = NULL,
    y = "% de Atrasos"
  ) +
  theme_minimal() +
  theme(legend.position = "none")
# * Turistas são os que mais atrasam a devolução (12,5% de atrasos vs 8,9% dos locais)
# * → feature altamente preditiva
# apesar de que 11.429 registros são turistas

# Residência × Idade × Atraso (interação crítica)
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(geo_cluster, user_age_group_exp) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = user_age_group_exp, y = taxa_atraso, fill = geo_cluster)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Taxa de Atraso por Idade e Residência",
    x = "Faixa Etária",
    y = "% de Atrasos"
  ) +
  theme_minimal()
# * A faixa 08–17 anos tem altas taxas de atraso em todos os grupos (>10%). Falta de responsabilidade financeira ou desconhecimento das regras.
# * Usuários idosos que não informaram residência têm uma taxa de atraso explosiva (>23%).
# * Residência não é proxy de idade
# → elas trazem informação complementar, não redundante


#Residência × Horário × Atraso
#Turistas atrasam mais em qualquer horário, ou só fora do pico?
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(geo_cluster, hora_inicio) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(hora_inicio, taxa_atraso, color = geo_cluster)) +
  geom_line(linewidth = 0.8) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Risco de Atraso por Hora e Residência",
    x = "Hora",
    y = "% de Atrasos"
  ) +
  theme_minimal()
# * Quase todas as viagens iniciadas de madrugada estouram o tempo limite.
##> A linha Vermelha (Local DF) e a linha Verde (Não Informado) andam praticamente coladas.
##> Elas sobem juntas às 10h, descem juntas às 13h e sobem juntas às 16h.
##> Isso enterra qualquer dúvida restante. O perfil de risco de quem não informa o endereço é idêntico ao do residente do DF. Eles são a mesma "persona".
##> Entre 09h e 18h (horário comercial/turístico), a linha Azul (Turistas) se descola para cima.
##> Enquanto os locais mantêm uma taxa de atraso controlada (~5-10%), os turistas sobem para ~15-20%.
##> Para todos os grupos, o risco de atraso não é linear. Existem dois picos claros durante o dia:
  ##>  Pico das 10h: Talvez usuários que perdem a hora do trabalho ou entregas matinais?
  ##>   Pico das 16h: Fim de tarde. Lazer misturado com saída do trabalho. É o momento crítico para mandar notificações de "Seu tempo está acabando".

df_rides %>%
  count(geo_cluster, user_age_group_exp)

# Heatmap: Onde está a massa de usuários?
df_rides %>%
  count(geo_cluster, user_age_group_exp) %>%
  ggplot(aes(x = user_age_group_exp, y = geo_cluster, fill = n)) +
  geom_tile() +
  geom_text(aes(label = scales::number(n, big.mark = ".", accuracy = 1)), 
            color = "white", size = 3.5, fontface = "bold") +
  scale_fill_viridis_c(option = "turbo", direction = -1) + # Cor escura = mais gente
  labs(
    title = "Matriz de Densidade: Idade x Residência",
    subtitle = "O 'calor' mostra que o público massivo 'Não Informado' é Jovem (18-24)",
    x = "Faixa Etária",
    y = "Cluster Geográfico",
    fill = "Viagens"
  ) +
  theme_minimal()
##> O "Não Informado" é, na verdade, o Jovem
##> O usuário mais velho (veja as faixas 35+) tende a preencher o cadastro com mais frequência proporcionalmente.


#✅ “Não Informado” → tratar como Local

#✅ “Outros” → manter como cluster comportamental

#✅ Idade é variável crítica (com efeitos não lineares)

#⚠️ Idosos + Não Informado = risco sistêmico, não comportamental

#✅ Atraso não é aleatório — é explicável e previsível

# ==============================================================================
#  PADRÕES TEMPORAIS (hora, dia, ciclo semanal, mensal)
# ==============================================================================
# Quando o sistema falha mais?

# Criar variáveis temporais
df_rides <- df_rides %>%
  mutate(
    weekday = wday(ride_date, label = TRUE, week_start = 1),
    is_weekend = weekday %in% c("sáb", "dom"),
    month = month(ride_date, label = TRUE)
  )

summary(df_rides$weekday) 
summary(df_rides$is_weekend) #60408
summary(df_rides$month)

# Atraso x Dia da semana
# O sistema falha mais em dias úteis ou no fim de semana?
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(weekday) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = weekday, y = taxa_atraso)) +
  geom_col(fill = "#3498DB", width = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Taxa de Atraso por Dia da Semana",
    subtitle = "Diferença entre uso funcional e recreativo",
    x = "Dia da Semana",
    y = "% de Atrasos"
  ) +
  theme_minimal()

##> Atraso ligado a uso recreativo / turistas
##> Fim de Semana + atrasos
##> 
# Fim de semana x Dia útil
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(is_weekend) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  )
# Qual a diferença em atrasos em dia útil ou fim de semana?
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(is_weekend) %>%
  summarise(taxa_atraso = mean(ride_late)) %>%
  ggplot(aes(x = is_weekend, y = taxa_atraso, fill = is_weekend)) +
  geom_col(width = 0.6) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_discrete(labels = c("FALSE" = "Dia Útil", "TRUE" = "Fim de Semana")) +
  labs(
    title = "Risco de Atraso: Dia Útil vs Fim de Semana",
    x = NULL,
    y = "% de Atrasos"
  ) +
  theme_minimal() +
  theme(legend.position = "none")
##> Fim de Semana tende a ter risco de atrasos até 3x maiores
##> Diferença grande → atraso contextual, não aleatório

# Atraso ao longo do dia
# Existe “hora crítica” de atraso?
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(hora_inicio) %>%
  summarise(
    taxa_atraso = mean(ride_late),
    viagens = n(),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = hora_inicio, y = taxa_atraso)) +
  geom_line(linewidth = 0.9, color = "#E74C3C") +
  geom_point(size = 2) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  labs(
    title = "Risco de Atraso ao Longo do Dia",
    x = "Hora",
    y = "% de Atrasos"
  ) +
  theme_minimal()
##> picos às 10h e 16h; uso estável das 5h às 23h
##> madrugadas chances absurdas de atrasos
##> 

# Interação crítica: hora × fim de semana
#O risco horário muda quando é fim de semana?
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(is_weekend, hora_inicio) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = hora_inicio, y = taxa_atraso, color = is_weekend)) +
  geom_line(linewidth = 0.9) +
  scale_color_manual(
    values = c("FALSE" = "#3498DB", "TRUE" = "#E67E22"),
    labels = c("Dia Útil", "Fim de Semana")
  ) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  labs(
    title = "Risco de Atraso por Hora e Tipo de Dia",
    x = "Hora",
    y = "% de Atrasos",
    color = "Tipo de Dia"
  ) +
  theme_minimal()
##> como visto o risco aumenta muito nos fim de semana
##> em qualquer hora do dia, especialmente em picos

# Volume de viagens por mês
# O sistema muda de perfil ao longo do ano?
df_rides %>%
  group_by(month) %>%
  summarise(
    viagens = n(),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = month, y = viagens)) +
  geom_col(fill = "#95A5A6", width = 0.7) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Volume de Viagens por Mês",
    subtitle = "Jan–Ago 2018",
    x = "Mês",
    y = "Número de Viagens"
  ) +
  theme_minimal()
##> Crescimento de Jan → Ago (maior adesão,clima mais favorável, maturação do sistema)
##> Isso afeta atraso: mais usuários ≠ mais eficiência.

# Taxa de atraso por mês
# Agora sim: o risco muda ao longo do ano?
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(month) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = month, y = taxa_atraso)) +
  geom_col(fill = "#E74C3C", width = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Taxa de Atraso por Mês",
    subtitle = "Sazonalidade de risco operacional",
    x = "Mês",
    y = "% de Atrasos"
  ) +
  theme_minimal()
##> maiores riscos de atrasos: jan, abr, jul...
##> 

# Mês × fim de semana
# O atraso alto no fim de semana é constante ou sazonal?
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(month, is_weekend) %>%
  summarise(
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = month, y = taxa_atraso, fill = is_weekend)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_manual(
    values = c("FALSE" = "#3498DB", "TRUE" = "#E67E22"),
    labels = c("Dia Útil", "Fim de Semana")
  ) +
  labs(
    title = "Taxa de Atraso por Mês e Tipo de Dia",
    x = "Mês",
    y = "% de Atrasos",
    fill = "Tipo de Dia"
  ) +
  theme_minimal()
##> Em dias úteis os atrasos são quase iguais em todos os meses ~6%,8%
##> no fim de semana, em todos os atrasos ~16%,24%
##> atraso é comportamental
##> 

# Hora × mês
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(month, hora_inicio) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = hora_inicio, y = taxa_atraso, color = month)) +
  geom_line(linewidth = 0.8) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(0, 23, 4)) +
  labs(
    title = "Risco de Atraso por Hora ao Longo dos Meses",
    x = "Hora",
    y = "% de Atrasos",
    color = "Mês"
  ) +
  theme_minimal()
##> O padrão horário é estável; o que muda é a intensidade do risco
##> abr e jul concentra as viagens 'problema da madrugada'

## 🚦 Atraso não é ruído — é evento previsível condicionado ao tempo.

# ==============================================================================
#  REDE E ESTAÇÕES 
# ==============================================================================
# Existem “estações problema” recorrentes?
#skim(df_stations)
#skim(df_rides)

# Estações e atrasos
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_start) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  filter(viagens >= 500) %>%  # sanidade estatística
  arrange(desc(taxa_atraso)) %>%
  print(n=15)

# Taxa de atraso por estação de saída
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_start) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  filter(viagens >= 500) %>%
  ggplot(aes(x = fct_reorder(station_start, taxa_atraso),
             y = taxa_atraso)) +
  geom_col(fill = "#E74C3C") +
  coord_flip() +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Estações com Maior Taxa de Atraso (Origem)",
    x = "Estação",
    y = "% de Atrasos"
  ) +
  theme_minimal()
##> Algumas estações concentram atrasos independentemente de quem usa

# Taxa de atraso por estação de chegada
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_end) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  filter(viagens >= 500) %>%
  arrange(desc(taxa_atraso)) %>%
  print(n=15)

df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_end) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  filter(viagens >= 500) %>%
  ggplot(aes(x = fct_reorder(station_end, taxa_atraso),
             y = taxa_atraso)) +
  geom_col(fill = "#E67E22") +
  coord_flip() +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Estações com Maior Taxa de Atraso (Destino)",
    x = "Estação",
    y = "% de Atrasos"
  ) +
  theme_minimal()

# Taxa de atraso por par de estações
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_start, station_end) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  filter(viagens >= 200) %>%
  arrange(desc(taxa_atraso)) %>%
  print(n=15)

# Volume total
# Estações centrais sofrem mais pressão?
df_rides %>%
  count(station_start, name = "saida") %>%
  full_join(
    df_rides %>% count(station_end, name = "entrada"),
    by = c("station_start" = "station_end")
  ) %>%
  mutate(
    saida = replace_na(saida, 0),
    entrada = replace_na(entrada, 0),
    fluxo_total = saida + entrada
  ) %>%
  arrange(desc(fluxo_total)) %>%
  print(n=15)
##> Existem gargalos fixos na rede, não eventos esporádicos. 
##> 

# fluxo x atrasos
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_end) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  left_join(
    df_rides %>% count(station_end, name = "entrada"),
    by = "station_end"
  ) %>%
  ggplot(aes(x = entrada, y = taxa_atraso)) +
  geom_point(alpha = 0.6) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Volume da Estação × Taxa de Atraso (Destino)",
    x = "Número de Chegadas",
    y = "% de Atrasos"
  ) +
  theme_minimal()

# Estação x Horário
# O problema muda no tempo?
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_end, hora_inicio) %>%
  summarise(
    taxa_atraso = mean(ride_late),
    viagens = n(),
    .groups = "drop"
  ) %>%
  filter(viagens >= 100) %>%
  print(n=15)


# O atraso nasce quando o usuário pega a bike ou quando tenta devolver?

top_stations <- c(
  "15 - Brasil 21",
  "4 - Torre de TV",
  "16 - SRTVS",
  "5 - Setor Hoteleiro Norte",
  "32 - SQS 305",
  "12 - Rodoviária 3"
)

# Retirada x Devolução
df_blocA <- df_rides %>%
  filter(
    !is.na(ride_late),
    station_start %in% top_stations |
      station_end %in% top_stations
  ) %>%
  mutate(
    tipo_risco = case_when(
      station_end %in% top_stations ~ "Devolução",
      station_start %in% top_stations ~ "Retirada"
    )
  )
# Resultado agregado
df_blocA %>%
  group_by(tipo_risco) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  )
##> O atraso nasce majoritariamente na DEVOLUÇÃO

# Separar problema de RETIRADA vs DEVOLUÇÃO
df_blocA %>%
  group_by(tipo_risco) %>%
  summarise(taxa_atraso = mean(ride_late)) %>%
  ggplot(aes(x = tipo_risco, y = taxa_atraso, fill = tipo_risco)) +
  geom_col(width = 0.6) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Onde o Atraso se Origina?",
    subtitle = "Comparação entre Retirada e Devolução em Estações Críticas",
    x = NULL,
    y = "% de Atrasos"
  ) +
  theme_minimal() +
  theme(legend.position = "none")
##> O usuário até consegue pegar a bike,
##> mas não consegue devolver onde quer.
##>

# Todas as estações sofrem do mesmo problema?
df_blocA %>%
  group_by(station = if_else(
    tipo_risco == "Devolução", station_end, station_start
  ), tipo_risco) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  ggplot(aes(
    x = fct_reorder(station, taxa_atraso),
    y = taxa_atraso,
    fill = tipo_risco
  )) +
  geom_col(position = "dodge") +
  coord_flip() +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Retirada vs Devolução — Diagnóstico por Estação",
    x = "Estação",
    y = "% de Atrasos",
    fill = "Tipo de Risco"
  ) +
  theme_minimal()
##> sim
##> 

# Fluxo x Atrasos
df_rides %>%
  filter(!is.na(ride_late),
         station_start %in% top_stations |
           station_end %in% top_stations) %>%
  group_by(estacao = if_else(station_end %in% top_stations,
                             "Destino",
                             "Origem")) %>%
  summarise(taxa_atraso = mean(ride_late))
##> gargalo de docas
##> 

# As estações com alta taxa de atraso são aquelas onde entra muito mais bike do que sai (ou o contrário)?

# Construir métricas de fluxo por estação
df_fluxo <- df_rides %>%
  count(station_start, name = "saidas") %>%
  full_join(
    df_rides %>% count(station_end, name = "entradas"),
    by = c("station_start" = "station_end")
  ) %>%
  mutate(
    saidas   = replace_na(saidas, 0),
    entradas = replace_na(entradas, 0),
    fluxo_total = saidas + entradas,
    saldo_fluxo = entradas - saidas
  )
print(df_fluxo)

# fluxo com atraso (diagnóstico causal)
df_fluxo_atraso <- df_fluxo %>%
  left_join(
    df_rides %>%
      filter(!is.na(ride_late)) %>%
      group_by(station_end) %>%
      summarise(
        taxa_atraso = mean(ride_late),
        .groups = "drop"
      ),
    by = c("station_start" = "station_end")
  )
print(df_fluxo_atraso)

# saldo × atraso
ggplot(df_fluxo_atraso, aes(x = saldo_fluxo, y = taxa_atraso)) +
  geom_point(alpha = 0.7) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Desequilíbrio de Fluxo × Taxa de Atraso",
    subtitle = "Estações que acumulam bikes apresentam mais atraso",
    x = "Saldo de Fluxo (Entradas − Saídas)",
    y = "% de Atrasos"
  ) +
  theme_minimal()
##> lado direito (saldo positivo) → taxas de atraso maiores
##> lado esquerdo → atraso menor e mais estável 
##> padrão não linear → sinal de saturação física

##> O atraso é consequência direta do acúmulo de bicicletas em estações específicas.
##> Não é uso excessivo em geral — é desequilíbrio espacial da rede.

# Ranking: estações estruturalmente problemáticas
df_fluxo_atraso %>%
  arrange(desc(saldo_fluxo)) %>%
  select(
    station_start,
    entradas,
    saidas,
    saldo_fluxo,
    taxa_atraso
  ) %>%
  print(n = 15)


# O acúmulo acontece o dia inteiro ou em horários específicos?
# Fluxo por horário (refinamento temporal)
df_rides %>%
  group_by(station_end, hora_inicio) %>%
  summarise(
    entradas = n(),
    taxa_atraso = mean(ride_late, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(entradas >= 100) %>%
  ggplot(aes(x = hora_inicio, y = taxa_atraso)) +
  geom_line(color = "#E74C3C") +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Acúmulo Horário e Atraso por Estação",
    subtitle = "O risco cresce quando o fluxo se concentra",
    x = "Hora",
    y = "% de Atrasos"
  ) +
  theme_minimal()

##> Em estações centrais: 
##> Taxa de atraso sobe em janelas específicas 
##> Coincide com picos de chegada
##> Confirma lógica de pressão momentânea

##> O sistema entra em colapso local quando: muita gente chega, poucas bikes saem, capacidade física é ultrapassada

## O usuário não causa o atraso —
# ele é exposto a estações problemáticas.

# Quem está mais exposto às estações problemáticas?

# Definir “estações críticas”
stations_criticas <- df_fluxo_atraso %>%
  filter(
    saldo_fluxo > quantile(saldo_fluxo, 0.75, na.rm = TRUE),
    taxa_atraso > quantile(taxa_atraso, 0.75, na.rm = TRUE)
  ) %>%
  pull(station_start)

# Usuário exposto a estação crítica
df_rides <- df_rides %>%
  mutate(
    estacao_critica = station_end %in% stations_criticas
  )

# Exposição por perfil (quem cai mais nessas estações)
#Residência × exposição
df_rides %>%
  group_by(geo_cluster) %>%
  summarise(
    viagens = n(),
    pct_estacao_critica = mean(estacao_critica),
    .groups = "drop"
  )

# Idade x exposição
df_rides %>%
  filter(!is.na(user_age_group_exp)) %>%
  group_by(user_age_group_exp) %>%
  summarise(
    viagens = n(),
    pct_estacao_critica = mean(estacao_critica),
    .groups = "drop"
  )

# Gênero x exposição
df_rides %>%
  filter(!is.na(user_gender)) %>%
  group_by(user_gender) %>%
  summarise(
    viagens = n(),
    pct_estacao_critica = mean(estacao_critica),
    .groups = "drop"
  )
# Taxa de atraso: estação crítica x normal
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(estacao_critica) %>%
  summarise(
    taxa_atraso = mean(ride_late),
    viagens = n(),
    .groups = "drop"
  )

# Quem sofre MAIS dentro das estações críticas?

# Residência × atraso (condicional)
df_rides %>%
  filter(estacao_critica, !is.na(ride_late)) %>%
  group_by(geo_cluster) %>%
  summarise(
    taxa_atraso = mean(ride_late),
    viagens = n(),
    .groups = "drop"
  )

# Idade × atraso (condicional)
df_rides %>%
  filter(estacao_critica, !is.na(ride_late), !is.na(user_age_group_exp)) %>%
  group_by(user_age_group_exp) %>%
  summarise(
    taxa_atraso = mean(ride_late),
    viagens = n(),
    .groups = "drop"
  )
##> O sistema pune quem menos conhece a rede
##>  ou menos consegue reagir ao erro operacional
##> 

# Perfil × tipo de dia × estação crítica
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(geo_cluster, is_weekend, estacao_critica) %>%
  summarise(
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  ggplot(aes(
    x = estacao_critica,
    y = taxa_atraso,
    fill = geo_cluster
  )) +
  geom_col(position = "dodge") +
  facet_wrap(~ is_weekend, labeller = as_labeller(c(
    "FALSE" = "Dia Útil",
    "TRUE" = "Fim de Semana"
  ))) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Quem Sofre com Estações Críticas?",
    subtitle = "O impacto explode para turistas no fim de semana",
    x = "Estação Crítica",
    y = "% de Atrasos",
    fill = "Perfil"
  ) +
  theme_minimal()
##> O mesmo gargalo estrutural se torna muito mais severo no fim de semana.

# Quanto tempo extra o usuário fica rodando até achar vaga?
# Distribuição de duração: atrasados vs não atrasados
# 
df_rides %>%
  filter(!is.na(ride_late), ride_duration < 120) %>%  # corta extremos
  ggplot(aes(x = ride_duration, fill = ride_late)) +
  geom_histogram(binwidth = 2, alpha = 0.6, position = "identity") +
  scale_fill_manual(
    values = c("FALSE" = "#3498DB", "TRUE" = "#E74C3C"),
    labels = c("No prazo", "Atrasado")
  ) +
  labs(
    title = "Distribuição da Duração da Viagem",
    subtitle = "Atraso não é simplesmente viagem longa",
    x = "Duração (min)",
    y = "Número de Viagens",
    fill = "Status"
  ) +
  theme_minimal()

#estatísticas
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(ride_late) %>%
  summarise(
    n = n(),
    dur_mediana = median(ride_duration, na.rm = TRUE),
    dur_q3 = quantile(ride_duration, 0.75, na.rm = TRUE),
    .groups = "drop"
  )

# Se a devolução falha, o tempo extra aparece no final da viagem
# diferença entre duração observada e duração típica
# Calcular duração típica por estação de origem + hora
duracao_referencia <- df_rides %>%
  filter(!is.na(ride_duration)) %>%
  group_by(station_start, hora_inicio) %>%
  summarise(
    dur_mediana_ref = median(ride_duration),
    .groups = "drop"
  )

# Calcular excesso de duração
df_rides <- df_rides %>%
  left_join(duracao_referencia,
            by = c("station_start", "hora_inicio")) %>%
  mutate(
    excesso_duracao = ride_duration - dur_mediana_ref
  )

# Excesso de duração × atraso (prova causal)
df_rides %>%
  filter(!is.na(ride_late), excesso_duracao > -5, excesso_duracao < 60) %>%
  ggplot(aes(x = excesso_duracao, fill = ride_late)) +
  geom_histogram(binwidth = 2, alpha = 0.6, position = "identity") +
  scale_fill_manual(
    values = c("FALSE" = "#3498DB", "TRUE" = "#E74C3C")
  ) +
  labs(
    title = "Excesso de Duração da Viagem",
    subtitle = "O atraso nasce no tempo extra, não no pedal",
    x = "Minutos além do esperado",
    y = "Viagens",
    fill = "Atraso"
  ) +
  theme_minimal()
#> Um limiar operacional
#> Atraso é consequência de falha na devolução, não de comportamento do usuário


# Quanto tempo extra o usuário perde?
df_rides %>%
  filter(ride_late, excesso_duracao > 0) %>%
  summarise(
    mediana_extra = median(excesso_duracao, na.rm = TRUE),
    p75_extra = quantile(excesso_duracao, 0.75, na.rm = TRUE),
    p90_extra = quantile(excesso_duracao, 0.90, na.rm = TRUE)
  )
#> Isso é tempo perdido, não lazer
#> 

# Quem perde MAIS tempo? (impacto humano)

# Por residência
df_rides %>%
  filter(ride_late, excesso_duracao > 0) %>%
  group_by(geo_cluster) %>%
  summarise(
    mediana_extra = median(excesso_duracao),
    .groups = "drop"
  )

# Por idade
df_rides %>%
  filter(ride_late, excesso_duracao > 0, !is.na(user_age_group_exp)) %>%
  group_by(user_age_group_exp) %>%
  summarise(
    mediana_extra = median(excesso_duracao),
    .groups = "drop"
  )
##> O problema não é quem perde mais tempo
##> É quem cai mais vezes no problema

# Ligação final com estações críticas
df_rides %>%
  filter(ride_late, excesso_duracao > 0) %>%
  group_by(estacao_critica) %>%
  summarise(
    mediana_extra = median(excesso_duracao),
    p75_extra = quantile(excesso_duracao, 0.75),
    .groups = "drop"
  )
##> O atraso não é pedalar mais.
##> É tempo improdutivo no final, procurando vaga.
##> 
##> Esse é um limiar operacional claro: após ~15–20 minutos extras, o atraso se torna praticamente inevitável.

#>>> Síntese Causal
#→ Desequilíbrio de fluxo
#→ Acúmulo de bikes
#→ Saturação de docas
#→ Falha na devolução
#→ Tempo extra improdutivo
#→ Atraso
#→ Impacto desigual em perfis vulneráveis
#→ Amplificação em fins de semana

# ==============================================================================
# fim
# ==============================================================================


