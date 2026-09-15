# ==============================================================================
# SISTEMA +BIKE – FASE 2: ANÁLISE EXPLORATÓRIA DE DADOS (EDA)
# ==============================================================================
# Autor: Gean Gabriel
# Data: 10/12/2025
# Objetivo: Descobrir padrões, detectar anomalias, testar hipóteses (Perfil/Uso)
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

# 1. FUNÇÕES AUXILIARES (ETL SEGURO) -------------------------------------------

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
df_rides    <- read_data_safe(here("arquivos/outputs", "df_rides_clean_20251129.rds"))
df_stations <- read_data_safe(here("arquivos/outputs", "df_stations_clean_20251202.rds"))

# --- 2.1 Investigação: Missing Semântico (Residência) ---
message("🔍 Auditando Residência...")

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

# NOTA DE ANÁLISE (Ação 2):
# As 42k linhas sem datetime_end são Espacialmente Válidas, mas Temporalmente Inválidas.
# Serão mantidas, mas filtradas em análises de tempo.

# Ação 3: Investigação Missing Gênero ---
# 338 casos (<0.2%). Impacto negligenciável. Mantidos por enquanto.

# 3. ENGENHARIA DE FEATURES (PREPARAÇÃO ANALÍTICA) -----------------------------

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

# FILTROS DE SANIDADE E SUMÁRIOS --------------------------------------------

# Idade (Verificação de NAs)
summary_age <- df_rides %>%
  summarise(
    n = n(),
    na_age = sum(is.na(user_age)),
    na_age_group = sum(is.na(user_age_group_exp))
  )

# Filtro de Sanidade Biológica
df_rides <- df_rides %>%
  filter(user_age >= 8 & user_age <= 90)

message("✅ Processamento concluído. Dimensões finais: ", nrow(df_rides), " linhas e " , ncol(df_rides), " colunas.")

# Verificação de Atrasos
table_late <- df_rides %>%
  count(ride_late); print(table_late)


# ------------------------------------------------------------------------------
# 4. ANÁLISE DO PERFIL DO USUÁRIO ("O QUEM")
# ------------------------------------------------------------------------------

# Configuração de Cores para Identidade Visual
paleta_bike <- list(
  principal = "#3498DB",
  secundaria = "#2E86AB",
  alerta     = "#E74C3C",
  neutra     = "#2C3E50"
)

# ==============================================================================
# 4.1 IDADE: ESTATÍSTICAS E DISTRIBUIÇÃO
# ==============================================================================

# Estatísticas descritivas da idade
df_rides %>%
  summarise(
    n             = n(),
    idade_media   = mean(user_age, na.rm = TRUE),
    idade_mediana = median(user_age, na.rm = TRUE),
    idade_sd      = sd(user_age, na.rm = TRUE),
    idade_min     = min(user_age, na.rm = TRUE),
    idade_q1      = quantile(user_age, 0.25, na.rm = TRUE),
    idade_q3      = quantile(user_age, 0.75, na.rm = TRUE),
    idade_max     = max(user_age, na.rm = TRUE)
  )

# Distribuição da idade (histograma)
# Nota: Linha vermelha = média | Linha tracejada = mediana
ggplot(df_rides, aes(x = user_age)) +
  geom_histogram(
    binwidth = 2,
    fill = paleta_bike$principal,
    color = "white"
  ) +
  geom_vline(
    xintercept = mean(df_rides$user_age, na.rm = TRUE),
    color = paleta_bike$alerta,
    linewidth = 0.6
  ) +
  geom_vline(
    xintercept = median(df_rides$user_age, na.rm = TRUE),
    color = paleta_bike$neutra,
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
# * Apesar da mediana em 25 anos, a média levemente maior sugere cauda à direita,
# * indicando usuários mais velhos com menor frequência, mas impacto relevante.
ggplot(df_rides, aes(y = user_age)) +
  geom_boxplot(
    fill = paleta_bike$secundaria,
    color = "#1C3A59",
    alpha = 0.8,
    outlier.alpha = 0.2
  ) +
  labs(
    title = "Boxplot da Idade dos Usuários",
    y = "Idade"
  ) +
  theme_minimal()

# ==============================================================================
# 4.2 FAIXAS ETÁRIAS E COMPORTAMENTO
# ==============================================================================

# Distribuição por Faixa Etária
df_rides %>%
  filter(!is.na(user_age_group_exp)) %>%
  count(user_age_group_exp) %>%
  mutate(pct = n / sum(n)) %>%
  ggplot(aes(x = user_age_group_exp, y = n)) +
  geom_col(fill = paleta_bike$principal, width = 0.7) +
  geom_text(
    aes(label = scales::percent(pct, accuracy = 0.1)),
    vjust = -0.3,
    size = 3
  ) +
  scale_y_continuous(
    labels = scales::comma,
    expand = expansion(mult = c(0, 0.15))
  ) +
  labs(
    title = "Distribuição por Faixa Etária",
    subtitle = "Maior concentração em jovens adultos",
    x = "Faixa Etária",
    y = "Número de Viagens"
  ) +
  theme_minimal()

# Idade x Taxa de Atraso (Risco Operacional)
media_atraso_geral <- mean(df_rides$ride_late, na.rm = TRUE)

df_rides %>%
  filter(!is.na(user_age_group_exp)) %>%
  group_by(user_age_group_exp) %>%
  summarise(
    total = n(),
    atrasos = sum(ride_late, na.rm = TRUE),
    taxa_atraso = mean(ride_late, na.rm = TRUE)
  ) %>%
  ggplot(aes(x = user_age_group_exp, y = taxa_atraso)) +
  geom_col(aes(fill = taxa_atraso > media_atraso_geral), width = 0.7) +
  geom_hline(yintercept = media_atraso_geral, linetype = "dashed", color = "gray40") +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_manual(
    values = c("FALSE" = "gray70", "TRUE" = paleta_bike$alerta), 
    labels = c("Abaixo da Média", "Acima da Média")
  ) +
  labs(
    title = "Quem gera mais multas por atraso?",
    subtitle = "Linha tracejada = Média Geral do Sistema",
    x = "Faixa Etária",
    y = "% de Viagens Atrasadas",
    fill = "Risco"
  ) +
  theme_minimal()

# ==============================================================================
# 4.3 CRUZAMENTOS E INTERAÇÕES
# ==============================================================================

# Idade × tipo de uso (proxy por horário)
df_rides %>%
  mutate(
    periodo = case_when(
      hora_inicio %in% 8:11  ~ "Pico Manhã",
      hora_inicio %in% 15:18 ~ "Pico Tarde",
      TRUE                   ~ "Fora do Pico"
    )
  ) %>%
  group_by(user_age_group_exp, periodo) %>%
  summarise(n = n(), .groups = "drop") %>%
  ggplot(aes(x = user_age_group_exp, y = n, fill = periodo)) +
  geom_col(position = "fill") +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Faixa Etária × Tipo de Uso (proxy por horário)",
    subtitle = "Proporção de uso por período do dia",
    y = "Proporção",
    x = "Faixa Etária"
  ) +
  theme_minimal()

