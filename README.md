# bike-analytics

Projeto de análise estatística e modelagem preditiva aplicado à otimização operacional de um sistema de compartilhamento de bicicletas.

O projeto investiga o comportamento dos usuários, identifica padrões operacionais e desenvolve uma abordagem preditiva para estimar, no momento da retirada da bicicleta, a probabilidade de uma viagem ultrapassar o limite de 60 minutos.

A análise foi estruturada com foco em qualidade dos dados, rastreabilidade, reprodutibilidade e fundamentação estatística.

## Contexto

O sistema +BIKE apresenta desafios relacionados à operação e ao comportamento dos usuários. Entre os principais problemas identificados está a ocorrência de viagens superiores a 60 minutos, que podem resultar em cobranças adicionais e impactar a experiência do usuário.

A partir desse contexto, o projeto busca transformar os dados operacionais disponíveis em informações que possam apoiar decisões relacionadas à operação e à experiência dos usuários.

O trabalho foi estruturado como uma consultoria analítica simulada, considerando um problema de negócio com informações inicialmente limitadas e exigindo a definição autônoma das etapas de análise.

## Objetivos

### Objetivo geral

Desenvolver uma análise estatística e uma abordagem preditiva capazes de apoiar a compreensão e a otimização da operação do sistema +BIKE.

### Objetivos específicos

* Caracterizar o perfil dos usuários e o comportamento de utilização do sistema.
* Identificar padrões temporais, demográficos e operacionais associados às viagens.
* Avaliar a qualidade e a consistência dos dados disponíveis.
* Investigar fatores relacionados à ocorrência de viagens superiores a 60 minutos.
* Desenvolver uma abordagem preditiva para estimar a probabilidade de uma viagem ultrapassar esse limite no momento da retirada.

## Abordagem metodológica

O projeto segue uma abordagem baseada no ciclo CRISP-DM, adaptada às características do problema e com ênfase na etapa de preparação e validação dos dados antes da modelagem.

As principais etapas são:

1. Definição do problema e das restrições de negócio.
2. Estruturação e diagnóstico da base de dados.
3. Limpeza, recuperação e sanitização dos dados.
4. Análise exploratória e investigação estatística.
5. Engenharia de atributos.
6. Modelagem preditiva.
7. Avaliação dos resultados.
8. Interpretação e comunicação dos resultados.

A documentação de cada etapa está organizada em arquivos específicos no repositório.

## Engenharia e qualidade dos dados

A preparação dos dados constitui uma etapa central do projeto. O processo não se limitou à remoção de registros inválidos, mas também envolveu a investigação das causas dos problemas identificados e, quando possível, a recuperação de informação.

Entre os principais procedimentos realizados estão:

### Recuperação de registros

Foi identificado um problema de inversão temporal em parte dos registros. A investigação permitiu recuperar 29.886 observações que poderiam ser descartadas em uma abordagem convencional de limpeza.

### Validação de idade

Foram identificados registros com valores de idade incompatíveis com a realidade, incluindo datas de nascimento futuras. Aproximadamente 2,9% da base foi afetada por esse tipo de inconsistência.

### Tratamento de dados ausentes

Os dados demográficos apresentaram aproximadamente 62% de ausência em determinadas variáveis.

Em vez de eliminar esses registros, foi adotada uma estratégia de tratamento que preserva a informação disponível e explicita a ausência como uma categoria analítica quando apropriado.

O detalhamento dessas decisões está documentado em `04-LIMPEZA_DADOS.md`.

## Estrutura da documentação

A documentação do projeto acompanha o fluxo analítico e busca manter rastreabilidade entre as decisões metodológicas, os dados e os resultados.

`00-PROBLEMA.md`
Definição do problema, escopo, objetivos e restrições de negócio.

`01-ESTRUTURA.md`
Descrição da estrutura da base, dicionário de dados, *schema* e diagnóstico inicial de qualidade.

`02-PROCESSAMENTO.md`
Processo de limpeza, recuperação, validação e sanitização dos dados.

`03-EXPLORATÓRIA.md`
Análise exploratória, investigação de padrões e testes estatísticos.

`04-MODELAGEM.md`
Desenvolvimento do modelo preditivo, avaliação de performance e definição de *threshold*.

Novas etapas da análise e da modelagem serão incorporadas à documentação conforme o desenvolvimento do projeto.

## Tecnologias

O projeto utiliza principalmente:

* R
* tidyverse
* Quarto
* Markdown
* Git
* GitHub

O desenvolvimento analítico é realizado em R, utilizando o ecossistema tidyverse para manipulação e análise dos dados. A documentação é mantida em Markdown do Quarto, enquanto o versionamento é realizado com Git e GitHub.

## Reprodução do projeto

O projeto foi estruturado para permitir a reprodução do pipeline de análise a partir dos scripts e da documentação disponíveis no repositório.

### Pré-requisitos

* R
* RStudio
* Git

### Clonar o repositório

```bash
git clone https://github.com/estatisticas-do-gean/bike-analytics.git
```

### Abrir o projeto

Abra o arquivo de projeto do RStudio (`.Rproj`) disponível no repositório.

### Instalar dependências

Os scripts utilizam o pacote `pacman` para facilitar a verificação e instalação das dependências utilizadas no projeto.

### Executar a etapa de limpeza

```r
source("analise-R/01-ETL.R")
```

### Consultar a documentação

Os arquivos Markdown disponíveis na raiz do projeto apresentam as decisões e resultados de cada etapa da análise.

## Dados

Os dados utilizados no projeto não são disponibilizados neste repositório devido a questões de confidencialidade.

Consequentemente, a reprodução integral dos resultados depende do acesso à base original. O repositório disponibiliza a estrutura metodológica, os scripts e a documentação necessários para compreender e executar o pipeline sobre os dados correspondentes.

## Status do projeto

O projeto encontra-se em desenvolvimento.

As etapas de definição do problema, estruturação dos dados, planejamento metodológico e limpeza da base estão documentadas. A análise exploratória e as etapas posteriores de modelagem estão sendo desenvolvidas progressivamente.

## Autor

**Gean Gabriel**

Estatístico, Analista de Dados e Cientista de Dados.

[GitHub](https://github.com/estatisticas-do-gean)
