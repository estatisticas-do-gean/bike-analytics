# ===============================================================
# SISTEMA +BIKE – FASE 1: FUNDAMENTAÇÃO E LIMPEZA DE DADOS
# ===============================================================
# Autor: Gean
# Data: 10/11/2025
# Objetivo:
#   Diagnosticar, validar e limpar as bases de viagens e estações
#   antes da análise exploratória (FASE 2 - EDA)
# ===============================================================

# ---------------------------------------------------------------
# 0. AMBIENTE E CONFIGURAÇÕES INICIAIS
# ---------------------------------------------------------------

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


###############################################################
# 1. IMPORTAÇÃO DAS BASES
###############################################################
# --------------------------
# Importação segura dos CSV
# --------------------------

# Função de leitura segura (boa prática)
read_csv_safe <- function(path) {
  if (!file.exists(path)) {
    stop(glue("❌ Arquivo não encontrado: {path}"))
  }
  
  read_csv(
    file = path,
    show_col_types = FALSE,
    na = c("", "NA", "N/A", "<NA>")
  ) %>% 
    clean_names()  # padroniza nomes para snake_case
}

# Lendo os arquivos
df_rides    <- read_csv_safe(here("arquivos", "df_rides.csv"))
df_stations <- read_csv_safe(here("arquivos", "df_stations.csv"))

# --------------------------
# Checagem estrutural inicial
# --------------------------
message("📊 Estrutura da base de viagens:")
glimpse(df_rides)

message("📍 Estrutura da base de estações:")
glimpse(df_stations)


###############################################################
# 2. PADRONIZAÇÃO E TIPAGEM DA BASE DE VIAGENS 
###############################################################

message("\n🛠 Convertendo colunas para tipos adequados...")

# --------------------------
# Parsing de datas / DATETIME
# --------------------------

df_rides_clean <- df_rides %>%
  mutate(
    # Datas puras
    ride_date      = ymd(ride_date, quiet = TRUE),
    user_birthdate = ymd(user_birthdate, quiet = TRUE),
    
    # DateTimes: combinação segura + verificação de NA
    datetime_start = ymd_hms(paste(ride_date, time_start), quiet = TRUE),
    datetime_end   = ymd_hms(paste(ride_date, time_end),   quiet = TRUE),
    
    # Categóricas
    user_gender    = as_factor(user_gender),
    user_residence = as_factor(user_residence),
    station_start  = as_factor(station_start),
    station_end    = as_factor(station_end),
    
    # Flags booleanas
    ride_late      = as.logical(ride_late)
  )
# --------------------------
# Diagnóstico pós-transformação
# --------------------------

failed_start <- sum(is.na(df_rides_clean$datetime_start))
failed_end   <- sum(is.na(df_rides_clean$datetime_end))

message(glue("\n⏱ Falhas de parsing de datetime_start: {failed_start}"))
message(glue("⏱ Falhas de parsing de datetime_end:   {failed_end}"))

if (failed_start > 0 | failed_end > 0) {
  message("⚠ Atenção: há falhas de parsing — verifique time_start/time_end.")
}

glimpse(df_rides_clean)


###############################################################
# 3. LIMPEZA E AUDITORIA DA BASE DE ESTAÇÕES 
###############################################################

df_stations_clean <- df_stations %>%
  clean_names() %>%   # padroniza nomes: station_name -> station_name
  mutate(
    station_name = station_name |> 
      trimws() |> 
      str_squish() |>  # remove múltiplos espaços
      stri_trans_general("Latin-ASCII")  # remove acentos
  )

message("🔍 Auditoria: verificando duplicações nome ↔ número...")

# Verificar duplicações entre código e nome
dup_codes <- df_stations_clean %>%
  count(station_number) %>%
  filter(n > 1)

dup_names <- df_stations_clean %>%
  count(station_name) %>%
  filter(n > 1)

if (nrow(dup_codes) == 0 & nrow(dup_names) == 0) {
  message("✔ Estrutura 1–1 válida entre código e nome.")
} else {
  message("⚠ Atenção: foram detectadas duplicações!")
  print(dup_codes)
  print(dup_names)
}

# Diagnóstico final da tabela
skim(df_stations_clean)

# o dataframe das estações esta completo

rm(dup_codes, dup_names)

###############################################################
# 4. SUMARIZAÇÃO INICIAL E DIAGNÓSTICO DE COMPLETUDE
###############################################################

message("\n📊 Visão geral da base de viagens:")

summary(df_rides_clean)
skim(df_rides_clean)