# Interação: Idade x Duração (viagens < 60min para controle de ruído)
ggplot(
  subset(df_rides, ride_duration < 60 & !is.na(user_age_group_exp)), 
  aes(x = user_age_group_exp, y = ride_duration, fill = user_age_group_exp)
) +
  geom_boxplot(alpha = 0.7, outlier.shape = NA) +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 3, color = "black") +
  labs(
    title = "Duração mediana por faixa etária",
    subtitle = "Ponto preto representa a média da duração",
    y = "Duração (min)",
    x = "Faixa Etária"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

# Nota sobre modelagem (Análise de Dispersão):
# * Para qualquer idade observada, existem viagens com atraso e sem atraso 
# * em proporções semelhantes.
# df_rides %>%
#   filter(!is.na(ride_late)) %>%
#   ggplot(aes(x = user_age, y = ride_late)) +
#   geom_jitter(alpha = 0.05, height = 0.02, color = "#C0392B") +
#   labs(title = "Atraso vs Idade (visão contínua)", x = "Idade", y = "Atraso?") +
#   theme_minimal()

# ==============================================================================
# 4.4 ANÁLISE POR GÊNERO
# ==============================================================================

# Divisão Geral (Frequência Relativa)
# Nota: Predominância Masculina (74%) observada nos dados brutos.
df_rides %>%
  filter(!is.na(user_gender)) %>%
  count(user_gender) %>%
  mutate(
    pct = n / sum(n), 
    label = scales::percent(pct, accuracy = 0.1)
  ) %>%
  ggplot(aes(x = user_gender, y = n, fill = user_gender)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = label), vjust = -0.5, fontface = "bold") +
  scale_fill_manual(values = c("F" = paleta_bike$alerta, "M" = paleta_bike$principal)) +
  labs(
    title = "Divisão por Gênero", 
    subtitle = "Frequência absoluta e relativa de viagens", 
    x = "Gênero", 
    y = "Total de Viagens"
  ) +
  theme_minimal()

# Gênero x Horário (Análise de Segurança e Rotina)
# * Curvas similares indicam que não há barreira de horário específica.
# * Não há evidência forte de restrição temporal feminina no uso do sistema.
df_rides %>%
  filter(!is.na(user_gender)) %>%
  ggplot(aes(x = hora_inicio, color = user_gender, fill = user_gender)) +
  geom_density(alpha = 0.3) +
  scale_color_manual(values = c("F" = paleta_bike$alerta, "M" = paleta_bike$principal)) +
  scale_fill_manual(values = c("F" = paleta_bike$alerta, "M" = paleta_bike$principal)) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  labs(
    title = "Rotina Diária: Homens vs Mulheres", 
    subtitle = "Distribuição de densidade ao longo das 24 horas",
    x = "Hora do Dia", 
    y = "Densidade"
  ) +
  theme_minimal()

# Gênero x Duração (Comportamento de Uso)
# * Insight: Mulheres tendem a viagens levemente mais longas (Cuidado/Lazer?)
df_rides %>%
  filter(!is.na(user_gender), ride_duration < 60) %>%
  ggplot(aes(x = user_gender, y = ride_duration, fill = user_gender)) +
  geom_boxplot(alpha = 0.7, width = 0.5, outlier.shape = NA) +
  stat_summary(fun = mean, geom = "point", shape = 18, size = 3, color = "white") +
  scale_fill_manual(values = c("F" = paleta_bike$alerta, "M" = paleta_bike$principal)) +
  labs(
    title = "Duração da Viagem por Gênero", 
    subtitle = "Viagens < 60 min | Ponto branco representa a média",
    y = "Duração (Minutos)",
    x = "Gênero"
  ) +
  theme_minimal() + 
  theme(legend.position = "none")

