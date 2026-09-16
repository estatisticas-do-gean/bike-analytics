# *Machine Learning* - Modelagem

FASE 3 nesta ordem, antes de qualquer algoritmo sofisticado:

1. Auditoria temporal do dataset
2. Definição formal da unidade de previsão
3. Matriz de elegibilidade das 29 variáveis
4. Construção de df_model
5. Definição do período treino/validação/teste
6. Verificação da prevalência em cada período
7. Baseline global
8. Baseline operacional
9. Regressão logística
10. Modelos não lineares
11. Comparação por ROC-AUC + PR-AUC + Brier/calibração
12. Avaliação Top-20%
13. Análise por subgrupos
14. Interpretação
15. Só então decisão sobre o modelo final

Para a etapa de modelagem, é importante definir claramente os objetivos do modelo, identificar as variáveis relevantes e escolher a abordagem adequada para essa construção. A modelagem pode envolver a criação de diagramas, fluxogramas ou representações matemáticas que descrevam o sistema compartilhado de bicicletas.
Além disso, é essencial validar o modelo com dados reais e ajustar conforme necessário para garantir sua precisão e utilidade.

A FASE 2 deixou de ser somente EDA.

Ela começou a criar variáveis candidatas à previsão:

idade;
faixa etária;
horário;
seno/cosseno;
dia da semana;
fim de semana;
mês;
residência;
cluster geográfico;
estação inicial;
indicadores relacionados à rede.

Isso prepara corretamente a transição para modelagem.

A pergunta correta é:

| **No momento em que o usuário retira a bicicleta, qual é a probabilidade de aquela viagem ultrapassar 60 minutos?**

Formalmente:

$$ P(Y=1\mid X_{t_0}) $$

em que:

- $Y = ride_late$ é a variável alvo, e
- $t_0 = datetime_start$ o instante em que o usuário retira a bicicleta.
- $X_{t_0}$ contém somente informações disponíveis naquele instante.

Isso é uma definição muito melhor do problema do que simplesmente treinar um classificador sobre todas as 29 variáveis disponíveis.

O conceito de tempo zero ($t_0$) deve ser o princípio central da Fase 3.



O ponto mais importante é que a EDA já produziu uma hipótese operacional forte; agora precisamos garantir que a modelagem realmente respeite essa hipótese e não introduza informação do futuro.
Nesse caso, no instante `datetime_start`, há apenas informações como:

`user_gender`
`user_age`
`user_residence`
`station_start`
`hora_inicio`
`weekday`
`month`
`is_weekend`
`is_local_df`

┌──────────────────────────────┬─────────────────────────┐
│ Critério                     │ Situação                │
├──────────────────────────────┼─────────────────────────┤
│ Tamanho da base              │ Muito bom               │
│ Variáveis constantes         │ Nenhuma                 │
│ Valores infinitos            │ Nenhum                  │
│ Duplicações                  │ 1, investigar           │
│ Missing target               │ 15,2%                   │
│ Base modelável               │ 236.540 observações     │
│ Classe positiva              │ 9,73%                   │
│ Desbalanceamento             │ Relevante               │
│ Cardinalidade categórica     │ Administrável           │
│ Outliers/extremos            │ Merecem investigação    │
│ Estrutura temporal           │ Sim                     │
│ Potencial data leakage       │ Alto                    │
└──────────────────────────────┴─────────────────────────┘

O ponto prioritário agora não é imputação nem modelagem ainda. É definir o momento da previsão e separar as variáveis que existem nesse momento daquelas que são consequência da própria viagem. Isso determinará quais das 29 colunas podem legitimamente entrar em X.


Além disso, a narrativa interpreta o grupo:

Não Informado

como comportamentalmente semelhante aos locais.

Isso é uma inferência comportamental, não uma identificação geográfica.
Portanto:

Brasília explícito     → local
Não informado          → não sabemos
Outra localidade       → não local

Essa é a representação mais defensável.

Para a variável alvo, ride_late, é importante notar que ela não é recalculada para todos os registros. Em vez disso, ela é definida como:

| original quando disponível + derivado da duração quando ausente.

Isso não invalida o projeto, mas precisa ser documentado exatamente assim.

Porque conceitualmente existem duas possibilidades:

Opção A
$$ Y = I(duration > 60) $$
Opção B
$$ Y = \begin{cases} Y_{original}, & \text{se disponível}\\ I(duration > 60), & \text{caso contrário} \end{cases} $$

Seu código implementa B.

Essa distinção importa porque ride_late é justamente a variável que será usada como resposta supervisionada.

É preciso separar duas categorias de variáveis:

- Variáveis descritivas :Servem para entender o fenômeno.

- Variáveis preditivas :Podem ser utilizadas em \(t_0\).

Essas duas coisas não são iguais.

E a EDA criou algumas variáveis excelentes para explicar o fenômeno, mas inadequadas para alimentar diretamente o modelo.

**Classificação das 29 variáveis atuais**

