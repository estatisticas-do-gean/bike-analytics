# Contextualização e Definição do Problema: Sistema +BIKE

## 1. Cenário Operacional
A +BIKE opera um sistema de compartilhamento de bicicletas (*bike-sharing*) em ambiente urbano, gerando um volume contínuo de dados transacionais referentes aos empréstimos realizados. Atualmente, a gestão do sistema opera com base em fluxos reativos, carecendo de uma camada de inteligência analítica que permita antecipar demandas e compreender o comportamento profundo da base de usuários.

A ausência de tratamento estatístico sobre os dados históricos (referentes ao período de janeiro a agosto de 2018) resulta em duas lacunas principais de negócio, detalhadas a seguir.

### 1.1 Lacuna Operacional e Demográfica (O Problema de Gestão)
O primeiro gargalo identificado é a **opacidade de informações** sobre o perfil e o comportamento dos usuários. A operação atual desconhece as características demográficas predominantes de sua base ativa e não possui mapeamento estatístico dos padrões de deslocamento.

Essa falta de visibilidade gera ineficiências em duas frentes:
1.  **Ineficiência Logística:** Sem o entendimento da sazonalidade e das rotas preferenciais (origem-destino), o rebalanceamento de bicicletas entre estações é subotimizado, podendo gerar indisponibilidade em horários de pico ou excesso de ativos ociosos.
2.  **Ineficiência de Marketing:** A ausência de segmentação por perfil (idade, gênero, residência) impede a criação de estratégias de aquisição direcionadas, resultando em sub-representação de determinados grupos demográficos e menor penetração de mercado.

### 1.2 O Problema da Experiência do Usuário (O Atrito dos 60 Minutos)
O segundo e mais crítico problema reside na estrutura de precificação e sua comunicação com o usuário. A política tarifária do sistema isenta de cobranças extras as viagens com duração inferior a 60 minutos. Ao ultrapassar esse limiar, o usuário incorre automaticamente em taxas adicionais.

O problema de negócio manifesta-se na **imprevisibilidade** desse evento. Atualmente, nem o sistema nem o usuário possuem ferramentas para estimar, no momento da retirada (*check-out*), a probabilidade de aquela viagem exceder o tempo de franquia. Isso resulta em cobranças "surpresa", gerando insatisfação, aumento de reclamações e potencial evasão de clientes (*churn*).

O desafio técnico, portanto, consiste em lidar com a incerteza estocástica da duração da viagem, que varia em função de múltiplos fatores (tráfego, distância, perfil do ciclista), e transformar essa incerteza em risco mensurável.

## 2. Definição do Escopo de Dados
O problema está circunscrito aos dados históricos transacionais disponibilizados pela +BIKE. O cenário de análise compreende todas as viagens registradas entre **01 de janeiro de 2018 e 31 de agosto de 2018**.

Qualquer padrão, anomalia ou tendência comportamental necessária para compreender as lacunas citadas acima deve ser inferida exclusivamente a partir deste conjunto de dados e dos metadados associados aos usuários e às estações.

## 3. Entregável Final
Ao final do ciclo de desenvolvimento, espera-se a entrega dos seguintes artefatos:

1. **Análise Exploratória:** 

    Todos os insights, gráficos e conclusões da Análise Diagnóstica, com informações  claras e conclusivas para apoiar as equipes de Operações e Marketing na formulação de estratégias eficazes.

2. **Metodologia do Modelo:**   

    Detalhamento do desenvolvimento, treinamento e validação do modelo preditivo (Predição de Atraso).

3. **Resultados do Modelo:**        

    Análise de performance (métricas de avaliação) e a definição clara do threshold (limite de probabilidade) a ser usado para identificar os 20% de usuários a serem notificados.

4. (Opcional):
 O código-fonte ou script do modelo final para implementação em nosso sistema.
 
 ---


 