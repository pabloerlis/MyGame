# Roadmap e qualidade

| Marco | Entrega verificável | Gate |
|---|---|---|
| 0.0.1 | Documentação, decisão preliminar, fontes | Revisar objetivos |
| 0.0.2 | Aquisição CC0, manifestos, hashes e relatórios de rig/escala | Licenças e integridade |
| 0.1.0 | APK laboratório mínimo: personagem real, câmera, animação, arma e prop | Instalação e teste visual |
| 0.2.0 | Catálogo completo gratuito, busca, roupas e armas, reprodução avançada | Compatibilidade documentada |
| 0.3.0 | Contextos de contato, correções, revisão JSON persistente | Aprovação por ação/contexto |
| 0.4.0 | Integração de combate, interação e múltiplos atores | Estabilidade e desempenho |
| 1.0 laboratório | Capacidades necessárias validadas e pendências aceitas | Aprovação explícita do usuário |
| Transição PC | Exportar o mesmo núcleo, adaptar entrada/UI e perfis gráficos, verificar paridade | Só após gate do laboratório; testes próprios no PC |
| Jogo | Protótipo jogável para PC, mundo, progressão e demais sistemas | Após aprovação do laboratório e transição de plataforma |

## CI prevista
Durante toda a etapa de laboratório, somente APK Android como artefato executável entregue ao usuário. Testes headless do núcleo podem rodar no CI; não gerar builds PC nesta etapa. A exportação desktop e validação de paridade serão marcos futuros, sem duplicar o projeto.

GitHub Actions com versão fixa do Godot e templates, JDK 17, Android SDK compatível e arm64-v8a. Rodar validação JSON e referências, licenças, hashes, importação headless, testes unitários de catálogo/action/equipamento/review e testes de cenas; exportar APK debug; verificar assinatura e hash; publicar artefato e notas. Cache de dependências dentro dos limites gratuitos. Não publicar chaves de assinatura. Definir assinatura persistente antes de releases que precisem atualização sobre instalação existente.

## Testes
Separar unitário, integração, smoke em emulador e visual/performance em aparelho físico. Testes mínimos: catálogo sem IDs duplicados; referências resolvidas; clip com duração/tracks válidos; sockets existentes; importação e exportação de review preservam dados; troca repetida sem vazamento aparente; cena não apresenta erro fatal. Logs e métricas com versão/commit e ambiente. Revisão em aparelho físico pelo usuário; nenhuma aprovação visual automatizada presumida.

## Backlog imediato
- Inventariar todo o catálogo Quaternius relevante e validar licença efetiva; adquirir os recursos redistribuíveis, incluindo os não usados no APK inicial.
- Construir matriz de cobertura de modelos, peças, rigs, animações, efeitos e objetos; pesquisar fontes gratuitas complementares para lacunas. Reportar cobertura real e não criar arte/animações originais sem aprovação explícita.
- Montar pipeline determinístico e validar clone limpo.
- Fixar versão estável da engine e configuração Android.
- Implementar fatia vertical de laboratório com assets reais.
- Gerar APK e relatório de testes; publicar somente quando houver diferença observável.

Riscos: disponibilidade/licença de assets, incompatibilidade de rig, tamanho e quota GitHub, retargeting e contatos, fragmentação Android. Mitigação: catálogo CC0, perfis de rig, deduplicação, spike nativo, medição em dispositivo e gates. Nenhuma implementação ou benchmark ainda concluído.