| Variável           | Disponível em \(t_0\)? |                   Modelar? |
| ------------------ | ---------------------: | -------------------------: |
| user_gender        |                    Sim |                        Sim |
| user_birthdate     |                    Sim | Sim, transformada em idade |
| user_residence     |                    Sim |           Sim, com cautela |
| ride_date          |                    Sim |            Não diretamente |
| station_start      |                    Sim |                        Sim |
| station_end        |                    Não |                    **Não** |
| datetime_start     |                    Sim |          Sim, transformada |
| datetime_end       |                    Não |                    **Não** |
| time_start         |                    Sim |                        Sim |
| time_end           |                    Não |                    **Não** |
| ride_duration      |                    Não |                    **Não** |
| ride_late          |                    Não |                 **Target** |
| correction_method  |                    Não |                    **Não** |
| was_corrected      |                    Não |                    **Não** |
| user_age           |                    Sim |                        Sim |
| user_age_scaled    |                    Sim |                   Opcional |
| user_age_group_exp |                    Sim |                   Opcional |
| has_residence_info |                    Sim |                        Sim |
| geo_cluster        |                    Sim |                        Sim |
| is_local_df        |                    Sim |                        Não |
| hora_inicio        |                    Sim |                        Sim |
| hora_inicio_sin    |                    Sim |                        Sim |
| hora_inicio_cos    |                    Sim |                        Sim |
| weekday            |                    Sim |                        Sim |
| is_weekend         |                    Sim |                        Sim |
| month              |                    Sim |                        Sim |
| estacao_critica    |                **Não** |                    **Não** |
| dur_mediana_ref    |  Depende da construção |     **Não na forma atual** |
| excesso_duracao    |                    Não |                    **Não** |

---

Isso é algo que eu deixaria explícito no projeto.

Produto A — conhecimento do fenômeno

Inclui:

station_end;
excesso de duração;
atraso por estação;
fluxo;
estação crítica;
duração observada;
relações pós-viagem.

Produto B — informação disponível no checkout

Inclui:

perfil;
estação de retirada;
horário;
calendário;
histórico disponível até \(t_0\).

A FASE 3 deve usar somente o Produto B.


E existe uma questão de negócio ainda mais importante: o threshold

Se a operação pretende:

alertar os 20% de viagens de maior risco

então o problema não é:

probabilidade > 0.5

O problema é:

$$ Top\ 20\% $$

dos scores.

Isso muda a avaliação.

Você deveria medir, por exemplo:

Precision@20%
Recall@20%
Lift@20%

Se 20% dos usuários/trips recebem intervenção, queremos saber:

quanto melhor é esse grupo em relação à seleção aleatória?


Precisamos distinguir "20% das viagens" de "20% dos usuários"

Essa definição é importante para o projeto.

Se a unidade de decisão é a viagem:

20% das viagens com maior risco

é uma coisa.

Se a unidade é usuário:

20% dos usuários com maior risco

é outra.

Seu dataset é essencialmente trip-level.

Portanto, salvo regra operacional diferente, eu assumiria inicialmente:

uma previsão por viagem no instante do checkout.


Você tem dados temporais de 2018.

Não faria simplesmente:

initial_split(df_rides)

aleatoriamente.

O cenário operacional é:

treinar com passado
        ↓
prever futuro

Portanto, a validação deveria respeitar o tempo.

Por exemplo, conceitualmente:

Treino       Validação      Teste
Jan–Jun      Jul            Ago

Mas eu não fixaria esses meses ainda sem primeiro verificar exatamente a cobertura temporal do arquivo final.

A regra metodológica é mais importante que os meses específicos:

$$ Train < Validation < Test $$

em termos temporais.


não começaria imediatamente pelo Random Forest.

Primeiro criaria uma tabela formal:

Feature eligibility matrix

Com colunas como:

variável	disponível t0	pós-viagem	risco leakage	ação
user_age	sim	não	baixo	manter
gender	sim	não	baixo	manter
station_start	sim	não	baixo	manter
station_end	não	sim	alto	excluir
ride_duration	não	sim	alto	excluir
excesso_duracao	não	sim	alto	excluir
estacao_critica	não/derivada	sim	alto	excluir
hora_inicio	sim	não	baixo	manter
weekday	sim	não	baixo	manter
is_weekend	sim	não	baixo	manter
month	sim	não	baixo	manter
geo_cluster	sim	não	baixo	manter
dur_mediana_ref	não historicamente	futuro incluído	alto	reconstruir ou excluir

Isso fecha a ponte entre FASE 2 e FASE 3.

Há redundâncias entre as features

Não colocaria automaticamente tudo no mesmo modelo.

Por exemplo:

Horário

Você possui:

hora_inicio
hora_inicio_sin
hora_inicio_cos

Se usar seno/cosseno, não precisa necessariamente manter os três.

Para modelos lineares:

sin + cos

é uma representação elegante da sazonalidade circular.

Para árvores:

hora_inicio

pode ser suficiente.

Calendário

Você possui:

weekday
is_weekend

Eles carregam informação parcialmente redundante.

