# MyGame

RPG 3D de ação, sobrevivência, exploração e progressão, com identidade própria e estética low-poly de fantasia. PC como plataforma-alvo do jogo final; Android como plataforma exclusiva de testes e entregas da etapa de laboratório; experiência offline; ferramentas e assets gratuitos. O projeto inicia pelo laboratório de validação, não pelo mundo do jogo.

## Estado: 0.1.0-alpha.21 — galeria de demonstrações e capturas reais (CI pendente)

Botão Amostras na sala, seleção direta pesquisável entre bibliotecas, câmera próxima de equipamento, alinhamento aproximado de caixote a mãos em pose de empurrar. CI gera imagens PNG reais e manifesto das poses, sem declarar aprovação visual. Alpha.20 aprovada e publicada.

Catálogo de 143 modelos (13 novos, incluindo nove modelos de armas de fogo e quatro objetos). Modo demonstração por padrão, encaixe automático por clipe, amostras de pistola, espada, arco, escudo, machado/árvore, cadeira, baú e caixote. Configuração inicial não equivale a aprovação visual; recarga e abertura do baú não animam o objeto nesta versão.

Correção opcional da projeção do tronco sobre a faixa entre dois apoios superiores registrados, com limite, guarda de alcance e colisão aproximada. Alpha.17 e alpha.18 aprovadas no CI; alpha.18 publicada.

Giro horizontal opcional ajustado por dois ou mais contatos, limite angular, guarda aproximada do arco de movimento e diagnóstico por JSON. Recalcula a translação após o giro. Mantém a animação original e o reset determinístico.

Até quatro cadeias independentes de mãos/pés, janelas por contato, indicadores e erros individuais, compromisso de translação ponderado. Alpha.16 aprovada no CI e publicada.

Camada de translação por fase antes do IK, limite e eixos configuráveis, proteção aproximada de pontos do tronco contra colisor expandido, perfis exportáveis. Alpha.14 e alpha.15 aprovadas no CI; alpha.15 publicada.

Captura de superfície aproximada para mão/pé livre, anchor normalizado que acompanha a escala do objeto, janela temporal com transição suave, prioridade sobre IK de apoio e perfis persistentes exportáveis. Não é ainda contato com a malha exata nem motion warping de raiz.

RenIK experimental integrado como alternativa ao FABRIK nativo. Troca de backend, proteção para rigs não alinhados a +Y e métricas por backend; sem alegação de superioridade. Alpha.13 aprovada no CI e publicada.

Primeiro adaptador de contato: ponto de apoio local por equipamento/rig/movimento, captura e ajuste em cm, correção opcional via FABRIK nativo, rejeição de alvo inalcançável e diagnóstico JSON. Originais RenIK e AMSG preservados em `third_party/`; somente o módulo de membros do RenIK é integrado nesta etapa, AMSG ainda não está ativo.

Novo modo de inspeção de 130 peças CC0 (106 RPG e 24 armas), com navegação circular e enquadramento automático. O APK mais recente aprovado está na página de Releases.

Implementados controles permanentes Anterior/Próxima, posição e nome do clipe, navegação circular na cena atual e velocidade de 0,25× a 2×. CI aprovada em 4 cenas, com 172 instâncias de clips; validação física pendente.

Sala única e duas bibliotecas de animação CC0 importadas: quatro cenas GLB e 172 instâncias de clipes. CI aprovada, assinatura verificada e APK Android ARM64 publicado (35 MB). Validação visual e execução física no Android ainda pendentes; equipamentos, roupas e catálogo ampliado permanecem no roadmap.

- [Baixar APK experimental](https://github.com/pabloerlis/MyGame/releases)
- [Execução CI aprovada](https://github.com/pabloerlis/MyGame/actions)
- [Estado experimental e roteiro de teste físico](docs/06-experimental.md)

## Documentação

- [Visão e escopo](docs/01-visao.md)
- [Arquitetura e decisão técnica](docs/02-arquitetura.md)
- [Aquisição e licenças](docs/03-assets.md)
- [Laboratório e critérios de aceite](docs/04-laboratorio.md)
- [Roadmap, testes e entregas](docs/05-roadmap.md)
- [Instruções para agentes](AGENTS.md)

## Regras permanentes

- Manter apenas o APK mais recente validado nas Releases; nome `MyGame-Lab-<versão>.apk`. Preservar tags e histórico de código; apagar binários antigos somente depois de publicar e verificar o novo. Links antigos de APK podem deixar de funcionar.

- Laboratório e testes do usuário exclusivamente no Android, em orientação vertical, por conveniência durante o dia. O jogo final tem PC como plataforma-alvo.
- Preservar portabilidade desde o início: núcleo, assets, regras, física e animações compartilhados; separar entrada, UI, armazenamento e perfis gráficos por plataforma. Não compilar nem testar versão PC nesta etapa.
- **Reaproveitamento máximo (asset-first):** usar todos os recursos prontos gratuitos, relevantes, compatíveis e legalmente utilizáveis. Não modelar, rigar, texturizar ou animar do zero o que já existe em condições adequadas. Pesquisar alternativas antes de declarar uma lacuna; criação original de recurso visual/animado somente como exceção documentada e autorizada pelo responsável.
- **Sala única de testes:** todo o laboratório acontece em uma única cena 3D compacta, reconfigurável dinamicamente; trocar assets, ações e contextos sem navegar entre salas ou mapas. Carregar somente os elementos necessários ao teste atual.
- Priorizar visualização 3D, menus contextuais e execução imediata da ação selecionada.
- Incorporar ao repositório público todos os assets gratuitos relevantes legalmente redistribuíveis. Preservar licenças e origem; não publicar material de licença incerta ou restrita.
- Separar biblioteca de origem, derivados de runtime e catálogo; carregar sob demanda.
- Corrigir contatos físicos, encaixes e alinhamento com objetos de verdade; preservar animações originais.
- Registrar avaliações por combinação de personagem, animação, equipamento e contexto, exportáveis em JSON.
- Não confundir execução automatizada com aprovação visual.
- Não começar mapa, história, missões ou campanha antes da aprovação explícita do laboratório.
- Não publicar APK sem mudança concreta testável. Reportar testes efetivamente realizados.

## Fonte de assets

[Quaternius](https://quaternius.com/) — usar somente edições gratuitas obtidas legalmente; verificar licença de cada arquivo baixado. A licença de código próprio ainda não foi escolhida pelo responsável; licenças dos terceiros permanecem independentes.
