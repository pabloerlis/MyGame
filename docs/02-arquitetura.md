# Arquitetura — ADR-001 (proposta inicial)

## Decisão
Godot 4.x estável + GDScript tipado, núcleo portátil para PC (plataforma final) e exportação Android ARM64 exclusiva na etapa inicial, glTF/GLB preferencial; começar com renderer Compatibility (OpenGL ES 3), comparar Mobile/Vulkan em hardware real. Fixar versão exata do editor, templates, SDK e JDK 17 no primeiro spike. Não introduzir plugins pagos. Blender somente para conversão/inspeção reproduzível quando necessário.

| Alternativa | Vantagem | Custo/risco |
|---|---|---|
| Godot 4 | Engine nativa, editor, física, animação, importação, export APK e CLI | Templates e runtime; retargeting precisa de validação |
| Three.js + Capacitor | TypeScript, tooling web, inspeção rápida | Física, IK, editor e pipeline de jogos exigem integração adicional; WebView a medir |
| Babylon.js + Capacitor | Recursos 3D e animação no ecossistema web | Mesmos riscos de empacotamento e integração; avaliar wrapper e performance |

Decisão qualitativa, sem benchmarks: Godot oferece melhor ponto de partida para reaproveitar laboratório no jogo. Confirmar com APK mínimo, rig humanoide, equipamento, colisão, animação e perfil de desempenho. Se falhar, registrar novo ADR antes de migrar.

## Camadas e diretórios propostos
- assets/source/cc0/: originais e licenças (somente redistribuíveis).
- assets/catalog/: manifestos JSON e relatórios de compatibilidade.
- tools/: aquisição, hash, validação, conversão determinística.
- game/: projeto Godot; assets/runtime/, core/, actors/, actions/, equipment/, interactions/, physics/, lab/, ui/, tests/.
- docs/: requisitos, decisões, documentação técnica; .github/workflows/: CI Android.
- Recursos restritos: cache local ignorado pelo Git; não guardar derivados redistribuíveis indevidamente.

## Contratos
AssetRecord: id estável, pack/version, hash SHA-256, licença, origem, caminho, tipo, rig_id, escala, variantes e status.
ActorDefinition: rig_id, cena, sockets, dimensões de colisão, equipamentos compatíveis.
ActionDefinition: id semântico, clip_id, rig_id, duração, loop, root_motion, requisitos de equipamento/contexto, fases de contato e correções por rig.
InteractionContext: anchors, dimensões, colisões e affordances (ex.: superfície escalável).
ReviewRecord: schema_version, build, ids, configuração, fase normalizada, status, notas.
Separar ActionPlayer (playback), ActionExecutor (movimento/estado), ContactSolver (alinhamento/IK), EquipmentService (sockets/compatibilidade) e Catalog (resolução de dados). UI não implementa física ou regras. Dados dirigem comportamento; scripts específicos só quando necessários.

## Sala única — composição dinâmica
- Uma cena principal LabRoom persistente com piso/limites modulares prontos, iluminação neutra, câmera orbital e interface sobreposta. Não criar cenas de sala separadas para cada ação; subcenas de assets/contextos são reutilizáveis, instanciadas dentro da sala.
- LabSession mantém seleção, modo, configuração de câmera e revisão. LabContextManager instancia atores, equipamentos, props e módulos de interação sob demanda em pontos de referência; limpa o contexto anterior, libera recursos e restaura estado físico inicial. Permitir reset manual e repetição determinística do teste.
- Contextos definem espaço útil, anchors, colisões e dependências (ex.: plataforma de escalada, alvo de combate, peças modulares). A sala pode ajustar área útil ou usar movimento no lugar para locomoção; testes de deslocamento real devem respeitar espaço e colisões.
- Modos de catálogo, montagem, animação e interação são estados da mesma sala. Inspeção isolada ou combinação simultânea conforme necessidade; não carregar acervo inteiro na memória. O núcleo do jogo não depende de LabRoom.

## Integração antes de produção artística
- Usar rigs, malhas, materiais e clips existentes como fonte de verdade. Reutilizar importadores, bibliotecas, addons e recursos nativos gratuitos adequados antes de implementar equivalentes; verificar licença, dependências e portabilidade.
- Adaptadores por família de rig, bone maps, sockets e perfis de retargeting devem maximizar a cobertura de animações e equipamentos sem remodelar personagens. Compor e mesclar clips existentes; correções de contato e transição via IK/anchors/configuração. Não sintetizar movimentos do zero se houver clipe pronto adequado.
- Separar disponibilidade do recurso, compatibilidade técnica e aprovação visual. Toda lacuna precisa de busca registrada e alternativas consideradas; produção artística original depende de aprovação do responsável.

## Pipeline
Originais imutáveis → inventário/licença → validação de malhas, materiais, rig e escala → normalização em metros → perfil de retargeting por família → derivados GLB/recursos Godot → catálogo → carregamento sob demanda. Usar Skeleton3D, BoneAttachment3D e AnimationPlayer/AnimationTree quando adequado. Aplicar correções por perfil, não sobrescrever clips. Não misturar root motion com deslocamento duplicado de CharacterBody3D. Testar colisões em runtime, não inferir qualidade só por importação.

## Portabilidade Android → PC (requisito obrigatório)
- Um projeto Godot, um núcleo e uma fonte de verdade para cenas, assets, rigs, regras, colisões e dados. Não bifurcar a implementação por plataforma.
- Comandos semânticos (selecionar ação, mover, mirar, interagir, equipar, orbitar, zoom) independentes de touchscreen, teclado, mouse ou gamepad. InputMap e adaptadores traduzem dispositivos para comandos; ações não leem eventos físicos diretamente.
- Laboratório em retrato com UI de toque; cenas 3D e serviços não dependem de layout, orientação, resolução ou DPI. Preparar separação de UI desktop futura sem implementar essa UI agora.
- Simulação em passo fixo de física; animação por tempo, não por quantidade de frames; unidades em metros e coordenadas de mundo independentes de pixels.
- Persistência via user://, caminhos relativos res:// e adaptadores para seletor/exportação de arquivos. JSON versionado e IDs estáveis preservados entre plataformas. Nenhum caminho absoluto, JNI ou plugin Android no núcleo.
- Assets glTF/GLB compartilhados, materiais portáveis; qualidade de sombras, texturas, LOD, resolução e limites por perfil. Compatibility inicial não determina renderer final do PC; eventual Forward+ exige validação própria.
- Dependências nativas somente se indispensáveis e com alternativa desktop. Preferir APIs multiplataforma da engine. CI Android e testes headless do núcleo nesta fase; sem build Windows/Linux/macOS até etapa posterior. Testar no Android não comprova desempenho nem compatibilidade gráfica no PC.
- Gate de portabilidade futuro: exportar a mesma base para PC, mapear teclado/mouse e eventualmente gamepad, ajustar UI desktop e perfis gráficos, validar paridade de comportamento e medir desempenho sem reescrever sistemas centrais. Sistema operacional e requisitos de hardware do PC ainda não definidos.

## Performance e portabilidade
Cache limitado e descarregamento, materiais compartilhados, texturas comprimidas após comparação visual; não duplicar formatos no APK. APK inicial contém amostra representativa; expansão offline por pacotes legalmente distribuíveis caso necessário. Tamanho máximo ainda não definido: medir primeiro. CI headless importa e testa lógica, mas não substitui GPU/dispositivo real.

Fontes: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html ; https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html ; https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html ; https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
