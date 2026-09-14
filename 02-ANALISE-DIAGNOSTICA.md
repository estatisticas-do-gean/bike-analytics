# Como os dados estão organizados?

Nesta etapa, é realizada a inspeção técnica dos dados brutos importados para o ambiente R. O objetivo é mapear a estrutura original, definir a tipagem correta para análise e identificar inconsistências que exijam tratamento ou limpeza antes da fase de exploração e modelagem.

Como visto, o *dataset* é composto por dois dataframes principais:

1. **`df_rides` (Tabela Fato):** Composta por 287.322 registros e 10 variáveis iniciais. Ela registra o perfil básico do usuário (gênero, data de nascimento, estado de residência) e a telemetria da viagem (estação e horário de início/fim, duração e indicativo de atraso).

2. **`df_stations` (Tabela Dimensão):** Tabela dimensional menor, com 49 registros e 5 variáveis, servindo como catálogo das estações (nome, número e coordenadas geográficas).

---

Para garantir a integridade das análises futuras, foi realizada uma etapa de conversão de tipos (*Data Type Casting*) e padronização.

**Na base de Estações:**

Tabela de consulta (*Lookup Table*) contendo os metadados das estações.

| **Variável** | **Tipo Original** | **Tipo Alvo** | **Justificativa Técnica e Ação** |
| --- | --- | --- | --- |
| `station` | `<chr>` | **`<chr>`** | Chave primária textual. |
| `station_number` | `<int>` | **`<int>`** | ID numérico auxiliar. |
| `station_name` | `<chr>` | **`<chr>`** | Nome descritivo. **Atenção:** Detectado espaço em branco (*trailing whitespace*). |
| `lat` | `<dbl>` | **`<dbl>`** | Coordenada geográfica (Latitude). |
| `lon` | `<dbl>` | **`<dbl>`** | Coordenada geográfica (Longitude). |

- Foi confirmada a integridade estrutural 1-1 entre os códigos (`station_number`) e os nomes (`station_name`). Não existem estações duplicadas ou com códigos sobrepostos.

- Os nomes passaram por uma padronização rigorosa: remoção de espaços duplos e acentuação, o que previne erros de agrupamento (*group by*) no futuro.

**Na base de Viagens:**

A inspeção inicial revelou a necessidade de conversão de tipos (*casting*) e criação de variáveis temporais compostas.

| **Variável** | **Tipo Original** | **Tipo Alvo** | **Justificativa Técnica e Ação** |
| :--- | :--- | :--- | :--- |
| `user_gender` | `<chr>` | **`<fct>`** | Variável categórica nominal. Conversão para `factor` otimiza armazenamento e plotagem. |
| `user_birthdate` | `<chr>` | **`<date>`** | Necessário converter para cálculo de idade e validação de consistência. |
| `user_residence` | `<chr>` | **`<fct>`** | Variável categórica nominal. |
| `ride_date` | `<chr>` | **`<date>`** | Base temporal primária da viagem. |
| `time_start` | `<chr>` | **`<dttm>`** | **Ação:** Concatenar com `ride_date` para criar um timestamp completo (*datetime*). |
| `time_end` | `<chr>` | **`<dttm>`** | **Ação:** Concatenar com `ride_date` para criar um timestamp completo (*datetime*). |
| `station_start` | `<chr>` | **`<fct>`** | Variável categórica (ID da estação de origem). |
| `station_end` | `<chr>` | **`<fct>`** | Variável categórica (ID da estação de destino). |
| `ride_duration` | `<dbl>` | **`<dbl>`** | Variável numérica contínua. Mantém-se inalterada. |
| `ride_late` | `<int>` | **`<lgl>`** | Variável binária (0/1). Conversão para lógico (`TRUE/FALSE`) para clareza semântica. |

- As variáveis textuais foram convertidas adequadamente para fatores (variáveis categóricas).

