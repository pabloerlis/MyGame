# Arquitetura — ADR-001 (proposta inicial)

## Decisão
Godot 4.x estável + GDScript tipado, exportação Android ARM64, glTF/GLB preferencial; começar com renderer Compatibility (OpenGL ES 3), comparar Mobile/Vulkan em hardware real. Fixar versão exata do editor, templates, SDK e JDK 17 no primeiro spike. Não introduzir plugins pagos. Blender somente para conversão/inspeção reproduzível quando necessário.

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

## Pipeline
Originais imutáveis → inventário/licença → validação de malhas, materiais, rig e escala → normalização em metros → perfil de retargeting por família → derivados GLB/recursos Godot → catálogo → carregamento sob demanda. Usar Skeleton3D, BoneAttachment3D e AnimationPlayer/AnimationTree quando adequado. Aplicar correções por perfil, não sobrescrever clips. Não misturar root motion com deslocamento duplicado de CharacterBody3D. Testar colisões em runtime, não inferir qualidade só por importação.

## Performance e portabilidade
Cache limitado e descarregamento, materiais compartilhados, texturas comprimidas após comparação visual; não duplicar formatos no APK. APK inicial contém amostra representativa; expansão offline por pacotes legalmente distribuíveis caso necessário. Tamanho máximo ainda não definido: medir primeiro. CI headless importa e testa lógica, mas não substitui GPU/dispositivo real.

Fontes: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html ; https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html ; https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html ; https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