# Colunas com mais NA
na_rank <- df_rides_clean %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(everything(), names_to = "variavel", values_to = "na_count") %>%
  arrange(desc(na_count))

message("\n🔎 Ranking de variáveis com mais NA:")
print(na_rank, n = 20)

# Visualização de Ausência
plot_missing(
  df_rides_clean,
  group = list(Good = 0.05, OK = 0.40, Bad = 0.70)
)
rm(na_rank)

###############################################################
# 5. INTEGRIDADE RELACIONAL – ESTAÇÕES ÓRFÃS
###############################################################
# Objetivo:
# - Verificar se station_start e station_end existem na tabela
#   de referência df_stations_clean
# - Remover viagens ligadas a estações inexistentes

# Lista das estações válidas
valid_stations <- df_stations_clean$station

# Estações presentes em rides mas ausentes na referência
orphan_starts <- setdiff(unique(df_rides_clean$station_start), valid_stations)
orphan_ends   <- setdiff(unique(df_rides_clean$station_end), valid_stations)

# Quantificação dos registros inválidos
n_orphan_rides <- df_rides_clean %>%
  filter(station_start %in% orphan_starts |
           station_end   %in% orphan_ends) %>%
  nrow()

message("Número de viagens com estações órfãs identificadas: ", n_orphan_rides)

# Remoção das inconsistências
df_rides_clean <- df_rides_clean %>%
  filter(!(station_start %in% orphan_starts |
             station_end   %in% orphan_ends))

message("Registros removidos: ", n_orphan_rides)
message("Integridade relacional restabelecida com sucesso.")



###############################################################
# 6. AUDITORIA BIOLÓGICA – DATAS DE NASCIMENTO (VERSÃO CORRIGIDA)
###############################################################
# Correção aplicada:
# - user_birthdate agora é parseado com fallback automático via parse_date_time()
# - idade é calculada somente quando ambas as datas são válidas
# - flags nunca retornam NA
# - relatório sempre retorna números válidos

message("\n🧪 Iniciando auditoria biológica das datas de nascimento...")

# ===============================================================
# 6.0 — Padronização ROBUSTA das datas de nascimento
# ===============================================================
# Esta abordagem corrige automaticamente:
#  - formatos mistos ("YYYY-MM-DD", "DD/MM/YYYY", "MM/DD/YYYY")
#  - datas inválidas representadas por strings

df_rides_clean <- df_rides_clean %>%
  mutate(
    user_birthdate = suppressWarnings(
      parse_date_time(
        user_birthdate,
        orders = c("ymd", "dmy", "mdy"),
        exact = FALSE
      )
    )
  )

# ===============================================================
# 6.1 — Parâmetros da auditoria
# ===============================================================
MIN_AGE    <- 8
MAX_AGE    <- 100
CUTOFF_DATE <- max(df_rides_clean$ride_date, na.rm = TRUE)

# ===============================================================
# 6.2 — Cálculo da idade + indicadores de inconsistência
# ===============================================================
df_audit <- df_rides_clean %>%
  mutate(
    # cálculo seguro: retorna NA apenas se birthdate ou ride_date forem NA
    age = floor(interval(user_birthdate, ride_date) / years(1)),
    
    birth_missing   = is.na(user_birthdate),
    birth_future    = !birth_missing & user_birthdate > CUTOFF_DATE,
    birth_too_young = !birth_missing & !is.na(age) & age < MIN_AGE,
    birth_too_old   = !birth_missing & !is.na(age) & age > MAX_AGE,
    
    # Flag consolidada (nunca NA)
    birth_invalid   =  birth_future | birth_too_young | birth_too_old
  )

# ===============================================================
# 6.3 — Relatório final
# ===============================================================
audit_report <- df_audit %>%
  summarise(
    total_regs      = n(),
    missing_birth   = sum(birth_missing),
    future_dates    = sum(birth_future),
    too_young       = sum(birth_too_young),
    too_old         = sum(birth_too_old),
    invalid_total   = sum(birth_invalid),
    pct_invalid     = round(100 * mean(birth_invalid), 2)
  )

message("\n===== RELATÓRIO DE AUDITORIA BIOLÓGICA (CORRIGIDO) =====")
print(audit_report)

# ===============================================================
# 6.4 — Amostras para inspeção
# ===============================================================
message("\nAmostras para inspeção manual:")

message("\n→ Datas futuras:")
print(df_audit %>% filter(birth_future) %>% 
        select(user_birthdate, ride_date, age) %>% head(10))