- Foram criadas duas novas variáveis temporais completas (`datetime_start` e `datetime_end`) combinando as colunas de data e hora`, estas variáveis auxiliarão nas análises posteriores.

- Diagnóstico de *Parsing*: A conversão da data/hora de início teve 100% de sucesso. No entanto, a data/hora de fim retornou 43.285 falhas, o que indica viagens que não foram encerradas corretamente no sistema ou erros de captação de dados no momento da devolução.

---

A análise da completude dos dados (via `skimr` e *ranking* de NAs) revelou gargalos importantes que exigirão tratamentos antes da modelagem preditiva ou análise exploratória de negócio:

| **Variável** | **Valores Ausentes (NA)** | **% do Total** | **Impacto e Observações Didáticas** |
| --- | --- | --- | --- |
| `user_residence` | 179.905 | ~62,6% | A maioria dos usuários não preencheu o estado de residência. O uso dessa variável para traçar o perfil geográfico será enviesado aos 37% que preencheram. |
| `ride_duration` | 73.174 | ~25,4% | Um quarto das viagens não possui duração calculada. |
| `ride_late` | 73.174 | ~25,4% | O mesmo volume da duração. Sugere que a regra de negócio que define se a viagem está atrasada depende do cálculo da duração. |
| `time_end` / `datetime_end` | 43.285 | ~15,0% | Viagens sem horário de término registrado (possíveis furtos, falhas no sensor da doca ou viagens em andamento). |

> Alerta Analítico (Inconsistência Lógica): Note que temos 43.285 viagens sem horário de término, mas temos 73.174 viagens sem duração. Isso significa que existem aproximadamente 30.000 viagens que possuem horário de início e de fim, mas a duração não foi calculada. É necessário revisar a regra ou *script* que gera a variável `ride_duration` na origem.

---

Além dos valores ausentes, o sumário estatístico nos permite identificar o perfil geral e alguns *outliers* (pontos fora da curva):

1. Perfil Demográfico: O público é predominantemente masculino. Das viagens com gênero informado, 212.608 (74%) foram realizadas por homens e 74.318 (26%) por mulheres. Dos que declararam residência, o Distrito Federal (DF) lidera esmagadoramente.

2. Anomalia em Datas: A variável `user_birthdate` possui uma data máxima de 28/04/2028. Como os dados de viagem são do ano de 2018, é impossível um usuário nascer no futuro. Além disso, a data mínima é 1928 (usuários com 90 anos à época). Em casos como este, é recomendável criar um filtro de idade válida (ex: 16 a 80 anos).

3. Comportamento de Uso: A duração média (entre os dados válidos) é de 29,9 minutos, com uma mediana de apenas 14,2 minutos. Isso indica uma distribuição assimétrica (curva puxada para a direita), onde a maioria usa para trajetos rápidos, mas alguns usuários ficam muito tempo com o veículo (o valor máximo registrado foi de incríveis 1.000 minutos - mais de 16 horas).

4. Taxa de Atraso: Nas viagens em que foi possível apurar, cerca de 9,88% (21.164 / 214.148) foram consideradas com atraso (`ride_late = TRUE`).

...

---

## Como os dados deveriam estar organizados?

Após a análise diagnóstica da estrutura dos dados, esta etapa visa corrigir, padronizar e preparar o conjunto de dados para as fases de Análise Exploratória e Modelagem Preditiva.

O propósito da limpeza é eliminar ruídos e inconsistências que comprometam a integridade analítica, sem distorcer a realidade observada.

Trata-se, portanto, de uma etapa de cirurgia analítica, não de maquiagem de dados.

A limpeza segue as quatro classes de inconsistências identificadas durante a Análise Diagnóstica anterior:

1. Integridade Referencial (Chaves “Órfãs”)
2. Validade de Dados (Valores Impossíveis)
3. *Parsing* e Completude Crítica (Ausências em Variáveis-Alvo)
4. Completude Demográfica (Ausência Sistemática em `user_residence`)

Cada uma dessas inconsistências é tratada de forma documentada, reproduzível e justificada, com decisões baseadas em evidências e na relevância para o problema de negócio.

---

É necessário que a integridade relacional entre as tabelas seja garantida, ou seja, que todas as estações referenciadas em `df_rides` existam em `df_stations`. Caso contrário, a análise de rotas e geolocalização será comprometida.

Em bancos de dados relacionais, uma viagem (tabela fato) não pode iniciar ou terminar em uma estação que não existe no cadastro oficial de estações (tabela dimensão). Quando isso ocorre, chamamos o registro de "órfão". Isso geralmente indica falhas de sincronização no sistema fonte, estações desativadas que foram removidas do cadastro, ou erros de transmissão de dados (*glitches*).

Ao realizar a auditoria de integridade, a rotina utilizou a função de conjuntos `setdiff()` para comparar todas as estações únicas da base de viagens com o cadastro oficial (`df_stations_clean`).

Foram identificadas 9 viagens vinculadas a estações fantasmas (inexistentes no cadastro).

Os 9 registros foram removidos (*filter*). Embora o volume seja estatisticamente insignificante, a remoção é estritamente necessária. Manter esses dados causaria erros graves (valores nulos ou quebra de código) no momento em que fôssemos cruzar as tabelas (*left_join*) para plotar as viagens em um mapa geográfico, por exemplo.

---

O cadastro de data de nascimento (`user_birthdate`) costuma ser um campo de preenchimento livre ou com baixa validação em aplicativos de mobilidade. Para aferir a qualidade dessa variável, calculamos a idade exata do usuário no momento da viagem (subtraindo a `ride_date` da `user_birthdate`) e aplicamos limites lógicos rigorosos:

- Idade Mínima: 8 anos (física e legalmente improvável que crianças menores utilizem o sistema sozinhas).

- Idade Máxima: 100 anos.

| **Métrica** | **Volume de Registros** | **Observação** |
| --- | --- | --- |
| Total de Viagens Analisadas | 287.313 | Base após a limpeza de órfãs. |
| Datas Faltantes (NA) | 1 | Apenas um registro sem data de nascimento. |
| Datas no Futuro | 511 | Usuários com data de nascimento posterior à viagem (ex: nascidos em 2020 e 2021). Retornam idades negativas. |
| Idade < 8 anos | 8.477 | Inclui bebês, recém-nascidos e os casos de datas futuras. |
| Idade > 100 anos | 0 | Nenhum registro de longevidade irreal detectado. |
| Total de Inconsistências | 8.477 | ~2,95% da base total de viagens. |

> Diagnóstico de Negócio (Por que isso acontece?):A inspeção manual revelou um padrão claro. Várias datas de nascimento estão registradas em anos recentes (2016, 2020, 2021) gerando idades de 1, 2 ou idades negativas (-4 anos). Isso não é um erro do ciclista, mas sim um reflexo de fricção de usabilidade (UX). Quando o aplicativo obriga o usuário a rolar um calendário para achar seu ano de nascimento, por exemplo, muitos perdem a paciência e confirmam a data que já vem pré-selecionada no sistema (geralmente o ano atual ou o ano em que o app foi instalado).

Assumindo que a idade é uma das variável preditora crítica para o modelo, e que essas datas são logicamente impossíveis, a abordagem recomendada é remover esses registros do conjunto de dados. Isso garantirá que o modelo seja treinado apenas com dados válidos e confiáveis.
Assim, todos os 8.477 registros com impossibilidade biológica foram descartados da base de análise. Essa decisão é correta assumindo que o objetivo da análise exigirá precisão no perfil demográfico. (Caso a análise fosse apenas sobre o fluxo de bicicletas, poderíamos ter mantido as viagens e apenas transformado as idades em NA).

---
Durante a etapa de diagnóstico, foi identificado que as variáveis críticas `time_end`, `ride_duration` e `ride_late` apresentavam um volume expressivo de valores ausentes e inconsistências lógicas.
Essas variáveis são centrais para qualquer análise operacional, modelagem preditiva ou avaliação de desempenho do sistema.
Tratar essas variáveis exige cautela metodológica extrema: eliminar 25% da base sem diagnóstico seria perder informação valiosa; imputar a média seria criar ficção analítica.
A primeira tarefa foi quantificar essas ausências e entender como elas se relacionam entre si.

A análise matemática revela que o problema não é único, mas se divide em dois fenômenos distintos:

1. Grupo A — Falha de Registro (42.239 viagens): `datetime_end` está ausente. Sem horário de término, não há como recuperar a duração. Tratamento recomendado: manter como NA e classificar como “viagens não finalizadas” para a análise exploratória.

2. Grupo B — Falha de Cálculo (28.940 viagens): `datetime_end` está presente, mas `ride_duration` está ausente. Isso indica que o sistema falhou ao calcular a duração, mesmo tendo os dados necessários. Tratamento recomendado: aplicar um algoritmo de resgate para tentar recuperar a duração.

O objetivo desta etapa foi desvendar o que aconteceu com essas ~29 mil viagens que tinham início e fim, mas falharam no cálculo de duração, e aplicar um algoritmo de resgate.

Ao isolar as viagens sem duração, mas com horário de fim preenchido ("Grupo B"), observou-se um padrão crítico do sistema:

- Das 28.940 viagens com esse erro, 28.884 (99,8%) apresentavam uma inversão temporal: o horário de término estava registrado como anterior ao horário de início (time_end < time_start).

 Isso é um clássico erro de *latency* (latência) ou dessincronização de relógios físicos entre a estação de retirada e a estação de devolução. O sistema central calculava a duração subtraindo o início do fim; como o resultado dava negativo, ele preenchia com NA (nulo).

Para não perder quase 30 mil viagens, aplica um algoritmo de correção em cascata, respeitando um limite operacional de 12 horas por viagem (`MAX_DURATION_MINS = 720`).

 O algoritmo testou cada viagem defeituosa nas seguintes hipóteses:

 1. Cálculo Direto: A viagem está normal? (Fim - Início).
 2. Travessia de Meia-Noite (*Overnight*): A viagem começou antes da meia-noite e terminou depois? (Adiciona-se +1 dia ao término e recalcula).
 3. Inversão Sincronizada (*Swap*): Os relógios inverteram o início e o fim? (Calcula-se Início - Fim).

Toda a operação foi realizada mantendo variáveis originais para auditoria futura. A coluna `correction_method` indica qual hipótese foi aplicada para cada viagem, e a coluna `was_corrected` indica se a viagem foi alterada ou não.

**Resultados da Aplicação (QA):**

| **Método de Resolução** | **Volume de Viagens** | **Impacto Analítico** |
|-------------------------|-----------------------|-----------------------|
| original_present        | 207.657               | Viagens normais, mantidas como estavam. |
| missing_start_or_end    | 42.239                | Sem solução. Faltam dados reais (viagens não encerradas). |
| swapped (Resgatadas)    | 28.884                | Sucesso absoluto. Viagens recuperadas revertendo a ordem dos relógios. |
| unresolved              | 56                    | Impossível corrigir dentro dos parâmetros de negócio (limite de 12h). |

> 💡 Destacando o Valor da Análise: A técnica de swap salvou cerca de 10% de toda a base de dados de ser descartada indevidamente, preservando a robustez estatística para modelos futuros.

Após a aplicação das regras, recriamos as métricas derivadas para garantir a consistência geral:

Recálculo de Atrasos (`ride_late`):

- Redefinimos a regra de negócio para: qualquer viagem com duração maior que 60 minutos é considerada atrasada. A auditoria mostrou 0 inconsistências, provando que as *flags* agora refletem perfeitamente os tempos corrigidos.

- Distribuição Estatística: A duração das viagens corrigidas faz sentido no mundo real. A viagem mais curta tem 3 minutos, a mediana ficou em 14,1 minutos, e 75% das viagens ocorrem em até 33,3 minutos.

Houve um resíduo de 56 viagens que o algoritmo rejeitou. Ao inspecionar a amostra, o motivo ficou evidente:

- Exemplo: Viagem iniciada às 00:20:19 e encerrada às 23:54:50 do mesmo dia.

- O que aconteceu: Essas viagens duraram quase 24 horas, estourando a nossa trava de segurança (`MAX_DURATION_MINS` estipulada em 12 horas).

É altamente provável que esses casos representem bicicletas que foram furtadas, abandonadas, ou retidas indevidamente por usuários, sendo recuperadas apenas no final do dia. Manter esses valores como NA para a análise de tempos médios é a decisão correta, pois eles representam anomalias operacionais extremas (*outliers*) e enviesariam a média de tempo de uso comum.

Essa intervenção devolve cerca de 30 mil observações ao conjunto modelável, fortalecendo análises exploratórias, modelagem preditiva e interpretação operacional.

![alt text](image\02-ANALISE-DIAGNOSTICA\image1.png)

---

Esta outra etapa foi focada em Engenharia de Texto (*Data Wrangling* para *Strings*) e avaliação de viés.

A variável de estado/cidade de residência (`user_residence`) é fundamental para entender o perfil do usuário (turista vs. morador local). Ela é relevante para análises territoriais, segmentação comportamental e modelos que incorporam variáveis geográficas.

No entanto, a análise preliminar revelou que essa coluna sofria de dois problemas clássicos de campos de formulário com "texto livre" (*free-text input*): altíssima taxa de não preenchimento e extrema fragmentação semântica.

Principais Descobertas:

- Volume de Ausência: Apenas cerca de 36% da base possui essa informação preenchida. O restante (177.943 viagens, ou 63,8%) estava em branco (NA).

- Ruído Estrutural: Foram detectados dados sensíveis e lixo na coluna, como e-mails (17 registros com @), números de telefone/documentos (104 registros) e símbolos diversos.

- Fragmentação: Havia 231 grafias diferentes para representar as mesmas localidades (ex: "DF", "Brasília", "Brasilia", "BRASILIA", "BRASILIA - DF").

> Teste de Viés Comportamental: Quando temos 63% de dados ausentes, a maior preocupação é o viés. Será que os usuários que não preenchem a residência se comportam de forma diferente dos que preenchem? O teste de grupos revelou que não há viés operacional relevante.
> Duração média (Sem residência): 29,7 min | (Com residência): 29,1 min.
> Taxa de atraso (Sem residência): 9,90% | (Com residência): 9,42%.

A ausência ocorre de forma aleatória (*Missing Completely at Random - MCAR*). Podemos analisar o perfil geográfico dos 37% restantes sem medo de que eles não representem o uso real do sistema.

Para recuperar a utilidade analítica dessa variável, foi construído um *pipeline* de processamento de linguagem natural (NLP básico) e regras de negócios, que podem ser resumidas em três etapas:

1. **Limpeza e Normalização (Regex):** Todos os textos foram convertidos para maiúsculas, tiveram acentos removidos, espaços duplos suprimidos e *tags* HTML eliminadas. Textos com números, @ ou preenchimentos falsos (como "X", "XXX", "NULL") foram convertidos para NA verdadeiro.

2. **Mapeamento Geográfico e de Negócio:** Foi aplicada uma regra de negócio inteligente para agrupar localidades da mesma região metropolitana:

    - Distrito Federal: Cidades satélites (Taguatinga, Ceilândia, Samambaia, Águas Claras, etc.) foram mapeadas para o macro-grupo "BRASILIA (DF)".

    - Entorno: Cidades goianas limítrofes (Valparaíso, Luziânia, Novo Gama) foram agrupadas junto a "GOIAS (GO)".

    - Demais Estados: Padronizados com Nome e Sigla (ex: "SAO PAULO (SP)").

3. **Redução de Dimensionalidade (*Lumping*):** Para evitar que o gráfico ou o modelo preditivo ficassem poluídos com centenas de estados com 1 ou 2 viagens, aplicamos um ponto de corte (*cutoff*). Estados com menos de 200 viagens foram agrupados automaticamente na categoria "OUTRA LOCALIDADE". Os dados ausentes (63%) foram rotulados explicitamente como "NAO INFORMADO".

Após o tratamento, a variável passou de 231 grafias sujas para 15 macro-categorias limpas e estruturadas.

| **Macro-Categoria** | **Volume de Viagens** | **Perfil** |
|------------------|-------------------|--------|
| **NAO INFORMADO**    | **178.126**           | Sem dados (Ausência tratada) |
| **BRASILIA (DF)**    | **87.163**            | Público Local |
| **GOIAS (GO)**       | **3.355**             | Público do Entorno / Região |
| **SAO PAULO (SP)**   | **1.950**             | Turistas / Visitantes (Sudeste) |
| **RIO DE JANEIRO (RJ)** | **1.674**          | Turistas / Visitantes (Sudeste) |
| **OUTRA LOCALIDADE** | **1.623**             | Visitantes (Demais estados unificados) |
| **MINAS GERAIS (MG)** | **1.355**            |Turistas / Visitantes (Sudeste) |
| **...** | **...**             | ... |

Essa análise revela que, apesar da falha de usabilidade no aplicativo que gerou 63% de dados não informados, o sistema é essencialmente uma ferramenta de deslocamento diário (micromobilidade), com cerca de 90% dos usuários identificados residindo no Distrito Federal e Entorno (GO). A parcela restante é composta por turistas de negócios do eixo Sudeste e visitantes de diversos estados, o que pode demandar ações operacionais distintas: garantir a oferta de bicicletas em polos de transporte para os moradores, criar passes de curto prazo para os visitantes e, em caráter corretivo imediato, substituir os campos de texto livre por menus suspensos no cadastro para estancar a perda de dados demográficos.

---

Durante as etapas de tratamento (recuperação de tempos, padronização de textos, auditorias), o dataset chegou a inchar para 27 colunas. Embora essas variáveis temporárias (`res_temp`, `duration_swap_ok`, etc.) fossem necessárias para os cálculos, mantê-las na base final causaria poluição visual, confusão conceitual e desperdício de processamento.A etapa de Projeção selecionou e filtrou a base para 15 variáveis definitivas, organizadas de forma lógica para facilitar o consumo em ferramentas de BI (Power BI, Tableau) ou bibliotecas de modelagem.

**Dicionário de Dados Consolidado (Esquema Final):**

| **Bloco Semântico** | **Variáveis** | **Propósito Analítico** |
|------------------|-----------|---------------------|
| 1. Perfil do Usuário | `user_gender, user_birthdate, user_residence, user_residence_raw` | Análises demográficas, cálculo de faixa etária e mapas de calor de origem. A residência bruta foi mantida para auditoria futura. |
| 2. Telemetria e Geografia | `ride_date, station_start, station_end, datetime_start/end, time_start/end` | Análise de fluxo (matriz Origem-Destino), sazonalidade, horários de pico e cruzamento espacial. |
| 3. Métricas de Negócio | `ride_duration, ride_late` | Variáveis-alvo (KPIs). Tempo total de uso e infrações de limite de tempo (>60 min). |
| 4. Metadados e QA | `correction_method, was_corrected` | Linhagem dos Dados: Permite rastrear se a métrica é original ou fruto do nosso algoritmo de resgate temporal. |

...

>  💡 Manter a coluna `correction_method` na base final é uma prática de excelência. Na etapa de Análise Exploratória (EDA), por exemplo, se  encontrar anomalias no tempo de viagem, poderá agrupar os dados por esse metadado e verificar se a anomalia é um comportamento real do usuário ou um artefato do método de correção (ex: viagens marcadas como *swapped*).

---

A base tratada, contendo 278.836 viagens validadas, foi salva utilizando uma estratégia dupla (arquitetura *polyglot* de arquivos), com carimbo de data (*stamp*) para versionamento automático:

1. **Formato RDS (.rds):** Formato nativo do R. Garante preservação estrita de tipagem. Fatores (*factors*), fusos horários (POSIXct) e datas (Date) não perderão seus metadados se o arquivo for reaberto em R. É altamente eficiente em compressão e leitura.

2. **Formato CSV (.csv):** Salvo em codificação UTF-8 universal. Garante interoperabilidade. Como funções baseadas em R exportam fatores como números por padrão em algumas configurações, foi aplicada a função as.character preventivamente. Este arquivo está pronto para ser consumido por Python (Pandas), Excel, ou carregado em um banco de dados SQL.

O conjunto de dados passou de um estado bruto, fragmentado e com graves erros de latência temporal, para uma tabela analítica limpa, enriquecida demograficamente e salva com governança. A base está oficialmente homologada e pronta para as próximas etapas de análise exploratória, modelagem preditiva e visualização de dados.
