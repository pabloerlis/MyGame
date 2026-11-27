# MyGame

RPG 3D de ação, sobrevivência, exploração e progressão, com identidade própria e estética low-poly de fantasia. PC como plataforma-alvo do jogo final; Android como plataforma exclusiva de testes e entregas da etapa de laboratório; experiência offline; ferramentas e assets gratuitos. O projeto inicia pelo laboratório de validação, não pelo mundo do jogo.

## Estado: 0.1.0-alpha.2 — APK publicado e CI aprovada

Implementados controles permanentes Anterior/Próxima, posição e nome do clipe, navegação circular na cena atual e velocidade de 0,25× a 2×. CI aprovada em 4 cenas, com 172 instâncias de clips; validação física pendente.

Sala única e duas bibliotecas de animação CC0 importadas: quatro cenas GLB e 172 instâncias de clipes. CI aprovada, assinatura verificada e APK Android ARM64 publicado (31,3 MB). Validação visual e execução física no Android ainda pendentes; equipamentos, roupas e catálogo ampliado permanecem no roadmap.

- [Baixar APK experimental](https://github.com/pabloerlis/MyGame/releases/download/lab-alpha-46002174709/MyGame-Lab.apk)
- [Execução CI aprovada](https://github.com/pabloerlis/MyGame/actions/runs/46002174709)
- [Estado experimental e roteiro de teste físico](docs/06-experimental.md)

## Documentação

- [Visão e escopo](docs/01-visao.md)
- [Arquitetura e decisão técnica](docs/02-arquitetura.md)
- [Aquisição e licenças](docs/03-assets.md)
- [Laboratório e critérios de aceite](docs/04-laboratorio.md)
- [Roadmap, testes e entregas](docs/05-roadmap.md)
- [Instruções para agentes](AGENTS.md)

## Regras permanentes

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