message("\n→ Idade > MAX_AGE:")
print(df_audit %>% filter(birth_too_old) %>% 
        select(user_birthdate, ride_date, age) %>% head(10))

message("\n→ Idade < MIN_AGE:")
print(df_audit %>% filter(birth_too_young) %>% 
        select(user_birthdate, ride_date, age) %>% head(10))

# ===============================================================
# 6.5 — Visualização
# ===============================================================

# Visualizar distribuição de datas de nascimento inválidas
df_audit %>%
  filter(!is.na(user_birthdate)) %>%
  mutate(
    birth_year = year(user_birthdate),
    validity = case_when(
      birth_future    ~ "Futuro",
      birth_too_old   ~ "Idade > 100",
      birth_too_young ~ "Idade < 8",
      TRUE            ~ "Válida"
    )
  ) %>%
  ggplot(aes(x = birth_year, fill = validity)) +
  geom_histogram(binwidth = 1, color = "black") +
  scale_fill_manual(
    values = c(
      "Válida"       = "#B0B0B0",
      "Futuro"       = "#D73027",
      "Idade > 100"  = "#FDAE61",
      "Idade < 8"    = "#8073AC"
    )
  ) +
  theme_minimal()


# ===============================================================
# 6.6 — Remoção dos registros inválidos
# ===============================================================
n_invalid <- sum(df_audit$birth_invalid)

df_rides_clean <- df_rides_clean %>%
  filter(!df_audit$birth_invalid)

message("\n🧹 Registros removidos por impossibilidade biológica: ", n_invalid)


# Remove objetos específicos
rm(df_audit, MIN_AGE, MAX_AGE, CUTOFF_DATE, audit_report)

###############################################################
# 7. ANÁLISE DE PARSING E DADOS CRÍTICOS AUSENTES – TIME_START / TIME_END
###############################################################
# Objetivo:
#   - Avaliar a consistência das variáveis temporais (time_start,
#     time_end, datetime_start, datetime_end).
#   - Identificar padrões de ausência e inversões temporais.
#   - Caracterizar grupos de inconsistências que exigirão correção
#     algorítmica na etapa subsequente.
###############################################################


###############################################################
# 7.1 Diagnóstico de ausência nas variáveis críticas
###############################################################

na_summary <- df_rides_clean %>%
  summarise(
    across(
      c(time_end, ride_duration, ride_late),
      ~ sum(is.na(.x)),
      .names = "na_{col}"
    )
  ) %>%
  pivot_longer(everything(),
               names_to = "variavel",
               values_to = "qtd_na") %>%
  arrange(desc(qtd_na))

message("🔎 Ausências nas variáveis críticas:")
print(na_summary)


# Interpretação:
#   • Ausência simultânea em time_end, ride_duration e ride_late
#     indica falha de logging no fim da viagem e/ou erro de parsing.


###############################################################
# 7.2 Análise de sobreposição: ride_duration NA × time_end NA
###############################################################
# Avaliar se os registros sem duração também carecem do horário final,
# o que sugeriria dependência estrutural entre as variáveis.

overlap_nas <- df_rides_clean %>%
  filter(is.na(ride_duration)) %>%
  summarise(
    total_linhas       = n(),                               # total de NAs em ride_duration
    sum_in_time_end    = sum(is.na(time_end)),              # quantos também têm time_end NA
    sum_in_datetime_end = sum(is.na(datetime_end))          # confirmação no datetime
  )

print(overlap_nas)

# Interpretação:
#   • ~71k registros com NA em ride_duration
#   • ~42k deles também têm time_end e datetime_end ausentes
#   → trata-se de um problema sistemático na origem: registro incompleto do evento.



###############################################################
# 7.3 Detecção de inconsistências de cálculo (Grupo B)
###############################################################
# Grupo B é composto por:
#   • registros com ride_duration ausente
#   • mas com time_end presente
#   → estes são candidatos típicos a erro temporal (inversão ou swap)

group_b_issues <- df_rides_clean %>%
  filter(is.na(ride_duration) & !is.na(time_end))

group_b_summary <- group_b_issues %>%
  summarise(
    total             = n(),
    missing_start     = sum(is.na(time_start)),
    end_before_start  = sum(!is.na(time_start) & time_end < time_start),
    zero_duration     = sum(!is.na(time_start) & time_end == time_start),
    pct_inverse       = round(100 * end_before_start / total, 2)
  )

message("\n🔎 Grupo B — inconsistências temporais:")
print(group_b_summary)

