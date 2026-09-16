# ==============================================================================
# SISTEMA +BIKE – FASE 3: ANÁLISE PREDITIVA
# ==============================================================================
# Autor: Gean Gabriel
# Data: 10/12/2025
# Objetivo: Identificar possíveis atrasos de usuários antes da corrida ser iniciada.
# ==============================================================================

# 0. AMBIENTE E CONFIGURAÇÕES INICIAIS -----------------------------------------

# Controle de impressão e encoding
options(max.print = 5.5e5, encoding = "UTF-8")

# Reprodutibilidade
set.seed(1234)

# Gestão de Diretórios e Pacotes
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
library(here)

if (!require("pacman")) install.packages("pacman")
pacman::p_load(
  tidyverse, skimr, DataExplorer, janitor, 
  lubridate, forcats, naniar, scales, patchwork, glue
)

# Caminhos
dir_data <- here("arquivos")
root_dir <- here()

message("✅ Ambiente configurado. R Version: ", R.version.string)

# 1. FUNÇÕES AUXILIARES -------------------------------------------

read_data_safe <- function(path) {
  if (!file.exists(path)) stop(glue::glue("❌ Arquivo não encontrado: {path}"))
  
  ext <- tools::file_ext(path)
  data <- if (ext == "rds") {
    read_rds(file = path)
  } else if (ext == "csv") {
    read_csv(file = path, show_col_types = FALSE, na = c("", "NA", "N/A", "<NA>"))
  } else {
    stop("❌ Formato não suportado.")
  }
  return(clean_names(data))
}

# 2. IMPORTAÇÃO E AUDITORIA DE QUALIDADE ---------------------------------------

# Carregamento
df_rides    <- read_data_safe(here("arquivos/outputs", "df_rides_eda_20260226.rds"))
df_stations <- read_data_safe(here("arquivos/outputs", "df_stations_eda_20260226.rds"))

dim(df_rides)
glimpse(df_rides)
sum(is.na(df_rides)) 

df_rides %>%
  summarise(
    across(
      everything(),
      ~ sum(is.na(.x))
    )
  ) %>%
  pivot_longer(
    cols = everything(),
    names_to = "variavel",
    values_to = "n_na"
  ) %>%
  mutate(
    percentual_na = n_na / nrow(df_rides) * 100
  ) %>%
  arrange(desc(percentual_na))
#numericas
df_rides %>%
  select(where(is.numeric)) %>%
  summary()
#categoricas
df_rides %>%
  select(where(~ is.character(.x) || is.factor(.x))) %>%
  summarise(
    across(
      everything(),
      ~ n_distinct(.x, na.rm = TRUE)
    )
  ) %>%
  pivot_longer(
    everything(),
    names_to = "variavel",
    values_to = "n_niveis"
  ) %>%
  arrange(desc(n_niveis))

df_rides %>%
  count(ride_late) %>%
  mutate(
    percentual = n / sum(n) * 100
  )

df_rides %>%
  summarise(
    n = n(),
    positivos = sum(ride_late, na.rm = TRUE),
    taxa = mean(ride_late, na.rm = TRUE)
  )

df_rides %>%
  summarise(
    across(
      everything(),
      ~ n_distinct(.x, na.rm = TRUE)
    )
  ) %>%
  pivot_longer(
    everything(),
    names_to = "variavel",
    values_to = "n_unicos"
  ) %>%
  arrange(desc(n_unicos))

df_rides %>%
  summarise(
    across(
      everything(),
      ~ n_distinct(.x, na.rm = TRUE)
    )
  ) %>%
  pivot_longer(
    everything(),
    names_to = "variavel",
    values_to = "n_unicos"
  ) %>%
  filter(n_unicos <= 1)
