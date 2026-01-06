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

# --- 2.3 Investigação: Missing Gênero ---
# 338 casos (<0.2%). Impacto negligenciável. Mantidos.

# ------------------------------------------------------------------------------
# 3. ENGENHARIA DE FEATURES (PREPARAÇÃO PARA ANÁLISE)
# ------------------------------------------------------------------------------
message("⚙️ Criando Variáveis Analíticas...")

df_rides <- df_rides %>%
  mutate(
    # 1. Idade Exata
    user_age = as.integer(interval(user_birthdate, ride_date) / years(1)),
    
    # 2. Faixa Etária (Business Buckets)
    user_age_group = cut(
      user_age,
      breaks = c(0, 18, 25, 35, 45, 55, 65, 100),
      labels = c("<18", "18-24", "25-34", "35-44", "45-54", "55-64", "65+"),
      right = FALSE
    ),
    
    # 3. Cluster Geográfico Simplificado (Para análises futuras)
    geo_cluster = case_when(
      user_residence == "NAO INFORMADO" ~ "Não Informado",
      user_residence == "BRASILIA (DF)" ~ "Local (DF)",
      TRUE ~ "Outros/Turistas"
    ),
    
    # 4. Hora do Dia (Para gráficos de densidade)
    hora_inicio = hour(datetime_start)
  )

# Filtro de Sanidade de Idade (8 a 90 anos)
df_rides <- df_rides %>% filter(user_age >= 8 & user_age <= 90)

# ------------------------------------------------------------------------------
# 4. ANÁLISE DO PERFIL DO USUÁRIO ("O QUEM")
# ------------------------------------------------------------------------------

# ==============================================================================
# 4.1 IDADE
# ==============================================================================

# A. Distribuição Geral (Histograma com Mediana)
p_age_hist <- ggplot(df_rides, aes(user_age)) +
  geom_histogram(binwidth = 5, fill = "#3498DB", color = "white") +
  geom_vline(aes(xintercept = median(user_age, na.rm = TRUE)), 
             color = "red", linewidth = 0.5) +
  labs(title = "Distribuição de Idade", subtitle = "Mediana indicada em vermelho",
       x = "Idade", y = "Frequência") +
  theme_minimal()

# B. Boxplot Detalhado
p_age_box <- ggplot(df_rides, aes(y = user_age)) +
  geom_boxplot(fill = "#2E86AB", color = "#1C3A59", alpha = 0.8, 
               outlier.color = "#A23B72", outlier.shape = 19) +
  geom_hline(yintercept = median(df_rides$user_age, na.rm = TRUE), 
             color = "#F18F01", linetype = "dashed") +
  labs(title = "Boxplot de Idades", x = NULL, y = "Idade") +
  theme_minimal() + 
  theme(axis.text.x = element_blank())

# C. Distribuição por Faixa Etária (Gráfico Técnico)
df_age_summary <- df_rides %>% 
  count(user_age_group) %>%
  mutate(pct = n / sum(n),
         label_text = paste0(n, "\n(", scales::percent(pct, accuracy = 0.1), ")"))

p_age_group <- ggplot(df_age_summary, aes(x = user_age_group, y = n)) +
  geom_col(fill = "#3498DB", color = "white", width = 0.7) +
  geom_text(aes(label = label_text), vjust = -0.2, size = 3) +
  scale_y_continuous(labels = scales::comma, expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Grupos Etários", x = NULL, y = "Viagens") +
  theme_bw() + theme(panel.grid.major.x = element_blank())

# Exibir Bloco Idade
print(p_age_hist)
print(p_age_box)
print(p_age_group)

# --- Interações com Idade ---

# 1. Idade x Horário (Rotina)
ggplot(df_rides, aes(x = hora_inicio, color = user_age_group, fill = user_age_group)) +
  geom_density(alpha = 0.1) +
  scale_x_continuous(breaks = seq(0, 23, 4)) +
  labs(title = "Uso por Horário e Faixa Etária", x = "Hora do Dia", y = "Densidade") +
  theme_minimal()

# 2. Idade x Duração (Eficiência vs Lazer)
df_rides %>%
  filter(ride_duration < 60) %>% 
  ggplot(aes(x = user_age_group, y = ride_duration, fill = user_age_group)) +
  geom_boxplot(alpha = 0.7, outlier.shape = NA) +
  labs(title = "Duração da Viagem por Idade", y = "Minutos", x = NULL) +
  theme_minimal() + theme(legend.position = "none")

# 3. Idade x Atraso (Risco)
df_rides %>%
  group_by(user_age_group) %>%
  summarise(taxa_atraso = mean(as.integer(ride_late), na.rm = TRUE)) %>%
  ggplot(aes(x = user_age_group, y = taxa_atraso)) +
  geom_col(fill = "#C0392B", width = 0.6) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Risco de Atraso por Idade", y = "% Atrasos") +
  theme_minimal()

# ==============================================================================
# 4.2 GÊNERO
# ==============================================================================

# A. Divisão Geral (Frequência Relativa)
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

# B. Gênero x Horário (Segurança)
# NOTA: Curvas similares indicam que não há barreira de horário específica
df_rides %>%
  filter(!is.na(user_gender)) %>%
  ggplot(aes(x = hora_inicio, color = user_gender, fill = user_gender)) +
  geom_density(alpha = 0.3) +
  scale_color_manual(values = c("F" = "#E74C3C", "M" = "#3498DB")) +
  scale_fill_manual(values = c("F" = "#E74C3C", "M" = "#3498DB")) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  labs(title = "Rotina Diária: Homens vs Mulheres", x = "Hora", y = "Densidade") +
  theme_minimal()

# C. Gênero x Duração (Comportamento)
# NOTA: Mulheres tendem a viagens levemente mais longas (Cuidado/Lazer?)
df_rides %>%
  filter(!is.na(user_gender), ride_duration < 60) %>%
  ggplot(aes(x = user_gender, y = ride_duration, fill = user_gender)) +
  geom_boxplot(alpha = 0.7, width = 0.5, outlier.shape = NA) +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 3, color = "white") +
  scale_fill_manual(values = c("F" = "#E74C3C", "M" = "#3498DB")) +
  labs(title = "Duração por Gênero", y = "Minutos") +
  theme_minimal() + theme(legend.position = "none")

# D. Pirâmide Etária (Interação Idade x Gênero)
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

# ==============================================================================
# 5. ANÁLISE GEOGRÁFICA PRELIMINAR (O "ONDE")
# ==============================================================================

# Composição Etária por Região (Geografia x Idade)
df_rides %>%
  ggplot(aes(x = user_residence, fill = user_age_group)) +
  geom_bar(position = "fill", width = 0.8) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_brewer(palette = "Blues") +
  labs(title = "Perfil Etário por Região", y = "Proporção", x = NULL) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5))



# ==============================================================================
# PRÓXIMOS PASSOS (ESTRUTURA SUGERIDA)
# ==============================================================================
# 2.3 Padrões temporais (Heatmaps, Sazonalidade)
# 2.4 Duração e atraso (Análise focada em outliers e multas)
# 2.5 Rede e estações (Fluxo Origem-Destino)
# 2.6 Síntese e hipóteses finais