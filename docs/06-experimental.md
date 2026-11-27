# Experimento 0.1.0-alpha.1 — primeira fatia
Implementação inicial: uma sala persistente, câmera orbital por toque, catálogo de GLBs reais com rig e animações, seleção e loop/one-shot, pausa e diagnóstico de duração/tracks. A superfície neutra é primitiva de inspeção, não modelo artístico criado para o jogo. Sem armaduras, armas e retargeting nesta fatia; eles aguardam aquisição dos packs correspondentes.

O pipeline fixa tamanho e SHA-256 de dois arquivos Standard CC0 da Quaternius, a partir do espelho público Ludots-Assets, não da fonte primária. As páginas oficiais confirmam CC0 e as edições gratuitas; os ZIPs ainda precisam passar pela verificação do pipeline. O código mantém ZIPs originais e notices e cria derivados ignorados pelo Git. A quantidade real de clips e compatibilidade visual serão confirmadas na importação.

Limitação: ambiente de autoria sem DNS externo nem Godot instalado. Nenhum APK ou teste de dispositivo foi executado localmente. A CI é responsável pela primeira importação e exportação. Se a aquisição falhar, não publicar APK vazio. As demais coleções gratuitas permanecem pendentes. Não confundir este alfa com o marco 0.1.0 completo.

## Primeira execução CI (run 45993715871)
Aquisição e SHA-256 confirmados: os dois ZIPs Standard foram publicados em assets/source/cc0 no commit 72dda18. O pipeline extraiu 4 cenas GLB animadas e 172 instâncias de clips (variantes incluídas, não quantidade de movimentos únicos). Godot e templates foram instalados com sucesso. Build interrompido em sdkmanager ausente, antes da importação da engine. Corrigido workflow para instalar explicitamente ferramentas Android, aceitar licenças SDK e verificar códigos de saída de importação/exportação. Nova execução ainda precisa ser confirmada. Sem APK validado nesta execução.

## Baseline publicada — 27/11/2026

