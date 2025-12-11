# ===============================================================
# SISTEMA +BIKE – FASE 2: ANÁLISE EXPLORATÓRIA DE DADOS
# ===============================================================
# Autor: Gean
# Data: 10/12/
# Objetivo:
#   Descobrir padrões, detectar anomalias, testar hipóteses e verificar
#   suposições através de estatísticas descritivas e técnicas de visualização
#   identificar perfil de atrasos
# ===============================================================

###############################################################
# 0. AMBIENTE E CONFIGURAÇÕES INICIAIS

# Controle de impressão e encoding
options(
  max.print = 5.5e5,   # Limite de caracteres exibidos no console
  encoding  = "UTF-8"
)

# Limpeza opcional do ambiente
# Ative apenas quando desejado:
# rm(list = ls(), envir = .GlobalEnv)

# Reprodutibilidade
set.seed(1234)


# ------------ Diretório seguro -------------------
# Evita caminhos absolutos dependentes da máquina:
if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
library(here)

root_dir <- here()

# Caminhos relativos para os dados
dir_data <- here("arquivos")

# ------------ Gestão de pacotes --------------------
required_pkgs <- c(
  "tidyverse", "skimr", "DataExplorer",
  "textclean", "stringi", "forcats", "lubridate", "janitor", "forcats", "naniar"
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
message("Versão do R: ", R.version.string)
message("Data/Hora de início: ", Sys.time())
# ----------------------------------------------------------------

###############################################################
# 1. IMPORTAÇÃO DAS BASES TRATADAS


# Função de leitura híbrida e segura
read_data_safe <- function(path) {
  
  if (!file.exists(path)) {
    stop(glue::glue("❌ Arquivo não encontrado: {path}"))
  }
  
  # Verifica a extensão do arquivo
  ext <- tools::file_ext(path)
  
  if (ext == "rds") {
    # Se for RDS, usa read_rds (sem argumentos extras)
    data <- read_rds(file = path)
    
  } else if (ext == "csv") {
    # Se for CSV, usa read_csv (com os argumentos de tratamento)
    data <- read_csv(
      file = path,
      show_col_types = FALSE,
      na = c("", "NA", "N/A", "<NA>")
    )
    
  } else {
    stop("❌ Formato de arquivo não suportado (use .rds ou .csv)")
  }
  
  # Limpeza final dos nomes
  data %>% 
    clean_names()
}

# Leitura dos arquivos RDS (da fase anterior)
df_rides    <- read_data_safe(here("arquivos/outputs", "df_rides_clean_20251129.rds"))

df_stations <- read_data_safe(here("arquivos/outputs", "df_stations_clean_20251202.rds"))


# Checagem estrutural inicial

glimpse(df_rides)
glimpse(df_stations)

str(df_rides)
str(df_stations)

skim(df_rides)
skim(df_stations)

df_rides %>% 
  count(station_start, sort = TRUE)

###############################################################

#Auditoria de Missing Values
miss_var_summary(df_rides)

gg_miss_var(df_rides)

###
# Explorar user_residence

glimpse(df_rides %>% select(user_residence_raw, user_residence))
miss_var_summary(df_rides %>% select(user_residence_raw, user_residence))

df_rides %>% count(user_residence_raw, sort = TRUE) %>% print(n = 15)
df_rides %>% count(user_residence, sort = TRUE) %>% print(n = 15)

#* o problema de missing não foi criado pela padronização;
#* reflete ausência estrutural já presente no sistema operacional.
#* 
#* 

# A avaliação é feita comparando proporções:
df_rides %>% 
  count(user_residence_raw) %>% 
  mutate(pct = n / sum(n) * 100)

df_rides %>% 
  count(user_residence) %>% 
  mutate(pct = n / sum(n) * 100)

#* A transformação preservou todas as ocorrências válidas.
#* Não houve "supergrupos" artificiais.
#* A padronização aumentou a coerência e reduziu drasticamente a cardinalidade (231 → 15).
#* Categorias raras foram corretamente enviadas para "OUTRA LOCALIDADE".
#* A categoria “NAO INFORMADO” agora é coerente e mensurável.
#* 

# Distribuição geral da residência (padronizada)
df_rides %>% 
  ggplot(aes(fct_infreq(user_residence))) +
  geom_bar(fill = "#2980B9") +
  labs(
    title = "Distribuição Geográfica dos Usuários (+BIKE)",
    x = "Residência - Categoria Padronizada",
    y = "Número de Viagens"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))



# Comparação entre residências válidas vs NA
df_rides %>% 
  mutate(flag = user_residence == "NAO INFORMADO") %>% 
  count(flag) %>%
  ggplot(aes(flag, n, fill = flag)) +
  geom_col() +
  scale_fill_manual(values = c("#E74C3C", "gray70")) +
  labs(
    title = "Presença vs Ausência de Dados Geográficos",
    x = "Residência Não Informada?",
    y = "Total de Registros"
  ) +
  theme_minimal()

# Auditoria Analítica — Residência vs Comportamento #