# Interpretação :
#   • end_before_start ≫ zero_duration
#   → o padrão dominante é inversão temporal (erro sistêmico de registro)
#   → 28.884 (99,8%) dos casos têm inversão temporal real.

# ✔ A divisão entre Grupo A (ausência estrutural) e Grupo B (inconsistência temporal) foi confirmada numericamente.

# ✔ A base está diagnostica e pronta para receber a correção algorítmica robusta (overnight, swap, fallback), 
#que é a única abordagem metodológica adequada nesse cenário.



###############################################################
# 8. CORREÇÃO ALGORÍTMICA DOS DADOS CRÍTICOS (overnight, swap)
###############################################################

# -------------------------------------------------------------
# Parâmetros (ajustáveis conforme o domínio operacional)
# -------------------------------------------------------------
MAX_DURATION_MINS     <- 12 * 60   # limite superior para rides (12h)
OVERNIGHT_LIMIT_HOURS <- 16        # máximo após +1 dia
OVERNIGHT_LIMIT_MINS  <- OVERNIGHT_LIMIT_HOURS * 60

# 0) Preparação e preservação dos originais
# - preserva colunas originais para auditoria: datetime_start_orig, datetime_end_orig, ride_duration_orig, ride_late_orig
df_rides_clean <- df_rides_clean %>%
  mutate(
    datetime_start_orig = datetime_start,
    datetime_end_orig   = datetime_end,
    ride_duration_orig  = ride_duration,
    ride_late_orig      = ride_late,
    # flags iniciais de presença
    start_missing = is.na(datetime_start_orig),
    end_missing   = is.na(datetime_end_orig)
  )

# 1) Cálculo direto (casos normais: end >= start)
# - duration_direct_mins: diferença direta (end - start) em minutos
# - duration_direct_ok: TRUE se diferença estiver entre 0 e max_duration_mins
df_rides_clean <- df_rides_clean %>%
  mutate(
    duration_direct_mins = as.numeric(
      difftime(datetime_end_orig, datetime_start_orig, units = "mins")
    ),
    duration_direct_ok =
      !is.na(duration_direct_mins) &
      duration_direct_mins >= 0 &
      duration_direct_mins <= MAX_DURATION_MINS
  )

# 2) Tentativa overnight (travessia de meia-noite)
# - datetime_end_plus1: adiciona 1 dia quando end < start (apenas para teste)
# - duration_overnight_mins: diferença após +1 dia
# - duration_overnight_ok: aceitável dentro de limites
df_rides_clean <- df_rides_clean %>%
  mutate(
    datetime_end_plus1 = if_else(
      !is.na(datetime_end_orig) &
        !is.na(datetime_start_orig) &
        datetime_end_orig < datetime_start_orig,
      datetime_end_orig + days(1),
      datetime_end_orig
    ),
    duration_overnight_mins = as.numeric(
      difftime(datetime_end_plus1, datetime_start_orig, units = "mins")
    ),
    duration_overnight_ok =
      !is.na(duration_overnight_mins) &
      duration_overnight_mins > 0 &
      duration_overnight_mins <= MAX_DURATION_MINS &
      duration_overnight_mins <= OVERNIGHT_LIMIT_MINS
  )


# 3) Tentativa swap (start e end trocados)
# - duration_swap_mins: calcula start - end (se direct e overnight não OK)
# - duration_swap_ok: validade do swap dentro de limites
df_rides_clean <- df_rides_clean %>%
  mutate(
    duration_swap_mins = if_else(
      (!duration_direct_ok & !duration_overnight_ok) &
        !is.na(datetime_start_orig) &
        !is.na(datetime_end_orig),
      as.numeric(difftime(datetime_start_orig, datetime_end_orig, units = "mins")),
      NA_real_
    ),
    duration_swap_ok =
      !is.na(duration_swap_mins) &
      duration_swap_mins > 0 &
      duration_swap_mins <= MAX_DURATION_MINS
  )

# 4) Seleção da duração final (prioridade)
# - prioridade: ride_duration_orig (se já existia) > direct > overnight_adjust > swapped > NA (unresolved)
df_rides_clean <- df_rides_clean %>%
  mutate(
    ride_duration_fixed_mins = case_when(
      !is.na(ride_duration_orig) ~ ride_duration_orig,
      duration_direct_ok        ~ duration_direct_mins,
      duration_overnight_ok     ~ duration_overnight_mins,
      duration_swap_ok          ~ duration_swap_mins,
      TRUE                      ~ NA_real_
    ),
    correction_method = case_when(
      !is.na(ride_duration_orig) ~ "original_present",
      duration_direct_ok         ~ "direct",
      duration_overnight_ok      ~ "overnight_adjust(+1d)",
      duration_swap_ok           ~ "swapped",
      start_missing | end_missing ~ "missing_start_or_end",
      TRUE                       ~ "unresolved"
    )
  )