# Pirâmide Etária (Interação Idade x Gênero)
# * Distribuições etárias semelhantes; a diferença maior é volume, não forma.
ggplot(df_rides, aes(x = user_age, fill = user_gender)) +
  geom_histogram(
    data = subset(df_rides, user_gender == "F"), 
    aes(y = after_stat(count)), 
    binwidth = 2, alpha = 0.7
  ) +
  geom_histogram(
    data = subset(df_rides, user_gender == "M"), 
    aes(y = -after_stat(count)), 
    binwidth = 2, alpha = 0.7
  ) +
  coord_flip() +
  scale_y_continuous(labels = abs) +
  scale_fill_manual(values = c("F" = paleta_bike$alerta, "M" = paleta_bike$principal)) +
  labs(
    title = "Pirâmide Etária do Sistema +Bike", 
    subtitle = "Distribuição demográfica por idade e gênero",
    x = "Idade", 
    y = "Volume de Usuários (F <-> M)", 
    fill = "Gênero"
  ) +
  theme_minimal()

# ==============================================================================
# 4.5 GÊNERO E RISCO OPERACIONAL (ATRASOS)
# ==============================================================================

# Sumário Estatístico de Atraso
df_rides %>%
  filter(!is.na(user_gender), !is.na(ride_late)) %>%
  group_by(user_gender) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late, na.rm = TRUE),
    .groups = "drop"
  )

# Visualização da Taxa de Atraso
# * Insight: O feminino tende a apresentar taxa de atraso superior ao masculino.
df_rides %>%
  filter(!is.na(user_gender), !is.na(ride_late)) %>%
  group_by(user_gender) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = user_gender, y = taxa_atraso, fill = user_gender)) +
  geom_col(width = 0.6) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_manual(values = c("F" = paleta_bike$alerta, "M" = paleta_bike$principal)) +
  labs(
    title = "Taxa de Atraso por Gênero", 
    subtitle = "O gênero segmenta padrões com consequências operacionais",
    y = "% de Viagens com Atraso", 
    x = "Gênero"
  ) +
  theme_minimal()

# Interação Gênero x Horário x Atraso
# * Nota: O comportamento estável ocorre entre 06h e 22h. 
# * Picos em 00h-05h devem-se ao baixíssimo volume (ruído estatístico).
df_rides %>%
  filter(!is.na(user_gender), !is.na(ride_late)) %>%
  group_by(user_gender, hora_inicio) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = hora_inicio, y = taxa_atraso, color = user_gender)) +
  geom_line(linewidth = 0.8) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  scale_color_manual(values = c("F" = paleta_bike$alerta, "M" = paleta_bike$principal)) +
  labs(
    title = "Risco de Atraso ao Longo do Dia por Gênero", 
    subtitle = "Análise de estabilidade temporal do risco",
    x = "Hora de Início", 
    y = "% de Atrasos"
  ) +
  theme_minimal()

