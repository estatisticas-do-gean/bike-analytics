#  Análise Exploratória de Dados (EDA)
library(skimr)
library(tidyverse)
library(lubridate)
library(ggplot2)
#---------------------------------------------------------#
# Diretório de trabalho
setwd() # Defina seu diretório de trabalho aqui
#---------------------------------------------------------#

# Carregar os dados preparados

df_rides_clean <- readRDS(here::here("arquivos", "df_rides_clean.rds"))

## Com isso, você evita a etapa de limpeza toda vez que for analisar os dados, garantindo velocidade e reprodutibilidade.

glimpse(df_rides_clean)
summary(df_rides_clean)
skim(df_rides_clean)


