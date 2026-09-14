#==============================================================================#
# Script: 01_data-preparation.R
# Autor: Mestre dos Dados (Refatorado)
# Data: 18 de Novembro
# Descrição:
#   Este script realiza o pipeline completo de Engenharia de Dados:
#   Carregamento, Auditoria, Limpeza (Cleaning), Imputação e Engenharia de
#   Features (Feature Engineering) para o dataset de bicicletas compartilhadas.
#
# Estrutura:
#   1. Configuração de Ambiente
#   2. Definição de Funções Modulares
#   3. Pipeline de Execução (Main)
#==============================================================================#

# 1. CONFIGURAÇÃO E CARREGAMENTO DE PACOTES -----------------------------------

if (!requireNamespace("pacman", quietly = TRUE)) {
  install.packages("pacman", repos = "http://cran.us.r-project.org")
}

pacman::p_load(
  tidyverse,    # Manipulação de dados (dplyr, readr, stringr)
  lubridate,    # Manipulação de datas
  textclean,    # Limpeza de texto (HTML decoding)
  stringi,      # Manipulação de strings (Acentos)
  forcats,      # Manipulação de fatores
  skimr,        # Sumarização estatística
  here          # Gerenciamento robusto de caminhos de arquivos
)

# 2. FUNÇÕES DE LIMPEZA E PREPARAÇÃO DE DADOS ---------------------------------

#' Carrega e realiza a tipagem inicial dos dados.
carregar_e_preparar_dados <- function(path_rides, path_stations) {
  message("\n[1/5] Carregando e tipando dados brutos...")
  
  if (!file.exists(path_rides) || !file.exists(path_stations)) {
    stop("ERRO: Arquivos não encontrados. Verifique os caminhos.")
  }
  
  df_rides <- read.csv(path_rides)
  df_stations <- read.csv(path_stations)
  
  # Data Wrangling Inicial: Conversão de Tipos
  df_rides <- df_rides %>%
    mutate(
      # Datas e Horas (Parsing combinando Data + Hora)
      # Nota: paste() lida com NAs gerando strings "NA", o que ymd_hms converte de volta para NA (correto)
      datetime_start = ymd_hms(paste(ride_date, time_start), quiet = TRUE),
      datetime_end   = ymd_hms(paste(ride_date, time_end), quiet = TRUE),
      
      # Conversão Explícita de Tipos
      user_birthdate = ymd(user_birthdate, quiet = TRUE),
      ride_date      = ymd(ride_date, quiet = TRUE),
      user_gender    = factor(user_gender),
      user_residence = factor(user_residence),
      station_start  = factor(station_start),
      station_end    = factor(station_end),
      ride_late      = as.logical(ride_late)
    )
  
  # Limpeza básica de estações (Trim whitespace)
  df_stations <- df_stations %>%
    mutate(station_name = trimws(station_name))
  
  return(list(df_rides = df_rides, df_stations = df_stations))
}

#' Remove registros inconsistentes de estações que não existem no cadastro.
limpar_estacoes_orfas <- function(df_rides, df_stations) {
  message("[2/5] Verificando integridade referencial (Estações Órfãs)...")
  
  valid_stations <- df_stations$station
  orphan_starts <- setdiff(unique(df_rides$station_start), valid_stations)
  orphan_ends <- setdiff(unique(df_rides$station_end), valid_stations)
  
  n_antes <- nrow(df_rides)
  
  df_rides_clean <- df_rides %>%
    filter(!(station_start %in% orphan_starts | station_end %in% orphan_ends))
  
  n_removidos <- n_antes - nrow(df_rides_clean)
  
  if (n_removidos > 0) {
    message(paste("    -> Removidos", n_removidos, "registros associados a estações de teste/inválidas."))
  } else {
    message("    -> Nenhuma estação órfã encontrada.")
  }
  
  return(df_rides_clean)
}