# Interação Gênero x Idade x Atraso (Check final de segmentação)
# * Insight: Mulheres de 55-64 anos possuem taxa de atraso > 20%, homens < 10%.
df_rides %>%
  filter(!is.na(user_gender), !is.na(ride_late), !is.na(user_age_group_exp)) %>%
  group_by(user_gender, user_age_group_exp) %>%
  summarise(taxa_atraso = mean(ride_late, na.rm = TRUE), .groups = "drop") %>%
  ggplot(aes(x = user_age_group_exp, y = taxa_atraso, fill = user_gender)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_manual(values = c("F" = paleta_bike$alerta, "M" = paleta_bike$principal)) +
  labs(
    title = "Taxa de Atraso por Faixa Etária e Gênero", 
    subtitle = "Gênero como moderador real do risco operacional",
    x = "Faixa Etária", 
    y = "% de Atrasos",
    fill = "Gênero"
  ) +
  theme_minimal()

# ==============================================================================
# 4.6 GEOGRAFIA / RESIDÊNCIA
# ==============================================================================

# Definindo paleta específica para os clusters geográficos 
paleta_geo <- c(
  "Local (DF)" = "#E74C3C",        # Vermelho
  "Não Informado" = "#2ECC71",     # Verde
  "Outros / Turistas" = "#3498DB"  # Azul
)

# Residência dos Usuários (Visão Bruta)
# * A maior dúvida era: Quem são os 63,9% que não informaram residência?
ggplot(df_rides, aes(x = fct_infreq(user_residence))) +
  geom_bar(fill = "gray70") +
  geom_bar(
    data = subset(df_rides, user_residence == "NAO INFORMADO"),
    fill = paleta_bike$alerta
  ) +
  labs(
    title = "Distribuição da Variável de Residência",
    subtitle = "A barra vermelha indica volume de dados não informados (~63%)",
    x = "Residência (Agrupada)",
    y = "Número de Viagens"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Perfil geográfico entre registros válidos
# * Depois do DF, a maior origem é Goiás (GO). 
# * Confirma o uso pendular (moram no entorno, trabalham no DF).
df_rides %>%
  filter(user_residence != "NAO INFORMADO") %>%
  ggplot(aes(x = fct_infreq(user_residence))) +
  geom_bar(fill = paleta_bike$secundaria) +
  geom_text(
    stat = 'count', aes(label = after_stat(count)),
    vjust = -0.5, size = 3
  ) +
  labs(
    title = "Perfil Geográfico dos Usuários Identificados",
    subtitle = "Distribuição entre localidades válidas (37% dos registros)",
    x = "Residência (Agrupada)",
    y = "Total de Viagens"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# Composição Etária por Região (Geografia x Idade)
# * Residência está capturando vínculo com a cidade, não localização física pontual.
df_rides %>%
  ggplot(aes(x = user_residence, fill = user_age_group_exp)) +
  geom_bar(position = "fill", width = 0.8) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_brewer(palette = "Blues") +
  labs(
    title = "Perfil Etário por Região Informada", 
    y = "Proporção", 
    x = NULL,
    fill = "Faixa Etária"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5))

# ==============================================================================
# 4.6.1 ANÁLISE DO CLUSTER GEOGRÁFICO (FAMILIARIDADE)
# > geo_cluster ≈ familiaridade operacional com o sistema
# ==============================================================================

# Frequência por cluster geográfico
df_rides %>%
  count(geo_cluster) %>%
  mutate(pct = n / sum(n)) %>%
  ggplot(aes(x = geo_cluster, y = n, fill = geo_cluster)) +
  geom_col(width = 0.7) +
  geom_text(
    aes(label = scales::percent(pct, accuracy = 0.1)),
    vjust = -0.3, size = 3
  ) +
  scale_y_continuous(
    labels = scales::comma,
    expand = expansion(mult = c(0, 0.15))
  ) +
  scale_fill_manual(values = paleta_geo) +
  labs(
    title = "Distribuição de Usuários por Cluster Geográfico",
    x = NULL,
    y = "Número de Viagens"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

# Residência × Duração (Familiaridade em ação)
# * Locais (DF) e Não Informados → viagens curtas (~12 min) e pouca dispersão.
# * Outros / Turistas → maior dispersão e medianas mais altas.
# > Familiaridade reduz risco de atraso.
# > Tratar “Não Informado” como Local é defensável e reduz ruído estatístico.
df_rides %>%
  filter(ride_duration < 60) %>%
  ggplot(aes(x = geo_cluster, y = ride_duration, fill = geo_cluster)) +
  geom_boxplot(alpha = 0.7, outlier.shape = NA) +
  scale_fill_manual(values = paleta_geo) +
  labs(
    title = "Duração da Viagem por Tipo de Residência",
    subtitle = "Comportamento idêntico entre 'Local' e 'Não Informado'",
    x = NULL,
    y = "Duração (Minutos)"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

# Residência × Horário (Uso funcional vs recreativo)
# * A curva azul (Turistas) sobe suavemente até o fim da tarde (16h-18h), típico de passeio.
# * O grupo "Não Informado" NÃO é ruído. São residentes locais que pularam o cadastro.
df_rides %>%
  ggplot(aes(x = hora_inicio, fill = geo_cluster, color = geo_cluster)) +
  geom_density(alpha = 0.25) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  scale_fill_manual(values = paleta_geo) +
  scale_color_manual(values = paleta_geo) +
  labs(
    title = "Padrões Horários por Residência",
    x = "Hora do Dia",
    y = "Densidade",
    fill = "Cluster", color = "Cluster"
  ) +
  theme_minimal()

# ==============================================================================
# 4.6.2 GEOGRAFIA E RISCO DE ATRASO
# ==============================================================================

# Residência × Atraso (Pergunta de negócio direta)
# * Turistas são os que mais atrasam (12,5% vs 8,9% dos locais). Feature preditiva.
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
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = geo_cluster, y = taxa_atraso, fill = geo_cluster)) +
  geom_col(width = 0.6) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_manual(values = paleta_geo) +
  labs(
    title = "Taxa de Atraso por Tipo de Residência",
    x = NULL,
    y = "% de Atrasos"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

# Residência × Idade × Atraso (Interação crítica)
# * 08-17 anos: altas taxas em todos os grupos (>10%). Falta de responsabilidade/desconhecimento.
# * Idosos "Não Informados": taxa explosiva (>23%). 
# * Residência e Idade trazem informações complementares, não redundantes.
df_rides %>%
  filter(!is.na(ride_late), !is.na(user_age_group_exp)) %>%
  group_by(geo_cluster, user_age_group_exp) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = user_age_group_exp, y = taxa_atraso, fill = geo_cluster)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_manual(values = paleta_geo) +
  labs(
    title = "Taxa de Atraso por Idade e Residência",
    x = "Faixa Etária",
    y = "% de Atrasos",
    fill = "Cluster"
  ) +
  theme_minimal()

# Residência × Horário × Atraso
# * Vermelho (Local) e Verde (Não Informado) andam coladas: sobem às 10h/16h e descem às 13h.
# * Enterra dúvidas: perfil de risco do Não Informado é a persona do Residente DF.
# * Azul (Turistas) descola para cima entre 09h e 18h.
# * Picos (10h e 16h) indicam momentos críticos para envio de push notifications.
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(geo_cluster, hora_inicio) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = hora_inicio, y = taxa_atraso, color = geo_cluster)) +
  geom_line(linewidth = 0.8) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  scale_color_manual(values = paleta_geo) +
  labs(
    title = "Risco de Atraso por Hora e Residência",
    subtitle = "Análise temporal da estabilidade do risco por cluster",
    x = "Hora do Dia",
    y = "% de Atrasos",
    color = "Cluster"
  ) +
  theme_minimal()