# 5) Aplicar correção ao campo oficial e recálculo de ride_late
df_rides_clean <- df_rides_clean %>%
  mutate(
    ride_duration = ride_duration_fixed_mins,
    ride_late = case_when(
      !is.na(ride_late_orig)                ~ ride_late_orig,
      !is.na(ride_duration_fixed_mins)      ~ (ride_duration_fixed_mins > 60),
      TRUE                                  ~ NA
    ),
    was_corrected = correction_method %in% c("overnight_adjust(+1d)", "swapped")
  )

# 6) Limpeza temporária de colunas auxiliares que não precisamos manter no df final
#    (mas preservamos os originais e correction_method)
df_rides_clean <- df_rides_clean %>%
  select(
    -duration_direct_mins,
    -duration_overnight_mins,
    -duration_swap_mins,
    -datetime_end_plus1
  )


# 7) QA automático (relatórios resumidos)
qa_counts <- df_rides_clean %>%
  count(correction_method) %>%
  arrange(desc(n))

message("\n=== QA: contagem por correction_method ===")
print(qa_counts)

#| Valor obtido         |
#| -------------------- |
#| **42.239**           |
#| **28.884** (swapped) |
#| **56**               |

# Estatísticas da distribuição corrigida
qa_duration_stats <- df_rides_clean %>%
  summarize(
    min_duration = min(ride_duration, na.rm = TRUE),
    q1 = quantile(ride_duration, 0.25, na.rm = TRUE),
    median = median(ride_duration, na.rm = TRUE),
    q3 = quantile(ride_duration, 0.75, na.rm = TRUE),
    max_duration = max(ride_duration, na.rm = TRUE),
    na_duration = sum(is.na(ride_duration))
  )
message("\n=== QA: estatísticas de ride_duration (minutos) ===")
print(qa_duration_stats)
# Isso indica que ZERO viagens foram erroneamente extrapoladas para cima,
# e ZERO viagens normais ficaram como NA indevidamente.

# Validação lógica de ride_late (>60 min)
qa_late_check <- df_rides_clean %>%
  mutate(check_late = if_else(!is.na(ride_duration), ride_duration > 60, NA)) %>%
  summarize(inconsistentes = sum((ride_late != check_late) & !is.na(ride_late) & !is.na(check_late)))
message("\n=== QA: inconsistências entre ride_late e regra (>60min) ===")
print(qa_late_check)
# indica que o recálculo da regra foi aplicado corretamente em todos os casos recuperados.

#  Amostra para auditoria manual: 5 casos por método de correção

audit_samples <- df_rides_clean %>%
  group_by(correction_method) %>%
  sample_n(size = pmin(5, n()), replace = FALSE) %>%
  ungroup() %>%
  select(correction_method, datetime_start_orig, datetime_end_orig, ride_duration_orig, ride_duration, ride_late)

# Exibir amostra
message("\n=== Amostras para auditoria (max 5 por método) ===")
print(audit_samples)

# ☆ missing_start_or_end ✔ Esperado → sem horário final → irrecuperável → NA.
# ☆ original_present ✔ Correto → preservado.
# ☆ swapped ✔ Correto → swap detectou e corrigiu.

df_rides_clean %>%
  filter(correction_method == "unresolved") %>%
  select(datetime_start_orig, datetime_end_orig, ride_duration_orig) %>%
  head(20)
#isso confirma 100% que os 56 casos “unresolved” são REALMENTE irrecuperáveis e que o algoritmo está funcionando exatamente como deveria.
# ☆ unresolved ✔ Portanto, corretamente marcado como “unresolved”.

rm(na_summary, overlap_nas, qa_counts, qa_duration_stats, qa_late_check, audit_samples, group_b_issues, group_b_summary)

# ---------------------------------------------------------------
# 9. INVESTIGAÇÃO DE AUSÊNCIA MASSIVA NOS DADOS DEMOGRÁFICOS
# ---------------------------------------------------------------
# Objetivo:
#   Analisar e padronizar a variável `user_residence`, que apresenta
#   aproximadamente 63% de valores ausentes e alta variação semântica.
#   Essa variável é fundamental para análises geográficas e perfis
#   comportamentais de usuários.
# ---------------------------------------------------------------


