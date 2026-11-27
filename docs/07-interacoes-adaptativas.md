# ADR-002 — Contatos adaptativos: ferramentas de terceiros

Estado: fontes adquiridas e arquivadas, ainda NÃO ativadas no runtime. Engine atual: Godot 4.4.1. Manter laboratório Android, sala única, clipes e assets originais.

## Dependências fixadas
- RenIK (GDScript), MIT, https://github.com/V-Sekai/renik/tree/9d6cbc9c1ea55f4b13e42fad3b4514a4ddc3266f : scripts de membros, coluna, posicionamento e gait. Local: third_party/renik. Não importar modelos de exemplo (licenças separadas).
- AMSG PoseWarping, MIT, https://github.com/ywmaa/Advanced-Movement-System-Godot/tree/bc16f8f621d8c5465bda81bef48235fc08bde35e/addons/PoseWarping : ajuste de orientação, passada, terreno e sincronização de posição. Local: third_party/amsg. Somente módulo PoseWarping e licença; sem controlador completo, binários ou recursos visuais.
- Godot 4.4.1 já possui SkeletonIK3D, SkeletonModifier3D, BoneAttachment3D, RayCast3D e APIs de colisão. Referência: https://docs.godotengine.org/en/4.4/classes/class_skeletonik3d.html . TwoBoneIK3D só entra após migração validada para 4.6+.

## Próxima integração verificável
1. Preservar originais versionados fora de game/ para impedir importação/empacotamento prematuros. Verificar API, dependências, licença e testes de cada módulo; importar apenas scripts/cenas necessários para game/addons/.
2. Mapear ossos do rig real e anchors locais dos objetos: mão principal, mão de apoio, área útil de impacto, apoio do pé, assento e topo da plataforma. Distinguir marker autorado de estimativa. Reusar perfis e escalas existentes.
3. Resolver contato por fase do clipe: calcular transform mundial do anchor após escala; IK só na janela de contato; manter clip original fora da janela; rejeitar alvo fora do alcance, não esticar membros. Evitar dependência circular entre arma presa à mão e target dessa mesma mão.
4. RenIK: avaliar modificador de membro primeiro; preservar movimento existente; usar pé/coluna somente onde necessário. Alternativa: SkeletonIK3D nativo. AMSG: avaliar sincronização de raiz e slope/stride warping separadamente. MotionWarping.gd usa tweens de transform, não é um solver de colisão; não usar diretamente em corpo físico sem checar trajeto. PoseWarping requer nós de cena e PhysicsBody3D; não presumir plug-and-play.
5. Diagnóstico no laboratório: correção liga/desliga, distância mão/anchor e pé/superfície, fase, alcance e colisão. Exportar estado, parâmetros e observações no JSON de revisão. UI em português; IDs originais.
6. Testar espada/escudo, arma de duas mãos, mineração e escalada em pelo menos três escalas/alturas viáveis, além de alvos inalcançáveis. Medir erro de contato (meta inicial 2 cm, não resultado medido), penetração, estabilidade no loop e custo no Android. Testar reset/troca/seek. Registrar separadamente aprovação visual. Não publicar APK sem mudança funcional validada.

## Riscos
RenIK é port GDScript; compatibilidade 4.4.1 não demonstrada. AMSG é componente de template e requer adaptação. Nenhuma biblioteca identifica semanticamente qualquer objeto sem configuração. Não atualizar engine nem ativar plugins automaticamente nesta aquisição. Não copiar assets ou animações novos. Nenhum teste de execução foi realizado nesta etapa.

## alpha.13 — primeiro adaptador funcional (CI pendente)
Optado pelo SkeletonIK3D/FABRIK nativo como baseline do Godot 4.4.1, para reduzir risco de API e medir ganho antes de trocar o backend. Mão livre recebe alvo local da peça (marcador explícito ou captura de pose); opção desligada por padrão, por clipe/rig/peça, edição em cm, rejeição por alcance, erro antes/depois e exportação de perfis. A rotação da mão, dedos, colisão fina, janelas de contato e warping não estão resolvidos. RenIK e AMSG continuam arquivados, não ativados. Smoke inclui cadeia sintética; não equivale a aprovação física ou visual do Android.

## alpha.14 — RenIK selecionável (CI pendente)
Cópia do módulo de membros/helper MIT em game/addons/renik, licença incluída. Preservados originais. Backend padrão FABRIK; RenIK usa target no mundo e orientação de entrada, sem movimento de ombro nem estiramento. Guardas de eixo +Y e cadeia direta: rigs incompatíveis permanecem no FABRIK até adaptação explícita. Teste sintético mede erro e rejeita alvos impossíveis; não prova precisão em rigs reais. JSON registra backend e amostras. AMSG continua arquivado. Não trocar engine.

## alpha.15 — contato contextual por fase (CI pendente)
Reutiliza FABRIK nativo e colisores caixa existentes. Captura ponto mais próximo ou face superior em coordenadas normalizadas, por rig/objeto/clipe/osso, com janela temporal de influência suave e rejeição de alcance. Não altera clipes nem dimensões do objeto para mascarar erro. Correção opcional, um membro por vez, priorizada sobre IK de mão de apoio; não resolve contato de mão equipada, sola real, colisão fina ou deslocamento da raiz. Testes de geometria e cadeia de perna; validação de rig real/dispositivo pendente. AMSG permanece arquivado: tween de transform não é determinístico em seek e não respeita colisão por si só.
