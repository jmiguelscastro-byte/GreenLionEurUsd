# Copilot Instructions

Este projeto é um Expert Advisor em MQL5 para MetaTrader 5.

## Par alvo

- O **TITAN LION** deste repositório é focado no par **EURUSD**.

## Regras gerais

- Escrever código limpo, seguro e bem comentado.
- Não criar lógica demasiado complexa sem necessidade.
- Priorizar estabilidade, controlo de risco e facilidade de backtest.
- Todos os parâmetros importantes devem ser configuráveis por input.
- O código deve compilar em MetaEditor sem erros.
- Evitar funções obsoletas ou incompatíveis com MQL5.
- Usar CTrade para execução de ordens.
- Usar Magic Number para identificar operações do EA.
- Nunca abrir trades sem stop loss.
- Nunca abrir trades sem validação de spread.
- Evitar múltiplas entradas no mesmo candle.

## Estrutura recomendada

O EA deve conter:

- Inputs organizados por secções:
  - GEN_
  - RISK_
  - ENTRY_
  - EXIT_
  - FILTER_
  - UI_
- Função OnInit
- Função OnDeinit
- Função OnTick
- Funções auxiliares:
  - CheckNewBar
  - GetSpreadPoints
  - CalculateLotSize
  - CheckBuySignal
  - CheckSellSignal
  - OpenBuy
  - OpenSell
  - ManageOpenPositions
  - ApplyTrailingStop
  - WriteLog

## Estratégia inicial

Usar:
- EMA rápida
- EMA lenta
- RSI
- ATR
- Spread filter

Buy:
- EMA rápida acima da EMA lenta
- RSI acima de 50 mas abaixo de sobrecompra
- Preço acima das EMAs
- Spread dentro do limite

Sell:
- EMA rápida abaixo da EMA lenta
- RSI abaixo de 50 mas acima de sobrevenda
- Preço abaixo das EMAs
- Spread dentro do limite

## Gestão de risco

- Permitir lote fixo.
- Permitir lote automático baseado em percentagem de risco.
- Calcular SL com ATR.
- Calcular TP com multiplicador Risk Reward.
- Aplicar trailing stop opcional.
- Aplicar break even opcional.

## Qualidade obrigatória

Antes de terminar qualquer tarefa:
- Verificar se o código compila.
- Garantir que não há variáveis não usadas.
- Garantir que não há chamadas inválidas de indicadores.
- Garantir que handles de indicadores são libertados no OnDeinit.
- Garantir que CopyBuffer é validado.
- Garantir que erros de trading são registados no log.