#' Imputa dados recuperáveis (inversão de horário) e define NAs irrecuperáveis.
imputar_duracao_e_atraso <- function(df_rides) {
  message("[3/5] Imputando dados ausentes em Duração e Atraso...")
  
  n_nas_antes <- sum(is.na(df_rides$ride_duration))
  
  df_rides_imputed <- df_rides %>%
    mutate(
      # Cálculo auxiliar da diferença bruta
      duration_calc_min = as.numeric(difftime(datetime_end, datetime_start, units = "mins")),
      
      # Lógica de Recuperação:
      # Se ride_duration é NA, tentamos recuperar usando o valor absoluto da diferença calculada.
      # Isso corrige os casos onde datetime_end < datetime_start (inversão de input).
      ride_duration = if_else(
        is.na(ride_duration),
        abs(duration_calc_min), 
        ride_duration
      ),
      
      # Regra de Negócio para Atraso:
      # Se ride_late é NA, recalculamos baseado na duração recuperada (> 60 min).
      ride_late = if_else(
        is.na(ride_late),
        ride_duration > 60,
        ride_late
      )
    ) %>%
    select(-duration_calc_min)
  
  n_nas_depois <- sum(is.na(df_rides_imputed$ride_duration))
  recuperados <- n_nas_antes - n_nas_depois
  
  message(paste("    -> Registros recuperados (Correção de Inversão):", recuperados))
  message(paste("    -> Registros irremediavelmente perdidos (Sem hora fim):", n_nas_depois))
  
  return(df_rides_imputed)
}

#' Realiza auditoria de idades e cria flag de validade, sem remover dados.
auditar_idade <- function(df_rides) {
  message("[4/5] Auditando consistência demográfica (Idades)...")
  
  cutoff_date <- as.Date("2018-08-31") # Data de referência do dataset
  
  df_rides_audit <- df_rides %>%
    mutate(
      age = as.numeric(floor(interval(user_birthdate, ride_date) / years(1))),
      
      # Flags de Auditoria
      birth_future = user_birthdate > cutoff_date,
      birth_too_old = user_birthdate < as.Date("1920-01-01"), # > ~98 anos
      birth_too_young = user_birthdate > as.Date("2010-01-01"), # < 8 anos
      birth_invalid = birth_future | birth_too_old | birth_too_young
    )
  
  n_invalidos <- sum(df_rides_audit$birth_invalid, na.rm = TRUE)
  message(paste("    -> Identificados", n_invalidos, "registros com datas de nascimento implausíveis (mantidos para análise)."))
  
  return(df_rides_audit)
}

