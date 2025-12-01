### Descrição e Estrutura dos Dados

Esta análise fundamenta-se em dois conjuntos de dados principais, fornecidos como planilhas (ou tabelas), que registram a operação do sistema de compartilhamento de bicicletas +BIKE. Estes dados representam o ponto de partida para o estudo, detalhando as viagens realizadas e as estações que compõem o sistema.

A seguir, é apresentada a estrutura de cada fonte de dados, detalhando suas dimensões e as variáveis (colunas) contidas em cada uma.

### 1. Tabela de Viagens (Base `df_rides`)

Este é o conjunto de dados principal, contendo **287.322 linhas e 10 colunas**, onde cada linha representa um único empréstimo de bicicleta. As colunas disponíveis nesta tabela são:                                             

- **`user_gender`**: Gênero do usuário que realizou a viagem.
- **`user_birthdate`**: Data de nascimento do usuário.
- **`user_residence`**: Local de residência informado pelo usuário.
- **`ride_date`**: Data completa em que a viagem ocorreu.
- **`time_start`**: Horário exato de início da viagem (retirada da bicicleta).
- **`time_end`**: Horário exato de término da viagem (devolução da bicicleta).
- **`station_start`**: Estação onde a viagem começou.
- **`station_end`**: Estação onde a viagem terminou.
- **`ride_duration`**: Duração total da viagem, registrada em minutos.
- **`ride_late`**: Houve ou não atraso na devolução da bicicleta.
    
![image.png](attachment:3f3e2f1b-5f3b-4f7b-8f3a-5f3e2f1b5f3b:image.png)
    

### 2. Tabela de Estações (Base `df_stations`)

Este é um conjunto de dados complementar (ou de "lookup") que fornece informações cadastrais sobre as estações. A tabela é composta por **49 linhas e 5 colunas**, onde cada linha representa uma estação única do sistema. As colunas disponíveis são:                          

- **`station`**: Código e nome da estação (provavelmente um identificador combinado).
- **`station_number`**: Número identificador único da estação.
- **`station_name`**: Nome textual (descritivo) da estação.
- **`lat`**: Coordenada geográfica de latitude da estação.
- **`lon`**: Coordenada geográfica de longitude da estação.

![image.png](attachment:887e9873-9700-4d4f-89a4-19bbf8c821e7:image.png)

*Nota: As duas tabelas se relacionam através das colunas de estação (como `station_start` e `station_end` na Tabela de Viagens, que correspondem às estações listadas na Tabela de Estações).*
---
### Resumo da Estrutura dos Dados
| Tabela            | Linhas   | Colunas | Descrição                                      |
|-------------------|----------|---------|------------------------------------------------| 
| `df_rides`       | 287.322  | 10      | Registros detalhados de cada viagem realizada.  |
| `df_stations`    | 49       | 5       | Informações cadastrais sobre as estações do sistema.   |      
---
Estas estruturas de dados fornecem a base necessária para a análise exploratória e a modelagem preditiva subsequente, permitindo uma compreensão detalhada dos padrões de uso e comportamento dos usuários do sistema +BIKE.