#*  Perfis de uso: duração, atraso e frequência
df_rides %>%
  group_by(user_residence) %>%
  summarise(
    rides = n(),
    avg_duration = mean(ride_duration, na.rm = TRUE),
    pct_late = mean(ride_late, na.rm = TRUE) * 100,
    avg_age = mean(year(Sys.Date()) - year(user_birthdate), na.rm = TRUE)
  ) %>%
  arrange(desc(rides))

#* Usuários sem residência informada se comportam como residentes típicos,
#* não como turistas.
#* Já usuários de SP, RJ, PE etc. têm:
#*   maiores durações médias,
#*   maior taxa de atraso,
#* Sugerindo:
#*   turista
#*   uso casual
#*   menos familiaridade com o sistema.

# * A variável "residência informada vs. não informada" é altamente preditiva 
# * e deve ser usada em modelagens futuras.

# Estações preferidas por grupo geográfico
df_rides %>%
  group_by(user_residence, station_start) %>%
  summarise(n = n()) %>%
  group_by(user_residence) %>%
  slice_max(n, n = 5)

# Horários de pico por grupo geográfico
df_rides %>%
  mutate(hour = hour(datetime_start)) %>%
  group_by(user_residence, hour) %>%
  summarise(n = n()) %>%
  group_by(user_residence) %>%
  mutate(freq = n / sum(n)) %>%
  ungroup()

# Ciclos semanais por residência
df_rides %>%
  mutate(week_day = wday(ride_date, label = TRUE)) %>%
  group_by(user_residence, week_day) %>%
  summarise(n = n()) %>%
  group_by(user_residence) %>%
  mutate(freq = n / sum(n))

#* a necessidade de aperfeiçoar coleta futura, pois usuários não informam residência
#* impacto moderado na análise, mas ainda funcional devido aos estados consolidados
#* 

# Mostra honestamente o tamanho do "buraco" nos dados.
df_rides %>%
  count(user_residence) %>%
  mutate(grupo = case_when(
    user_residence == "NAO INFORMADO" ~ "Não Informado",
    user_residence == "BRASILIA (DF)" ~ "Brasília (DF)",
    TRUE ~ "Outros Estados"
  )) %>%
  count(grupo, wt = n) %>%
  mutate(prop = n / sum(n)) %>%
  ggplot(aes(x = "", y = prop, fill = grupo)) +
  geom_col(color = "white") +
  coord_polar("y") +
  geom_text(aes(label = scales::percent(prop, accuracy = 1)),
            position = position_stack(vjust = 0.5), color = "white", fontface = "bold") +
  scale_fill_manual(values = c("#2980B9", "#95A5A6", "#E74C3C")) +
  theme_void() +
  labs(title = "Origem dos Usuários", fill = "Origem Declarada")


# Ditribuição de residência
ggplot(df_rides, aes(x = fct_infreq(user_residence))) +
  geom_bar(fill = "gray70") +
  geom_bar(
    data = subset(df_rides, user_residence == "NAO INFORMADO"),
    fill = "#E74C3C"
  ) +
  labs(
    title = "Distribuição da Residência dos Usuários",
    subtitle = "A barra vermelha indica volume de dados não informados (~63%)",
    x = "Residência (Agrupada)",
    y = "Número de Viagens"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Analisando os 37% (Ranking dos Top Locais)
df_rides %>%
  filter(user_residence != "NAO INFORMADO") %>%
  ggplot(aes(x = fct_infreq(user_residence))) +
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


# Diferença de tempo de uso (Turistas vs Locais).
df_rides %>%
  filter(user_residence != "NAO INFORMADO") %>%
  # Pegar apenas os Top 6 estados para o gráfico não ficar poluição
  mutate(residencia_top = fct_lump(user_residence, n = 6, other_level = "OUTROS")) %>%
  filter(ride_duration < 60) %>% # Filtro visual de outliers
  ggplot(aes(x = reorder(residencia_top, ride_duration, FUN = median), y = ride_duration)) +
  geom_boxplot(fill = "steelblue", alpha = 0.6) +
  coord_flip() +
  labs(
    title = "Duração da Viagem por Estado de Origem",
    subtitle = "Visitantes de SP e RJ tendem a fazer viagens mais longas (Perfil Lazer)",
    x = NULL,
    y = "Duração (minutos)"
  ) +
  theme_minimal()

# CONFIRMAR OS PADRÕES OBSERVADOS AQUI EXPLORANDO AS DEMAIS 

# O QUEM — Perfil do Usuário
# já vimos que a maioria dos usuários não são turistas
# e que os turistas tem um perfil mais longo de pedaladas
summary(df_rides)

# Criar variável de idade
df_rides <- df_rides %>%
  mutate(
    age = time_length(interval(user_birthdate, ride_date), "years"),
    age = round(age, 1)
  )
summary(df_rides$age)

# Criar variável binária para residência (informado ou não informado)
df_rides <- df_rides |> 
  mutate(
    residence_status = if_else(user_residence=="NAO INFORMADO",
                               "nao informado","informado")
  )
skim(df_rides$residence_status)
# Distribuição por status
df_rides %>%
  count(residence_status) %>%
  mutate(pct = round(n/sum(n)*100,2))

# Distribuição geral das idades
df_rides %>%
  ggplot(aes(age)) +
  geom_histogram(binwidth = 3, fill="#3498DB", color="white") +
  geom_vline(aes(xintercept = median(age, na.rm=TRUE)), 
             color="red", linewidth=0.5) +
  labs(
    title="Distribuição de Idade dos Usuários",
    subtitle="                Mediana",
    x="Idade",
    y="Frequência"
  ) +
  theme_minimal()


# Distribuição Gênero (Frequência Relativa)
df_rides %>%
  filter(!is.na(user_gender)) |> 
  count(user_gender) %>%
  mutate(
    pct = n / sum(n),
    label = scales::percent(pct, accuracy = 0.1)
  ) %>%
  ggplot(aes(x = user_gender, y = n, fill = user_gender)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = label), vjust = -0.5, fontface = "bold") +
  scale_fill_manual(values = c("F" = "#E74C3C", "M" = "#2980B9")) + # Cores distintas
  labs(
    title = "Divisão por Gênero",
    subtitle = "Há uma predominância clara do público masculino (~74%)",
    x = "Gênero",
    y = "Viagens"
  ) +
  theme_minimal() 