# Heatmap: Densidade de Usuários (Idade x Residência)
# * O "Não Informado" é massivamente Jovem (18-24). 
# * Usuários 35+ tendem a preencher o cadastro proporcionalmente mais.
df_rides %>%
  filter(!is.na(user_age_group_exp)) %>% 
  count(geo_cluster, user_age_group_exp) %>%
  ggplot(aes(x = user_age_group_exp, y = geo_cluster, fill = n)) +
  geom_tile() +
  geom_text(
    aes(label = scales::number(n, big.mark = ".", accuracy = 1)), 
    color = "white", size = 3.5, fontface = "bold"
  ) +
  scale_fill_viridis_c(option = "turbo", direction = -1) +
  labs(
    title = "Matriz de Densidade: Idade x Residência",
    subtitle = "Concentração de massa em 'Não Informados' Jovens (18-24)",
    x = "Faixa Etária",
    y = "Cluster Geográfico",
    fill = "Viagens"
  ) +
  theme_minimal()

# ==============================================================================
# SÍNTESE ESTRATÉGICA (DECISÕES PARA MODELAGEM)
# ✅ “Não Informado” → tratar como Local
# ✅ “Outros” → manter como cluster comportamental (Turistas)
# ✅ Idade é variável crítica (com efeitos não lineares)
# ⚠️ Idosos + Não Informado = risco sistêmico, não comportamental
# ✅ Atraso não é aleatório — é explicável e previsível
# ==============================================================================


# ==============================================================================
# 5. PADRÕES TEMPORAIS E SAZONALIDADE
# ==============================================================================
# Pergunta central: Quando o sistema falha mais?

# Definindo paleta temporal para consistência visual
paleta_tempo <- c(
  "Dia Útil" = paleta_bike$principal, # Azul
  "Fim de Semana" = "#E67E22"         # Laranja (Destacando o lazer/risco)
)

# Criar variáveis temporais
df_rides <- df_rides %>%
  mutate(
    weekday = wday(ride_date, label = TRUE, week_start = 1),
    is_weekend = weekday %in% c("sáb", "dom"),
    month = month(ride_date, label = TRUE)
  )

# Sumários rápidos de sanidade
# summary(df_rides$weekday) 
# summary(df_rides$is_weekend) # 60408 viagens no FDS
# summary(df_rides$month)

# ==============================================================================
# 5.1 ANÁLISE DIÁRIA E SEMANAL
# ==============================================================================

# Atraso x Dia da semana
# > O sistema falha mais em dias úteis ou no fim de semana?
# > Atraso ligado a uso recreativo / turistas. Fim de Semana = + atrasos.
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(weekday) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = weekday, y = taxa_atraso)) +
  geom_col(fill = paleta_bike$principal, width = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Taxa de Atraso por Dia da Semana",
    subtitle = "Forte indicativo de diferença entre uso funcional e recreativo",
    x = "Dia da Semana",
    y = "% de Atrasos"
  ) +
  theme_minimal()

# Qual a diferença em atrasos em dia útil ou fim de semana?
# > Fim de Semana tende a ter risco de atrasos até 3x maiores.
# > Diferença grande → atraso contextual, não aleatório.
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(is_weekend) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
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

# ==============================================================================
# 5.2 ANÁLISE INTRADIÁRIA (HORA A HORA)
# ==============================================================================

# Atraso ao longo do dia
# > Existe “hora crítica” de atraso?
# > Picos às 10h e 16h; uso estável das 5h às 23h.
# > Madrugadas apresentam chances absurdas de atrasos (baixo volume, alto risco).
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(hora_inicio) %>%
  summarise(
    taxa_atraso = mean(ride_late),
    viagens = n(),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = hora_inicio, y = taxa_atraso)) +
  geom_line(linewidth = 0.9, color = paleta_bike$alerta) +
  geom_point(size = 2, color = paleta_bike$alerta) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  labs(
    title = "Risco de Atraso ao Longo do Dia",
    subtitle = "Picos de risco observados às 10h e 16h",
    x = "Hora de Início",
    y = "% de Atrasos"
  ) +
  theme_minimal()

# Interação crítica: hora × fim de semana
# > O risco horário muda quando é fim de semana?
# > Como visto o risco aumenta muito nos fim de semana, em qualquer hora do dia.
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(is_weekend, hora_inicio) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = hora_inicio, y = taxa_atraso, color = is_weekend)) +
  geom_line(linewidth = 0.9) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(0, 23, 2)) +
  labs(
    title = "Risco de Atraso por Hora e Tipo de Dia",
    x = "Hora de Início",
    y = "% de Atrasos",
    color = "Tipo de Dia"
  ) +
  theme_minimal()

# ==============================================================================
# 5.3 ANÁLISE MENSAL (SAZONALIDADE)
# ==============================================================================

# Volume de viagens por mês
# > O sistema muda de perfil ao longo do ano?
# > Crescimento de Jan → Ago (maior adesão, clima favorável, maturação do sistema).
df_rides %>%
  group_by(month) %>%
  summarise(viagens = n(), .groups = "drop") %>%
  ggplot(aes(x = month, y = viagens)) +
  geom_col(fill = "#95A5A6", width = 0.7) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Volume de Viagens por Mês",
    subtitle = "Jan–Ago 2018: Aumento contínuo de adesão",
    x = "Mês",
    y = "Número de Viagens"
  ) +
  theme_minimal()