# ---------------------------------------------------------------
# 9.1 Diagnóstico quantitativo inicial
# ---------------------------------------------------------------
res_report <- df_rides_clean %>%
  summarise(
    total_registros = n(),
    n_ausentes      = sum(is.na(user_residence)),
    pct_ausentes    = round(100 * mean(is.na(user_residence)), 2),
    n_distintos     = n_distinct(user_residence, na.rm = TRUE)
  )

message("📌 Diagnóstico inicial de user_residence:")
print(res_report)

# Frequências iniciais (Top 20)
df_rides_clean %>%
  count(user_residence, sort = TRUE) %>%
  slice_head(n = 20)


# Impacto da ausência (testes de viés comportamental)
df_rides_clean %>%
  mutate(residence_missing = is.na(user_residence)) %>%
  group_by(residence_missing) %>%
  summarize(
    total             = n(),
    avg_ride_duration = mean(ride_duration, na.rm = TRUE),
    pct_late          = mean(ride_late, na.rm = TRUE) * 100
  )

# Observações:
#   - Usuários sem residência informada correspondem a ~63% dos registros.
#   - Padrões distintos de duração e atraso sugerem viés comportamental
#     entre usuários com e sem dados geográficos.



#*****
#*
#*
# ---------------------------------------------------------------
# AUDITORIA EXPLORATÓRIA DA VARIÁVEL user_residence
# ---------------------------------------------------------------
# Objetivo: compreender padrões, inconsistências e oportunidades
# de padronização antes da limpeza e harmonização semântica.
# ---------------------------------------------------------------

# Detectar padrões suspeitos
res_check <- df_rides_clean %>%
  mutate(
    has_email  = str_detect(user_residence, "@"),
    has_digit  = str_detect(user_residence, "\\d"),
    has_symbol = str_detect(user_residence, "[[:punct:]]")
  )

res_noise_summary <- res_check %>%
  summarise(
    emails   = sum(has_email, na.rm = TRUE),
    numbers  = sum(has_digit, na.rm = TRUE),
    symbols  = sum(has_symbol, na.rm = TRUE)
  )

message("\n📌 Presença de ruído estrutural:")
print(res_noise_summary)


# Amostra de 100 valores únicos, para análise manual
set.seed(42)
sample_unique_res <- df_rides_clean %>%
  distinct(user_residence) %>%
  sample_n(100)

View(sample_unique_res)

#*****
#*
#*


# ---------------------------------------------------------------
# 10. TRATAMENTO E PADRONIZAÇÃO DA VARIÁVEL user_residence
# ---------------------------------------------------------------

# ==========================================================
# 1. Normalização estrutural
# ==========================================================
df_rides_clean <- df_rides_clean %>%
  mutate(
    res_raw = as.character(user_residence),
    res_norm = res_raw |>
      textclean::replace_html() |>
      str_to_upper() |>
      stringi::stri_trans_general("Latin-ASCII") |>
      str_squish(),
    res_temp = res_norm
  )

# ==========================================================
# 2. Remover ruído explícito
# ==========================================================
df_rides_clean <- df_rides_clean %>%
  mutate(
    res_temp = case_when(
      is.na(res_temp) ~ NA_character_,
      str_detect(res_temp, "@") ~ NA_character_,
      str_detect(res_temp, "\\d") ~ NA_character_,
      res_temp %in% c("", "X", "XX", "XXX") ~ NA_character_,
      TRUE ~ res_temp
    )
  )


# ==========================================================
# 3. Listas derivadas da amostra real
# ==========================================================

invalid_values <- c(
  "", "X", "XX", "XXX", "X X", "NULL",
  "NA", "N/A", "SEM INFO",
  "CEILANDIA-", "CEILANDIA--", 
  "CEILANDIA NORTE",
  "BRASILIA0", "BRASIIA"
)

df_values_df <- c(
  "DF", "BRASILIA", "BRASILIA DF", "BRASILIA - DF", "BRASILIA-DF", 
  "BRASILIA,", "BRASILIA , DF",
  "SAMAMBAIA", "TAGUATINGA", "CEILANDIA", "GUARA", "GAMA",
  "PLANALTINA", "SOBRADINHO", "SOBRADINHO I", "SOBRADINHO II",
  "RECANTO DAS EMAS", "AGUAS CLARAS", "VICENTE PIRES",
  "BRAZLANDIA", "LAGO SUL", "SANTA MARIA"
)