# Homens e mulheres têm a mesma idade média?
ggplot(drop_na(df_rides), aes(x = age, fill = user_gender)) +
  geom_density(alpha = 0.5) + # Alpha garante transparência para ver a sobreposição
  scale_fill_manual(values = c("F" = "#E74C3C", "M" = "#2980B9")) +
  labs(
    title = "Perfil Etário por Gênero",
    subtitle = "As distribuições são muito similares, indicando que a idade independe do gênero",
    x = "Idade",
    y = "Densidade",
    fill = "Gênero"
  ) +
  theme_minimal() +
  scale_x_discrete(na.translate = FALSE)

df_rides %>%
  filter(!is.na(user_gender)) %>%
  ggplot(aes(user_gender, age, fill=user_gender)) +
  geom_boxplot(alpha=0.7) +
  scale_fill_manual(values=c("#3498DB","#E74C3C")) +
  labs(
    title="Distribuição Etária por Gênero",
    x="Gênero",
    y="Idade"
  ) +
  theme_minimal()

# Idade × residência → comportamento local vs turista
df_rides %>%
  filter(user_residence != "NAO INFORMADO") %>%
  ggplot(aes(user_residence, age)) +
  geom_boxplot(fill="steelblue") +
  coord_flip() +
  labs(
    title="Idade por Local de Origem",
    subtitle="Tendências etárias entre turistas e moradores",
    x="Residência",
    y="Idade"
  ) +
  theme_minimal()

df_rides %>%
  ggplot(aes(residence_status, age, fill=residence_status)) +
  geom_boxplot(alpha=0.7) +
  scale_fill_manual(values=c("#E74C3C","#3498DB")) +
  coord_flip() +
  labs(
    title="Idade por Local de Origem",
    subtitle="Tendências etárias entre turistas e moradores",
    x="Residência",
    y="Idade"
  ) +
  theme_minimal()

# Idade × duração (relação pedalar mais/menos)
library(mgcv) # Necessário para o método 'gam' em grandes bases

df_rides %>%
  
  filter(!is.na(age), !is.na(ride_duration)) %>%
  filter(age >= 10 & age <= 90) %>%        # Filtra idades irreais
  filter(ride_duration < 120) %>%          # Foco em viagens de até 2 horas (remove erros de sistema)
  
  # Visualização
  ggplot(aes(x = age, y = ride_duration)) + # X = Idade, Y = Duração
  
  # geom_jitter em vez de geom_point para evitar sobreposição excessiva
  geom_jitter(alpha = 0.05, linewidth = 1, color = "#2C3E50") + 
  
  # 'gam' (Generalized Additive Model) que é rápido para Big Data
  geom_smooth(method = "gam", color = "red", linewidth = 1.2) +
  
  labs(
    title = "Correlação: Idade vs. Tempo de Pedalada",
    subtitle = "A linha vermelha mostra a tendência média por idade",
    x = "Idade do Usuário",
    y = "Duração da Viagem (min)"
  ) +
  theme_minimal()
  
  
# Gênero × atraso
df_rides %>%
  group_by(user_gender) %>%
  summarise(
    atraso_pct = mean(ride_late, na.rm=TRUE) * 100
  )

# Segmentação em faixas etárias

df_rides <- df_rides %>%
  mutate(age_group = cut(
    age,
    breaks = c(0,18,25,35,45,55,65,100),
    labels = c("<18","18-24","25-34","35-44","45-54","55-64","65+"),
    right = FALSE
  ))
df_rides %>% count(age_group)

# Gênero x Faixa
df_rides %>%
  filter(!is.na(user_gender), !is.na(age_group)) %>%
  count(age_group, user_gender) %>%
  ggplot(aes(age_group, n, fill=user_gender)) +
  geom_col(position="dodge") +
  theme_minimal()


  