# Taxa de atraso por mês
# > O risco muda ao longo do ano?
# > Maiores riscos de atrasos: Jan, Abr, Jul (meses típicos de férias/feriados).
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(month) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  ggplot(aes(x = month, y = taxa_atraso)) +
  geom_col(fill = paleta_bike$alerta, width = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Taxa de Atraso por Mês",
    subtitle = "Sazonalidade de risco operacional (Férias e Feriados)",
    x = "Mês",
    y = "% de Atrasos"
  ) +
  theme_minimal()

# Mês × Fim de semana
# > O atraso alto no fim de semana é constante ou sazonal?
# > Em dias úteis os atrasos são constantes em todos os meses (~6-8%).
# > No fim de semana, os atrasos sobem para ~16-24%. O atraso é comportamental.
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(month, is_weekend) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = month, y = taxa_atraso, fill = is_weekend)) +
  geom_col(position = "dodge", width = 0.7) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Taxa de Atraso por Mês e Tipo de Dia",
    subtitle = "O risco do Fim de Semana é estrutural, independe do mês",
    x = "Mês",
    y = "% de Atrasos",
    fill = "Tipo de Dia"
  ) +
  theme_minimal()

# Hora × Mês
# > O padrão horário é estável; o que muda é a intensidade do risco.
# > Abr e Jul concentram as viagens do 'problema da madrugada'.
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(month, hora_inicio) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = hora_inicio, y = taxa_atraso, color = month)) +
  geom_line(linewidth = 0.8) +
  scale_y_continuous(labels = scales::percent) +
  scale_x_continuous(breaks = seq(0, 23, 4)) +
  scale_color_viridis_d(option = "turbo") + # Paleta viridis para diferenciar meses
  labs(
    title = "Risco de Atraso por Hora ao Longo dos Meses",
    x = "Hora de Início",
    y = "% de Atrasos",
    color = "Mês"
  ) +
  theme_minimal()

# ==============================================================================
# SÍNTESE ESTRATÉGICA TEMPORAL
# 🚦 Atraso não é ruído — é evento previsível condicionado ao tempo.
# ==============================================================================

# ==============================================================================
# 6. REDE E ESTAÇÕES (DIAGNÓSTICO CAUSAL)
# ==============================================================================
# Pergunta central: Existem “estações problema” recorrentes?

# skim(df_stations)
# skim(df_rides)

# ==============================================================================
# 6.1 DIAGNÓSTICO DE ESTAÇÕES (ORIGEM VS DESTINO)
# ==============================================================================

# Taxa de atraso por estação de saída (Origem)
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_start) %>%
  summarise(
    viagens = n(),
    taxa_atraso = mean(ride_late),
    .groups = "drop"
  ) %>%
  filter(viagens >= 500) %>%  # Filtro de sanidade estatística
  arrange(desc(taxa_atraso)) %>%
  print(n = 15)

# Visualização: Estações de Origem Críticas
# > Algumas estações concentram atrasos independentemente de quem usa.
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_start) %>%
  summarise(viagens = n(), taxa_atraso = mean(ride_late), .groups = "drop") %>%
  filter(viagens >= 500) %>%
  ggplot(aes(x = fct_reorder(station_start, taxa_atraso), y = taxa_atraso)) +
  geom_col(fill = paleta_bike$alerta) +
  coord_flip() +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Estações com Maior Taxa de Atraso (Origem)",
    x = "Estação",
    y = "% de Atrasos"
  ) +
  theme_minimal()

# Taxa de atraso por estação de chegada (Destino)
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
  print(n = 15)

# Visualização: Estações de Destino Críticas
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_end) %>%
  summarise(viagens = n(), taxa_atraso = mean(ride_late), .groups = "drop") %>%
  filter(viagens >= 500) %>%
  ggplot(aes(x = fct_reorder(station_end, taxa_atraso), y = taxa_atraso)) +
  geom_col(fill = "#E67E22") + # Laranja para diferenciar do vermelho da Origem
  coord_flip() +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Estações com Maior Taxa de Atraso (Destino)",
    x = "Estação",
    y = "% de Atrasos"
  ) +
  theme_minimal()

# Taxa de atraso por par de estações (Rotas)
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_start, station_end) %>%
  summarise(viagens = n(), taxa_atraso = mean(ride_late), .groups = "drop") %>%
  filter(viagens >= 200) %>%
  arrange(desc(taxa_atraso)) %>%
  print(n = 15)

# ==============================================================================
# 6.2 VOLUME, FLUXO E GARGALOS FÍSICOS
# ==============================================================================

# Volume total: Estações centrais sofrem mais pressão?
# > Existem gargalos fixos na rede, não eventos esporádicos.
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
  print(n = 15)

# Fluxo x Atrasos (Destino)
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_end) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  left_join(
    df_rides %>% count(station_end, name = "entrada"),
    by = "station_end"
  ) %>%
  ggplot(aes(x = entrada, y = taxa_atraso)) +
  geom_point(alpha = 0.6, color = paleta_bike$neutra) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Volume da Estação × Taxa de Atraso (Destino)",
    x = "Número de Chegadas",
    y = "% de Atrasos"
  ) +
  theme_minimal()

# Estação x Horário: O problema muda no tempo?
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(station_end, hora_inicio) %>%
  summarise(taxa_atraso = mean(ride_late), viagens = n(), .groups = "drop") %>%
  filter(viagens >= 100) %>%
  print(n = 15)

