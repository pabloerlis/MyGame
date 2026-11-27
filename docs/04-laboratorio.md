# Laboratório Android — especificação e aceite

## Experiência
O Android em retrato é a plataforma exclusiva de avaliação nesta etapa, não a plataforma final do jogo. A cena, catálogo, reprodução, física e revisão não devem depender de toque ou orientação; UI e gestos do laboratório são adaptadores. Não produzir APK e build PC em paralelo.

Retrato, espaço mínimo por ação, personagem com rosto original, fundo neutro, iluminação simples. Cena 3D ocupa a área principal. Menu recolhível de categorias: personagens, movimentos, equipamentos, objetos, interações e revisão. Busca e seleção imediata; botões permanentes Anterior/Próxima, com índice/nome sincronizados e navegação circular no personagem atual, mesmo com catálogo recolhido;  modo loop ou único; no único mostrar botão Play. Controles avançados contextuais: pausa, velocidade, timeline, frame a frame, root motion, esqueleto/colisões. Câmera orbitável 360°, inclinação, pinça/zoom, reset, enquadramento frontal/lateral/traseiro, isométrico e terceira pessoa. Não sobrepor controles à cena; evitar rolagem desnecessária.

## Sala única de testes (escopo obrigatório)
- Uma única sala física/visual, compacta, com piso neutro, iluminação adequada e limites simples compostos de assets existentes. Sem mapas, corredores, salas temáticas ou decoração dispensável.
- Ao abrir o APK, entrar diretamente na sala. A mesma câmera e interface permanecem disponíveis em todos os modos. Menus recolhíveis permitem escolher categoria, asset, ação e equipamento; seleção aplica imediatamente, sem navegar para outra sala.
- Modos na mesma cena: inspeção isolada de qualquer peça; montagem de personagem/equipamentos; reprodução de clipe; interação contextual; combinação de peças estruturais; testes com mais de um ator quando necessário. Objetos entram e saem da área conforme a seleção.
- Exemplo: selecionar mineração adiciona rocha e picareta; selecionar escalada substitui o contexto por plataforma; selecionar combate instancia alvo; selecionar uma peça permite observar geometria e materiais isoladamente. Tudo no mesmo espaço, sem reconstruir animações ou modelos existentes.
- Reset deve restaurar posição, orientação, animação e estado físico dos elementos; permitir preservar câmera e escolhas compatíveis. Dimensionar área útil conforme ação, com deslocamento real quando necessário. Não fixar metragem antes de testar os assets.
- Aceite: trocar de categoria e contexto sem carregar outra sala, sem sobras de props ou colisões, sem perder controles essenciais, sem crescimento contínuo de recursos ativos. Avaliações referenciam contexto e assets, não mapas distintos.

## Matriz de capacidades
| Área | Exemplos | Aceite |
|---|---|---|
| Personagem | Corpo, rosto, cabelo, criatura | Sem deformação, textura ausente ou escala incoerente |
| Locomoção | Idle, caminhar, correr, oito direções, agachar, rastejar, salto, queda, rolar | Pés/solo coerentes, direção e deslocamento corretos |
| Equipamento | Armas, escudos, capacete, armadura, botas, acessórios | Encaixe em mãos/costas/cintura; sem sobreposição relevante |
| Combate | Ataque, combo, bloqueio, esquiva, impacto, morte | Arma acompanha empunhadura; contato/fase e colisão coerentes |
| Interação | Escalar, transpor, abrir, colher, minerar, cortar, pescar, sentar, carregar | Objeto real no contexto; mãos/pés alcançam o alvo; não flutuar/atravessar |
| Estruturas | Paredes, pisos, portas, móveis, ruínas, vegetação | Escala, pivôs, encaixe modular e colisão inspecionáveis |
| Reprodução | Loop, one-shot, replay, busca, pausa, tempo | Sem replay indesejado, UI consistente, troca imediata |
| Câmera | Todos os ângulos e zoom | Gestos responsivos, sem clipping impeditivo |

A lista é alvo, não afirma disponibilidade de clips gratuitos. O laboratório deve expor todos os modelos, variantes, objetos, peças e clips gratuitos pertinentes efetivamente adquiridos e compatíveis, por etapas de importação, e não apenas uma seleção de exemplos. Identificar fonte e clip original; permitir avaliar combinações entre recursos. Para ações ausentes, pesquisar acervo e fontes externas gratuitas antes de registrar lacuna; manter indisponível com motivo até solução. Não criar animações ou modelos substitutos do zero sem aprovação explícita. Ajustes físicos e de integração não equivalem a criação de animação do zero. Testar contexto com plataforma/objeto do tamanho correto; não deformar objeto arbitrariamente para mascarar erro. Usar anchors, IK, ajustes de root motion e perfis de contato quando necessário.

## Revisão
Estados: não avaliado, aprovado, necessita ajuste, reprovado. Persistência no armazenamento privado do app e exportação/importação via seletor de arquivos Android, sem acesso indiscriminado ao armazenamento. Identificador composto por personagem, rig, clip, ação, equipamento e contexto. Importação não destrutiva; versão de schema e data; preservar histórico em atualizações; revalidar quando asset/correção mudar.

Exemplo de registro:
```json
{"schemaVersion":1,"build":"0.1.0","actorId":"actor.example","actionId":"climb","clipId":"clip.example","equipmentIds":[],"contextId":"ledge.example","phase":0.52,"camera":{"yaw":0.85,"pitch":0.3,"zoom":0.65},"verdict":"needs-adjustment","notes":"Pé não toca a plataforma.","reviewedAt":"2026-11-27T00:00:00Z"}
```
IDs e valores são ilustrativos, não resultados reais.

## Diagnóstico
FPS, frame time, draw calls, triângulos, tempo de carga, contagem de assets e memória quando mensurável. Objetivo inicial 60 FPS (16,7 ms/quadro), modo reduzido a 30 FPS. Medir p50/p95, consumo, aquecimento e estabilidade; não declarar resultado sem aparelho. Testar offline, instalação, troca de assets, pausa/retorno e exportação de revisão.

## Gate
Aprovação visual explícita do usuário das capacidades e combinações necessárias à primeira fase jogável; zero defeitos bloqueantes, sem lacunas ocultas. CI e testes de lógica não aprovam aparência. Lacunas devem ser corrigidas ou retiradas do escopo mediante aceite explícito.

## Revisão de ergonomia — alpha.10
Página de configuração em tela cheia, sem recarregar a sala, dividida em Cena, Movimentos, Equipamentos, Objetos e Tempo. Cabeçalho e categorias fixos; corpo com rolagem somente quando necessário. Seletores extensos em página de busca separada com linhas de toque de 72 unidades na viewport de referência 540 × 960; pesquisa sem distinção de acentos. Controles básicos Anterior/Próxima e câmera permanecem na visualização 3D. Configuração aplicada imediatamente; Voltar à sala não altera escolhas. Validação física em Android pendente.