df_sat <- c(
  "SAMAMBAIA", "TAGUATINGA", "CEILANDIA", "GUARA", "GAMA",
  "PLANALTINA", "SOBRADINHO", "SOBRADINHO I", "SOBRADINHO II",
  "RECANTO DAS EMAS", "AGUAS CLARAS", "VICENTE PIRES",
  "BRAZLANDIA", "LAGO SUL", "SANTA MARIA"
)

go_values <- c("GO", "GOIAS")

go_entorno <- c(
  "VALPARAISO", "VALPARAISO DE GOIAS", "VALPARAISO 1",
  "NOVO GAMA", "LUZIANIA", "APARECIDA DE GOIANIA",
  "PLANALTINA DE GOIAS", "SANTO ANTONIO DO DESCOBERTO",
  "CIDADE OCIDENTAL"
)

map_mg <- c("MG", "MINAS GERAIS", "BELO HORIZONTE", "BH", "VICOSA", "VICOSA", "VIÇOSA")
map_sp <- c("SP", "SAO PAULO", "SÃO PAULO", "SANTOS", "HORTOLANDIA")
map_rj <- c("RJ", "RIO DE JANEIRO", "NITEROI", "NITEROI")
map_rs <- c("RS", "RIO GRANDE DO SUL", "PORTO ALEGRE", "SANTIAGO", "CANOAS", "NOVO HAMBURGO")
map_pe <- c("PE", "PERNAMBUCO", "RECIFE", "JABOATAO DOS GUARARAPES")
map_ce <- c("CE", "CEARA", "FORTALEZA", "TIANGUA")
map_ba <- c("BA", "BAHIA", "SALVADOR")
map_pa <- c("PA", "PARA")
map_ac <- c("AC", "ACRE")
map_pr <- c("PR", "PARANA", "CURITIBA")
map_es <- c("ES", "ESPIRITO SANTO", "VITORIA")
map_ma <- c("MA", "MARANHAO")
map_mt <- c("MT", "MATO GROSSO")
map_rr <- c("RR", "RORAIMA")


# ==========================================================
# 4. Mapeamento Final
# ==========================================================
df_rides_clean <- df_rides_clean %>%
  mutate(
    user_residence_std = case_when(
      
      is.na(res_temp) ~ NA_character_,
      res_temp %in% invalid_values ~ NA_character_,
      
      # DF
      res_temp %in% df_values_df ~ "BRASILIA (DF)",
      str_detect(res_temp, paste(df_sat, collapse = "|")) ~ "BRASILIA (DF)",
      
      # GO e Entorno
      res_temp %in% go_values ~ "GOIAS (GO)",
      str_detect(res_temp, paste(go_entorno, collapse = "|")) ~ "GOIAS (GO)",
      
      # Estados
      res_temp %in% map_sp ~ "SAO PAULO (SP)",
      res_temp %in% map_rj ~ "RIO DE JANEIRO (RJ)",
      res_temp %in% map_mg ~ "MINAS GERAIS (MG)",
      res_temp %in% map_ba ~ "BAHIA (BA)",
      res_temp %in% map_ac ~ "ACRE (AC)",
      res_temp %in% map_pe ~ "PERNAMBUCO (PE)",
      res_temp %in% map_ce ~ "CEARA (CE)",
      res_temp %in% map_pa ~ "PARA (PA)",
      res_temp %in% map_rs ~ "RIO GRANDE DO SUL (RS)",
      res_temp %in% map_pr ~ "PARANA (PR)",
      res_temp %in% map_es ~ "ESPIRITO SANTO (ES)",
      res_temp %in% map_ma ~ "MARANHAO (MA)",
      res_temp %in% map_mt ~ "MATO GROSSO (MT)",
      res_temp %in% map_rr ~ "RORAIMA (RR)",
      
      # Siglas genéricas
      nchar(res_temp) == 2 ~ res_temp,
      
      TRUE ~ "OUTRA LOCALIDADE"
    )
  ) %>%
  # Refinamento de Fatores
  mutate(
    user_residence_std = user_residence_std %>% 
      fct_na_value_to_level(level = "NAO INFORMADO") %>%  
      fct_lump_min(min = 200, other_level = "OUTRA LOCALIDADE")
  ) %>%
  select(-res_temp)

# - VERIFICAÇÃO E ANÁLISE FINAL DA PADRONIZAÇÃO
# ---------------------------------------------------------------