#' Padroniza nomes de residência e consolida categorias raras.
padronizar_residencia <- function(df_rides, min_count = 200) {
  message("[5/5] Padronizando e categorizando Residência do Usuário...")
  
  df_rides_std <- df_rides %>%
    mutate(
      # 1. Limpeza Estrutural (Sanitização)
      res_temp = as.character(user_residence),
      res_temp = textclean::replace_html(res_temp),
      res_temp = str_to_upper(res_temp),
      res_temp = stringi::stri_trans_general(res_temp, "Latin-ASCII"),
      res_temp = str_trim(res_temp),
      
      # 2. Regras de Negócio (Mapeamento Explícito)
      user_residence_std = case_when(
        is.na(res_temp) ~ NA_character_,
        res_temp %in% c("XXX", "LILICAVIDA@HOTMAIL.COM", "") ~ NA_character_,
        
        # DF e Entorno
        str_detect(res_temp, "DF|BSB|BRASILIA|CEILANDIA|TAGUATINGA|SAMAMBAIA|SOBRADINHO|GAMA|PLANALTINA|AGUAS CLARAS|SANTA MARIA|RECANTO|PARANOA|ITAPOA|BRAZLANDIA|RIACHO|SEBASTIAO|P-SUL") ~ "BRASILIA (DF)",
        str_detect(res_temp, "GO|VALPARAISO|NOVO GAMA|AGUAS LINDAS|OCIDENTAL|PILAR|FORMOSA") ~ "GOIAS (GO)",
        
        # Principais Estados (Mapeamento para NOME (UF))
        res_temp %in% c("SP", "SAO PAULO") ~ "SAO PAULO (SP)",
        res_temp %in% c("RJ", "RIO DE JANEIRO") ~ "RIO DE JANEIRO (RJ)",
        res_temp %in% c("MG", "MINAS GERAIS", "BH", "BELO HORIZONTE") ~ "MINAS GERAIS (MG)",
        res_temp %in% c("BA", "BAHIA") ~ "BAHIA (BA)",
        res_temp %in% c("PE", "PERNAMBUCO") ~ "PERNAMBUCO (PE)",
        res_temp %in% c("CE", "CEARA") ~ "CEARA (CE)",
        res_temp %in% c("PA", "PARA") ~ "PARA (PA)",
        res_temp %in% c("RS", "RIO GRANDE DO SUL") ~ "RIO GRANDE DO SUL (RS)",
        res_temp %in% c("PR", "PARANA") ~ "PARANA (PR)",
        res_temp %in% c("ES", "ESPIRITO SANTO") ~ "ESPIRITO SANTO (ES)",
        
        # Siglas de 2 letras
        nchar(res_temp) == 2 ~ res_temp,
        
        # Todo o resto vira "OUTRA LOCALIDADE"
        TRUE ~ "OUTRA LOCALIDADE"
      )
    ) %>%
    
    # 3. Refinamento Estatístico (Fatores)
    mutate(
      user_residence_std = factor(user_residence_std),
      
      # Transforma NA em nível explícito para análise
      user_residence_std = fct_na_value_to_level(user_residence_std, level = "NAO INFORMADO"),
      
      # Consolida cauda longa (< 200 registros) em "OUTRA LOCALIDADE"
      # Como o case_when já usa esse nome, eles serão fundidos automaticamente.
      user_residence_std = fct_lump_min(
        user_residence_std, 
        min = min_count, 
        other_level = "OUTRA LOCALIDADE"
      ),
      
      # Feature Engineering: Flag binária
      residencia_informada = if_else(user_residence_std == "NAO INFORMADO", "NAO", "SIM"),
      residencia_informada = factor(residencia_informada)
    ) %>%
    select(-res_temp)
  
  return(df_rides_std)
}

# 3. FLUXO PRINCIPAL (MAIN) ---------------------------------------------------

main <- function() {
  message("\n=== INICIANDO PIPELINE DE PREPARAÇÃO DE DADOS ===\n")
  
  # Definir caminhos usando 'here' para reprodutibilidade
  path_rides <- here::here("arquivos", "df_rides.csv")
  path_stations <- here::here("arquivos", "df_stations.csv")
  
  # Execução do Pipeline
  dados <- carregar_e_preparar_dados(path_rides, path_stations)
  
  df_rides_final <- dados$df_rides %>%
    limpar_estacoes_orfas(dados$df_stations) %>%
    imputar_duracao_e_atraso() %>%
    auditar_idade() %>%
    padronizar_residencia(min_count = 200)
  
  # =========================================================================
  # ETAPA DE SALVAMENTO DE ARQUIVO FINAL
  # =========================================================================
  #output_path_rds <- here::here("arquivos", "df_rides_clean.rds")
  
  # Recomenda-se salvar em RDS para preservar todos os tipos de dados (Date, Factor, etc.)
  #saveRDS(df_rides_final, output_path_rds)
  
  #message("\n=== PIPELINE CONCLUÍDO COM SUCESSO ===")
  #message(paste("Arquivo final salvo em:", output_path_rds))
  #message("Para carregar na sua análise, use: readRDS(here::here('arquivos', 'df_rides_clean.rds'))")
  
  # Sumário Final (Para fins de portfólio, mostrar o resultado da limpeza)
  message("\n==================================================")
  message("LIMPEZA CONCLUÍDA. Sumário do Dataframe Final:")
  message("==================================================")
  
  print(skim(df_rides_final))
  
  return(df_rides_final)
}
################################################################################################################################################

#Configuração do diretório de trabalho

setwd("G:\\Meu Drive\\ESTATÍSTICA\\Areas\\Bacheral_UFOP\\7º_PERIODO\\Laboratorio-Supervisionado\\Sistema_+Bike")

#---------------------------------------------------------#
# Executar a função principal se o script for rodado diretamente (como deve ser)
if (sys.nframe() == 0) {
  df_rides_clean <- main()
}

summary(df_rides_clean)