# ==============================================================================
# 6.3 ONDE O ATRASO NASCE? (RETIRADA VS DEVOLUÇÃO)
# ==============================================================================

top_stations <- c(
  "15 - Brasil 21", "4 - Torre de TV", "16 - SRTVS",
  "5 - Setor Hoteleiro Norte", "32 - SQS 305", "12 - Rodoviária 3"
)

# Criando bloco comparativo
df_blocA <- df_rides %>%
  filter(
    !is.na(ride_late),
    station_start %in% top_stations | station_end %in% top_stations
  ) %>%
  mutate(
    tipo_risco = case_when(
      station_end %in% top_stations ~ "Devolução",
      station_start %in% top_stations ~ "Retirada"
    )
  )

# Resultado agregado
# > O atraso nasce majoritariamente na DEVOLUÇÃO.
df_blocA %>%
  group_by(tipo_risco) %>%
  summarise(viagens = n(), taxa_atraso = mean(ride_late), .groups = "drop")

# > O usuário até consegue pegar a bike, mas não consegue devolver onde quer.
df_blocA %>%
  group_by(tipo_risco) %>%
  summarise(taxa_atraso = mean(ride_late)) %>%
  ggplot(aes(x = tipo_risco, y = taxa_atraso, fill = tipo_risco)) +
  geom_col(width = 0.6) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_manual(values = c("Devolução" = paleta_bike$alerta, "Retirada" = paleta_bike$principal)) +
  labs(
    title = "Onde o Atraso se Origina?",
    subtitle = "Comparação entre Retirada e Devolução em Estações Críticas",
    x = NULL,
    y = "% de Atrasos"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

# Todas as estações sofrem do mesmo problema? > Sim.
df_blocA %>%
  group_by(
    station = if_else(tipo_risco == "Devolução", station_end, station_start), 
    tipo_risco
  ) %>%
  summarise(viagens = n(), taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = fct_reorder(station, taxa_atraso), y = taxa_atraso, fill = tipo_risco)) +
  geom_col(position = "dodge") +
  coord_flip() +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_manual(values = c("Devolução" = paleta_bike$alerta, "Retirada" = paleta_bike$principal)) +
  labs(
    title = "Retirada vs Devolução — Diagnóstico por Estação",
    x = "Estação",
    y = "% de Atrasos",
    fill = "Tipo de Risco"
  ) +
  theme_minimal()

# ==============================================================================
# 6.4 DESEQUILÍBRIO DE FLUXO (CAUSA RAIZ)
# ==============================================================================

# Construir métricas de fluxo por estação
df_fluxo <- df_rides %>%
  count(station_start, name = "saidas") %>%
  full_join(
    df_rides %>% count(station_end, name = "entradas"),
    by = c("station_start" = "station_end")
  ) %>%
  mutate(
    saidas      = replace_na(saidas, 0),
    entradas    = replace_na(entradas, 0),
    fluxo_total = saidas + entradas,
    saldo_fluxo = entradas - saidas
  )

# Fluxo com atraso (Diagnóstico Causal)
df_fluxo_atraso <- df_fluxo %>%
  left_join(
    df_rides %>%
      filter(!is.na(ride_late)) %>%
      group_by(station_end) %>%
      summarise(taxa_atraso = mean(ride_late), .groups = "drop"),
    by = c("station_start" = "station_end")
  )

# Saldo × Atraso
# > Lado direito (saldo positivo) → taxas de atraso maiores. Lado esquerdo → atraso menor.
# > O atraso é consequência direta do acúmulo de bicicletas em estações específicas.
ggplot(df_fluxo_atraso, aes(x = saldo_fluxo, y = taxa_atraso)) +
  geom_point(alpha = 0.7, color = paleta_bike$neutra) +
  geom_vline(xintercept = 0, linetype = "dashed", color = paleta_bike$alerta) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Desequilíbrio de Fluxo × Taxa de Atraso",
    
    x = "Saldo de Fluxo (Entradas − Saídas)",
    y = "% de Atrasos"
  ) +
  geom_smooth(method = "lm", se = FALSE, color = "blue") +
  theme_minimal()

# Acúmulo horário e atraso por estação
# > O sistema entra em colapso local quando: muita gente chega, poucas bikes saem.
# > O usuário não causa o atraso — ele é exposto a estações problemáticas.
df_rides %>%
  group_by(station_end, hora_inicio) %>%
  summarise(entradas = n(), taxa_atraso = mean(ride_late, na.rm = TRUE), .groups = "drop") %>%
  filter(entradas >= 100) %>%
  ggplot(aes(x = hora_inicio, y = taxa_atraso)) +
  geom_line(color = paleta_bike$alerta, alpha = 0.5) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Acúmulo Horário e Atraso por Estação",
    subtitle = "O risco cresce quando o fluxo se concentra em janelas específicas",
    x = "Hora",
    y = "% de Atrasos"
  ) +
  theme_minimal()


# ==============================================================================
# 6.5 EXPOSIÇÃO AO RISCO E IMPACTO HUMANO
# ==============================================================================

# Definir “estações críticas” (Top 25% piores)
stations_criticas <- df_fluxo_atraso %>%
  filter(
    saldo_fluxo > quantile(saldo_fluxo, 0.75, na.rm = TRUE),
    taxa_atraso > quantile(taxa_atraso, 0.75, na.rm = TRUE)
  ) %>%
  pull(station_start)

