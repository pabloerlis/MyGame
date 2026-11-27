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
