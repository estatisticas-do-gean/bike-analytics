# ===============================================================
# SISTEMA +BIKE – FASE 1: FUNDAMENTAÇÃO E LIMPEZA DE DADOS
# ===============================================================
# Autor: Gean
# Data: 10/11/2025
# Objetivo:
#   Descobrir padrões, detectar anomalias, testar hipóteses e verificar
#   suposições através de estatísticas descritivas e técnicas de visualização
# ===============================================================

# 0. AMBIENTE E CONFIGURAÇÕES INICIAIS

# Controle de impressão e encoding
options(
  max.print = 5.5e5,   # Limite de caracteres exibidos no console
  encoding  = "UTF-8"
)

# Limpeza opcional do ambiente (útil no modo notebook)
# Ative apenas quando desejado:
# rm(list = ls(), envir = .GlobalEnv)

# Reprodutibilidade
set.seed(1234)


# ------------ Diretório seguro (boa prática) -------------------
# Evita caminhos absolutos dependentes da máquina:
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
library(here)

# now your root is dynamic and portable
root_dir <- here()
message("Diretório raiz reconhecido: ", root_dir)

# Caminhos relativos para os dados
dir_data <- here("arquivos")


# ------------ Gestão de pacotes --------------------
required_pkgs <- c(
  "tidyverse", "skimr", "DataExplorer",
  "textclean", "stringi", "forcats", "lubridate", "janitor", "forcats"
)

# Função segura que instala e carrega automaticamente
load_pkgs <- function(pkgs){
  for(p in pkgs){
    if (!requireNamespace(p, quietly = TRUE)){
      install.packages(p)
    }
    library(p, character.only = TRUE)
  }
}

load_pkgs(required_pkgs)


# ------------ Log do ambiente ---------------------------------
message("Ambiente configurado com sucesso.")
message("Versão do R: ", R.version.string)
message("Data/Hora de início: ", Sys.time())

# ----------------------------------------------------------------

###############################################################
# 1. IMPORTAÇÃO DAS BASES TRATADAS
###############################################################


# --------------------------
# Importação segura dos CSV
# --------------------------

# Função de leitura segura (boa prática)
read_csv_safe <- function(path) {
  if (!file.exists(path)) {
    stop(glue("❌ Arquivo não encontrado: {path}"))
  }
  
  read_rds(
    file = path,
    show_col_types = FALSE,
    na = c("", "NA", "N/A", "<NA>")
  ) %>% 
    clean_names()  # padroniza nomes para snake_case
}

# Lendo os arquivos
df_rides    <- read_csv_safe(here("arquivos/outputs", "df_rides_clean_20251129.rds"))
df_stations <- read_csv_safe(here("arquivos/outputs", "df_stations_clean_20251202.csv"))

# --------------------------
# Checagem estrutural inicial
# --------------------------
message("📊 Estrutura da base de viagens:")
glimpse(df_rides)

message("📍 Estrutura da base de estações:")
glimpse(df_stations)