message("Distribuição final dos agrupamentos de residência (mínimo: 200 registros):")
df_rides_clean %>%
  count(user_residence_std, sort = TRUE) %>%
  print(n = 20)

# - VISUALIZAÇÕES EXPLORATÓRIAS – DISTRIBUIÇÃO DE RESIDÊNCIA
# ---------------------------------------------------------------

# (1) Panorama geral, destacando a ausência de dados
ggplot(df_rides_clean, aes(x = fct_infreq(user_residence_std))) +
  geom_bar(fill = "gray70") +
  geom_bar(
    data = subset(df_rides_clean, user_residence_std == "NAO INFORMADO"),
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

# (2) Perfil geográfico entre registros válidos
df_rides_clean %>%
  filter(user_residence_std != "NAO INFORMADO") %>%
  ggplot(aes(x = fct_infreq(user_residence_std))) +
  geom_bar(fill = "steelblue") +
  geom_text(stat = 'count', aes(label = ..count..),
            vjust = -0.5, size = 3) +
  labs(
    title = "Perfil Geográfico dos Usuários Identificados",
    subtitle = "Distribuição entre localidades válidas (37% dos registros)",
    x = "Residência (Agrupada)",
    y = "Total de Viagens"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
######

skim(df_rides_clean)
skim(df_stations_clean)

# Limpar Colunas dos dados preparados:
# ===============================================================
# SELEÇÃO FINAL DE COLUNAS (DESTRALHAMENTO)
# ===============================================================

df_rides_final <- df_rides_clean %>%
  select(
    # -----------------------------------------------------------
    # 1. PERFIL DO USUÁRIO
    # -----------------------------------------------------------
    user_gender,
    user_birthdate,
    
    # Mantemos a padronizada e renomeamos para ficar fácil de usar
    user_residence = user_residence_std, 
    
    # (Opcional) Mantemos a original apenas para comparação, se quiser:
    user_residence_raw = user_residence,
    
    # -----------------------------------------------------------
    # 2. DADOS DA VIAGEM (QUANDO E ONDE)
    # -----------------------------------------------------------
    ride_date,
    
    # Estações
    station_start,
    station_end,
    
    # Horários (DateTime é o mais importante para cálculos)
    datetime_start,
    datetime_end,
    
    # Horários isolados (úteis para gráficos de "pico por hora")
    time_start,
    time_end,
    
    # -----------------------------------------------------------
    # 3. MÉTRICAS (RESULTADO)
    # -----------------------------------------------------------
    # Estas já contêm os valores corrigidos pelo seu algoritmo
    ride_duration,
    ride_late,
    
    # -----------------------------------------------------------
    # 4. METADADOS DE QUALIDADE (Útil na EDA para explicar outliers)
    # -----------------------------------------------------------
    correction_method,  # Para saber se foi calculado, corrigido ou original
    was_corrected       # Booleano simples (TRUE/FALSE)
  )

# ===============================================================
# CHECAGEM FINAL
# ===============================================================
message("📉 Colunas antes: ", ncol(df_rides_clean))
message("🎯 Colunas agora: ", ncol(df_rides_final))

glimpse(df_rides_final)

df_rides_clean <- df_rides_final
# ===============================================================

# Salvar dados preparados, para usar na EAD
output_dir <- "arquivos/outputs"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

stamp <- format(Sys.Date(), "%Y%m%d")

# 1. RDS (Preserva tipos R)
saveRDS(df_rides_clean, file.path(output_dir, paste0("df_rides_clean_", stamp, ".rds")))
saveRDS(df_stations_clean, file.path(output_dir, paste0("df_stations_clean_", stamp, ".rds")))

# 2. CSV (Interoperabilidade)
df_rides_clean %>%
  mutate(across(where(is.factor), as.character)) %>% 
  write.csv(file.path(output_dir, paste0("df_rides_clean_", stamp, ".csv")), row.names = FALSE, fileEncoding = "UTF-8")

df_stations_clean %>%
  mutate(across(where(is.factor), as.character)) %>% 
  write.csv(file.path(output_dir, paste0("df_stations_clean_", stamp, ".csv")), row.names = FALSE, fileEncoding = "UTF-8")

message("\n✅ Processo concluído! Arquivos salvos em: ", output_dir)


# Remove TUDO do ambiente, EXCETO o dataframe final 'df_rides_clean'
rm(list = setdiff(ls(), "df_rides_clean"))

# Libera a memória RAM
gc()

message("🧹 Ambiente limpo! Apenas 'df_rides_clean' foi mantido.") 