Run [45996718841](https://github.com/pabloerlis/MyGame/actions/runs/45996718841), código f38af05ca501240c09126342790c22287e3740d1: importação real via OpenGL por software, smoke test (SMOKE_OK: 2 packs; 172 imported clip variants), exportação Android ARM64, verificação de assinatura e publicação concluídos. APK 31.290.558 bytes (31,3 MB), SHA-256 b04f9de34a6710819f6ae8c68c3167c7b97b0fd65b1a1928e6a8d9f19a0e6698. [Download direto](https://github.com/pabloerlis/MyGame/releases/download/lab-alpha-45996718841/MyGame-Lab.apk).

Limites: smoke test em Linux valida importação e seleção de clips, não renderização visual nem execução no Android. A exportação registrou ausência de ícone próprio sem impedir o APK; corrigir usando recurso pronto licenciado quando pertinente. A CI gera chave de debug nova, portanto atualização sobre instalação anterior pode exigir desinstalação. Não há medição de FPS, RAM ou temperatura em aparelho. A aprovação do laboratório continua pendente.

### Roteiro do primeiro teste físico

- Abrir em retrato e verificar personagem, textura e iluminação.
- Trocar cenas e movimentos, verificar reprodução imediata, loop, reprodução única e pausa.
- Girar câmera com um dedo, aproximar/afastar com dois, ocultar catálogo e restaurar câmera.
- Registrar falhas de carregamento, enquadramento, contatos e desempenho.

Próximo incremento: ampliar catálogo gratuito com personagens, equipamentos e objetos de contexto compatíveis; preservar baseline e manter sala única. Nenhum mundo ou história antes da aprovação do laboratório.

## 0.1.0-alpha.2 — navegação de movimentos
Implementado: faixa inferior permanente com botões Anterior/Próxima, posição e nome do clip. Navegação circular na cena atual, seleção sincronizada com catálogo, reprodução imediata e manutenção do modo loop/único. Controle adicional de velocidade 0,25× a 2× sem alterar o clip original. Testes automatizados ampliados para verificar navegação, visibilidade com catálogo oculto, modo e velocidade nas quatro cenas. Build e validação física ainda dependem de execução confirmada. Nenhum asset novo neste incremento.


CI alpha.2 confirmada: [run 46002174709](https://github.com/pabloerlis/MyGame/actions/runs/46002174709), SMOKE_OK (2 packs, 172 variantes) e TRANSPORT_OK (4 cenas, navegação circular, sincronização, visibilidade, modo e velocidade). APK assinado de 31.294.654 bytes, [download](https://github.com/pabloerlis/MyGame/releases/download/lab-alpha-46002174709/MyGame-Lab.apk). SHA-256: 04ae7b909033a30d2424a64984ae51d0a69b68a3a920a0fc07add8aea6299270. Teste físico pendente; aviso de ausência de ícone permanece. Chave de debug não persistente pode exigir desinstalação da versão anterior.

## 0.1.0-alpha.3 — inspeção de peças
Acervo bloqueado por commit e hash Git de cada GLB: 106 modelos Ultimate RPG Pack e 24 Modular Weapons Pack (5.573.380 bytes de origem), CC0 conforme páginas oficiais. GLBs convertidos por trebeljahr/quaternius-showcase, não arquivos FBX/Blend originais. CI verifica integridade, retém GLBs no repositório e importa todos os modelos. Modo Peças na mesma sala, navegação circular pelas setas, enquadramento automático por limites sem alterar escala e restauração do ator/animação ao voltar. Inspeção isolada, não equipagem, colisão ou interação ainda. Teste físico e CI pendentes.

## 0.1.0-alpha.4 — identificação de abertura
Tela de boot nativa do Godot configurada com imagem tipográfica “P. Erlis”, fundo #111820 e letras claras. A mesma imagem serve como ícone padrão do aplicativo para evitar o ícone Godot, inclusive na abertura do sistema Android quando aplicável. Imagem de 256 × 256, tipografia DejaVu Sans rasterizada, sem distribuição da fonte. Sem espera artificial na inicialização. Mantidas as atribuições/licenças da engine e dos assets. CI e teste visual no dispositivo pendentes.

## 0.1.0-alpha.5 — encaixe experimental de equipamentos
Seleção de arma, escudo e itens de mão disponíveis, fixados por BoneAttachment3D ao osso real escolhido (mão direita reconhecida quando possível, lista de todos os ossos para alternativa explícita). Uma peça por vez; posição local ajustável por eixo em passos de 1 cm no espaço do rig, rotação em 15 graus; perfil por cena/peça/osso mantido durante a sessão; reset e remoção. Sem deformação ou mudança de escala do asset. Animações e câmera continuam operacionais. Testes CI cobrem criação, osso escolhido, ajuste, troca de animação, reaplicação e remoção nas quatro cenas. Encaixe inicial usa o pivô original, não garante contato correto, calibração visual necessária. Sem IK, armadura vestível, duas mãos simultâneas ou persistência em disco nesta fatia. CI e teste físico pendentes.

## 0.1.0-alpha.6 — dois encaixes e persistência
Dois slots independentes, mão direita e esquerda, com escolha explícita do osso e proteção contra ocupação duplicada. Permite espada + escudo ou duas armas, sem IK. Perfis por cena/peça/osso/slot, gravados automaticamente em user://grip-profiles-v1.cfg e restaurados ao equipar novamente; reset remove o perfil. A seleção de itens é de sessão, não persistida. Testes verificam dois attachments, ajuste independente, leitura do arquivo, troca de movimento e remoção de um sem perder o outro. CI e contato visual pendentes. Chave de assinatura debug ainda variável; desinstalar perde arquivo privado, exportação/backup pendente.

## 0.1.0-alpha.7 — contexto físico inicial e política de publicação
Adiciona objetos existentes (baús, minerais, cristais, livros) à sala junto ao ator, sem alterar malhas ou escala. Posicionamento X/Y/Z em passos de 5 cm, reset, troca/remoção, caixa de colisão estática aproximada baseada nos limites da malha. Não implementa ainda contato, IK, animações de interação, colisão do personagem ou escalada. Testes cobrem importação dos props, deslocamento, persistência durante troca de clipe e remoção. CI pendente. Publicação Android passa a nomear APK com versão do projeto e manter somente binário e checksum mais recentes após upload verificado; tags, notas e código permanecem. Artefatos de logs não contêm APK; rebuilds não-main são temporários. URLs históricas de binários deixam de funcionar após limpeza.

## 0.1.0-alpha.8 — inspeção temporal e distância de contato
Painel recolhível Tempo/contato: fase normalizada, tempo em segundos, pausa ao selecionar fase, avanço/retrocesso em incrementos temporais de 1/60 s (não frames nativos do clipe). Escolha de osso real e distância assinada do ponto de origem do osso à caixa aproximada do objeto (positivo fora, negativo dentro, faixa de proximidade ±2 cm). Atualização a 10 Hz quando painel visível. Não é teste de contato entre superfícies, IK nem correção automática; origem do osso pode estar longe da superfície da mão/pé. Testes de distância da caixa, pausa, seek, passo e replay. CI pendente.

## 0.1.0-alpha.9 — nomes em português
Camada labels_pt.gd separada dos recursos e chaves técnicas: nomes das 130 peças, movimentos, coleções e ossos traduzidos para pt-BR. IDs originais continuam intactos para reprodução, vínculos, perfis e arquivos. Teste valida todos os itens e compara rótulos dos clipes/ossos sem modificar IDs; lista eventuais lacunas de tradução na CI. Nomes não reconhecidos recebem rótulo numerado em português até revisão. Validação CI e física pendentes.
