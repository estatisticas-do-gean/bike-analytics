# 📊 Pipeline de Análise Exploratória – Sistema +BIKE

A etapa de Análise Exploratória de Dados (Exploratory Data Analysis - EDA) será responsável por desvendar padrões, tendências e relações dentro do conjunto de dados do sistema +BIKE. Ao longo desta fase, serão utilizadas técnicas estatísticas descritivas e visualizações gráficas para compreender melhor o comportamento dos usuários, a dinâmica das estações e os fatores que influenciam as viagens. Aqui são formadas as hipóteses que guiarão a modelagem preditiva subsequente. Além disso, a EDA nos permitirá identificar quaisquer anomalias ou peculiaridades nos dados que possam impactar a análise futura.
> EDA → ponte para predição


### Objetivos

Com os dados limpos e preparados, o objetivo principal desta fase é explorar e interpretar os dados para extrair insights valiosos que possam informar decisões de negócio e estratégias operacionais do sistema +BIKE. 

Os objetivos específicos incluem:
- Compreender a distribuição das variáveis principais, como duração das viagens, frequência de uso, e padrões sazonais.
- Identificar correlações entre diferentes variáveis, como tipo de usuário, horário do dia, e localização das estações.
- Detectar outliers e anomalias que possam indicar problemas operacionais ou oportunidades de melhoria. 
- Visualizar tendências temporais e geográficas para entender melhor o comportamento dos usuários ao longo do tempo e em diferentes regiões.

### Metodologia
A metodologia adotada para a Análise Exploratória de Dados envolverá as seguintes etapas:

1. **Análise Univariada**: Examinar cada variável individualmente para entender sua distribuição, medidas de tendência central (média, mediana) e dispersão (desvio padrão, variância).
2. **Análise Bivariada**: Investigar relações entre pares de variáveis utilizando gráficos de dispersão, tabelas de contingência e cálculos de correlação.
3. **Visualização de Dados**: Utilizar gráficos como histogramas, boxplots, heatmaps e séries temporais para representar visualmente os dados e facilitar a identificação de padrões.
4. **Identificação de Outliers**: Aplicar métodos estatísticos e visuais para detectar valores atípicos que possam influenciar a análise.
5. **Análise Temporal e Geoespacial**: Explorar padrões ao longo do tempo e em diferentes localizações geográficas para entender melhor o comportamento dos usuários.

Ao final desta etapa, espera-se ter uma compreensão profunda dos dados do sistema +BIKE, permitindo a formulação de hipóteses informadas para a modelagem preditiva e outras análises avançadas.

---

O problema de negócio inicial do sistema +BIKE é identificar qual é o perfil dos seus usuários e como eles utilizam o serviço de bicicletas compartilhadas. 




Cerca de 15% das viagens apresentam falha no registro do horário de encerramento, apesar da devolução da bicicleta ter sido registrada corretamente. Isso indica limitações operacionais do sistema de captura de eventos, especialmente críticas para métricas de tempo, atraso e cobrança.


O Que Aconteceu? (A Teoria) Essas são viagens onde o sistema registrou a saída e a chegada (sabemos a rota), mas houve falha na sincronização do timestamp de chegada. Pode ser "Force Docking": O usuário entregou a bike, a estação não travou direito, e um técnico ou o sistema validou a entrega posteriormente, mas sem conseguir recuperar o segundo exato da entrega.
...



Agora podemos escrever a regra de ouro para a criação do df_eda.

Decisão Analítica:

Os dados com ausência de tempo (datetime_end NA) são Espacialmente Válidos, mas Temporalmente Inválidos.

Como proceder no código:

Para Análise de Rota/Fluxo (Origem -> Destino): Podemos usar essas 42 mil linhas! Elas mostram que alguém foi da Rodoviária para o Instituto de Artes. Se as removermos, subestimamos a carga dessas estações.

Para Análise de Comportamento (Duração/Atraso): Devemos removê-las obrigatoriamente.

Próximo Passo: Criar o Dataset Oficial da EDA
Agora que você entendeu o dado, vamos rodar o código de criação do df_eda com a consciência limpa.