Geografia

Você possui:

user_residence
geo_cluster
has_residence_info
is_local_df

Também há sobreposição.

Isso não significa que todos sejam "proibidos".

Significa que você precisa definir uma estratégia de representação.

. O modelo baseline deveria ser extremamente simples

Eu faria primeiro:

$$ P(Y=1)=0,0973 $$

Ou seja:

todos recebem a mesma probabilidade histórica.

Esse é o baseline de referência.

Depois:

Modelo 1

Regressão logística.

Algo conceitualmente próximo de:

$$ logit(P(Y=1)) = \beta_0 + \beta_1 Age + \beta_2 Gender + \beta_3 Station + \beta_4 Hour + \cdots $$

Esse modelo é importantíssimo porque fornece:

interpretabilidade;
odds ratios;
direção dos efeitos;
baseline estatístico.
31. Depois entram modelos não lineares

Uma sequência metodologicamente defensável seria:

Baseline
   ↓
Logística
   ↓
Árvore
   ↓
Random Forest
   ↓
Boosting

Não porque "mais complexo é melhor".

Mas para responder:

Quanto ganho preditivo obtenho ao abandonar a estrutura linear?

Essa é uma pergunta estatística muito mais interessante.

32. Não começaria com SMOTE

Como a classe positiva é aproximadamente 9,7%, existe desbalanceamento.

Mas isso não significa automaticamente:

SMOTE

Eu faria primeiro:

modelo sem reamostragem

e avaliaria.

Depois poderia testar:

downsampling;
upsampling;
SMOTE;
class weights.

Sempre dentro do treinamento, nunca antes da divisão temporal.

33. A variável missing target precisa ser tratada com cuidado

Os:

42.239

casos sem target não devem simplesmente virar:

FALSE

nem:

TRUE

Eles devem ficar fora do treinamento supervisionado.

Até aqui você fez isso implicitamente na análise da prevalência com:

mean(ride_late, na.rm = TRUE)

Isso é correto para calcular a taxa entre labels disponíveis.

Mas existe uma pergunta posterior:

Por que 15,2% das viagens não têm resultado observado?

Se a ausência de ride_late estiver associada ao tipo de viagem, estação, horário etc., pode existir selection bias.

Isso não significa que exista MNAR/MAR/Missing Completely at Random.

Só significa que a ausência do target precisa ser entendida.

não usaria diretamente:

df_rides

da EDA como dataset definitivo do modelo.

Criaria:

df_model

explicitamente.

Algo conceitual:

df_rides
   ↓
seleção de observações com target conhecido
   ↓
seleção de features elegíveis em t0
   ↓
remoção de variáveis pós-viagem
   ↓
definição de tipos
   ↓
df_model

Isso cria uma barreira explícita contra leakage.

esperaria algo como:

N total EDA
      ↓
N com target conhecido
      ↓
N treino
N validação
N teste

com:

prevalência de atraso

em cada período.

Isso permitirá verificar se a distribuição do problema muda no tempo.

Eu verificaria a prevalência:

mês × ride_late

e:

mês × N

não somente como EDA, mas como diagnóstico de estabilidade do target.

Se janeiro tem:

8%

e agosto:

14%

isso tem implicações importantes para validação e calibração.

também faria um baseline operacional muito simples

Além da média global:

P(atraso)

seria interessante ter:

P(atraso | estação de retirada)

e talvez:

P(atraso | hora)

desde que essas probabilidades sejam calculadas somente com histórico de treinamento.

Isso gera um baseline muito interpretável:

"Se eu só souber de qual estação a bicicleta saiu, quanto consigo prever?"

Depois:

"Quanto ganho adicionando perfil?"

Depois:

"Quanto ganho adicionando horário?"

Isso é uma análise incremental muito boa.

o terceiro maior risco

A validação aleatória.

Se você fizer:

initial_split(df_model, prop = .8)

teremos viagens do futuro no treinamento e viagens do passado no teste.

Para um sistema que será usado operacionalmente em novas viagens, isso não reproduz o cenário real.

A validação deve simular:

"eu estou em uma determinada data; só conheço o passado."


---

| Dimensão                       | Avaliação                                          |
| ------------------------------ | -------------------------------------------------- |
| Estrutura do projeto           | Muito boa                                          |
| Rastreabilidade                | Boa                                                |
| Limpeza dos dados              | Muito boa                                          |
| Tratamento de inconsistências  | Muito boa                                          |
| Recuperação de dados           | Muito boa                                          |
| EDA                            | Forte                                              |
| Engenharia de features         | Forte, mas ainda misturada com features pós-evento |
| Definição do target            | Adequada                                           |
| Definição temporal do problema | Adequada                                           |
| Controle de leakage            | Precisa ser formalizado                            |
| Modelagem                      | Ainda não iniciada                                 |
| Validação                      | Ainda não implementada                             |
| Avaliação operacional          | Ainda não implementada                             |
| Inferência causal              | Narrativa atualmente mais forte que a evidência    |

---