df_rides <- df_rides %>%
  mutate(estacao_critica = station_end %in% stations_criticas)

# Perfil × Tipo de Dia × Estação Crítica
# > O mesmo gargalo estrutural se torna muito mais severo no fim de semana.
df_rides %>%
  filter(!is.na(ride_late)) %>%
  group_by(geo_cluster, is_weekend, estacao_critica) %>%
  summarise(taxa_atraso = mean(ride_late), .groups = "drop") %>%
  ggplot(aes(x = estacao_critica, y = taxa_atraso, fill = geo_cluster)) +
  geom_col(position = "dodge") +
  facet_wrap(~ is_weekend, labeller = as_labeller(c(
    "FALSE" = "Dia Útil", "TRUE" = "Fim de Semana"
  ))) +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Quem Sofre com Estações Críticas?",
    subtitle = "O impacto explode para turistas no fim de semana",
    x = "Estação Crítica (Destino)",
    y = "% de Atrasos",
    fill = "Perfil Geográfico"
  ) +
  theme_minimal()

# ==============================================================================
# 6.6 TEMPO EXTRA (PROVA CAUSAL DE PROCURA POR VAGA)
# ==============================================================================

# Distribuição de duração: Atrasados vs Não atrasados
df_rides %>%
  filter(!is.na(ride_late), ride_duration < 120) %>%
  ggplot(aes(x = ride_duration, fill = ride_late)) +
  geom_histogram(binwidth = 2, alpha = 0.6, position = "identity") +
  scale_fill_manual(
    values = c("FALSE" = paleta_bike$principal, "TRUE" = paleta_bike$alerta),
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

# Calcular excesso de duração em relação ao padrão da rota
duracao_referencia <- df_rides %>%
  filter(!is.na(ride_duration)) %>%
  group_by(station_start, hora_inicio) %>%
  summarise(dur_mediana_ref = median(ride_duration), .groups = "drop")

df_rides <- df_rides %>%
  left_join(duracao_referencia, by = c("station_start", "hora_inicio")) %>%
  mutate(excesso_duracao = ride_duration - dur_mediana_ref)

# Excesso de duração × Atraso (Prova Causal)
# > Um limiar operacional: Atraso é consequência de falha na devolução.
df_rides %>%
  filter(!is.na(ride_late), excesso_duracao > -5, excesso_duracao < 60) %>%
  ggplot(aes(x = excesso_duracao, fill = ride_late)) +
  geom_histogram(binwidth = 2, alpha = 0.6, position = "identity") +
  scale_fill_manual(values = c("FALSE" = paleta_bike$principal, "TRUE" = paleta_bike$alerta)) +
  labs(
    title = "Excesso de Duração da Viagem",
    subtitle = "O atraso nasce no tempo extra procurando vaga, não no pedal inicial",
    x = "Minutos além do esperado",
    y = "Viagens",
    fill = "Atraso"
  ) +
  theme_minimal()

# Quanto tempo extra o usuário perde nas estações críticas?
# > O atraso não é pedalar mais. É tempo improdutivo no final.
# > Após ~15–20 minutos extras, o atraso se torna praticamente inevitável.
df_rides %>%
  filter(ride_late, excesso_duracao > 0) %>%
  group_by(estacao_critica) %>%
  summarise(
    mediana_extra = median(excesso_duracao),
    p75_extra = quantile(excesso_duracao, 0.75),
    .groups = "drop"
  )

# ==============================================================================
# SÍNTESE CAUSAL (CONCLUSÃO DO EDA)
# ==============================================================================
# → Desequilíbrio de fluxo geográfico
# → Acúmulo de bikes no destino (Saldo Positivo)
# → Saturação física das docas
# → Falha na devolução (Impossibilidade de encerrar a viagem)
# → Tempo extra improdutivo (Usuário rodando procurando vaga)
# → Atraso e penalidade tarifária
# → Impacto desigual em perfis vulneráveis (Turistas, Jovens, Idosos)
# → Amplificação do problema aos fins de semana
# ==============================================================================
# FIM DO SCRIPT DE EDA
# ==============================================================================

# Salvar dados preparados, para usar na Modelagem Preditiva
output_dir <- "arquivos/outputs"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

stamp <- format(Sys.Date(), "%Y%m%d")

# 1. RDS (Preserva tipos R)
saveRDS(df_rides, file.path(output_dir, paste0("df_rides_eda_", stamp, ".rds")))
saveRDS(df_stations, file.path(output_dir, paste0("df_stations_eda_", stamp, ".rds")))

# 2. CSV (Interoperabilidade)
df_rides %>%
  mutate(across(where(is.factor), as.character)) %>% 
  write.csv(file.path(output_dir, paste0("df_rides_eda_", stamp, ".csv")), row.names = FALSE, fileEncoding = "UTF-8")

df_stations %>%
  mutate(across(where(is.factor), as.character)) %>% 
  write.csv(file.path(output_dir, paste0("df_stations_eda_", stamp, ".csv")), row.names = FALSE, fileEncoding = "UTF-8")

message("\n✅ Processo concluído! Arquivos salvos em: ", output_dir)


# Remove TUDO do ambiente, EXCETO o dataframe final 'df_rides_clean'
rm(list = setdiff(ls(), "df_rides_eda"))

# Libera a memória RAM
gc()

message("🧹 Ambiente limpo! Apenas 'df_rides_eda' foi mantido.") 

