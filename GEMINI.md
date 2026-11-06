# Diretrizes do Projeto — Monitoramento Ambiental (Muda & PSA)

## Fluxo de Trabalho em Fases
- Dividir entregas complexas em fases incrementais (Fase 1, Fase 2, Fase 3, Fase 4), implementando e validando uma fase por vez antes de avançar para a seguinte.
- Sempre executar `flutter analyze` e `flutter test` ao concluir cada fase.

## Arquitetura e Homologação Acadêmica
- Manter o aplicativo 100% autônomo em SQLite (`sqflite`) + API REST/JWT simulada localmente, garantindo que o APK funcione em qualquer dispositivo/emulador de avaliação sem exigir chaves de API pagas ou configuração externa.
- Preservar a Barra de Modo Demonstração (Online/Offline, Falha de Rede AM-12 e Conflito de Sincronização AM-04) integrada a todos os fluxos de coleta e sincronização.
- Respeitar rigorosamente o controle de sigilo por perfil (AM-01): dados confidenciais (CPF, CAR, repasses financeiros PSA e laudos restritos) nunca devem ser exibidos em texto aberto para o perfil `Empresa Contratante`.
