# EURUSD WebTrader 5 Bot

Projeto para criar um Expert Advisor em MQL5 para MetaTrader 5, focado no par EURUSD.

O objetivo é desenvolver um bot simples, robusto e testável, com gestão de risco clara, entradas técnicas filtradas e controlo rigoroso de drawdown.

## Objetivo principal

Criar um EA para EURUSD que:
- Analise tendência e volatilidade.
- Abra operações apenas com critérios bem definidos.
- Use stop loss, take profit e trailing stop.
- Respeite limites de risco por trade e por conta.
- Tenha inputs fáceis de configurar no Strategy Tester.
- Gere logs claros para análise futura.

## Estratégia inicial

Timeframe recomendado: M15 ou H1.

Critérios base:
- Usar médias móveis para tendência.
- Usar RSI para evitar entradas em zonas extremas.
- Usar ATR para calcular stop loss/take profit dinâmicos.
- Evitar operar com spread alto.
- Evitar múltiplas entradas repetidas no mesmo candle.

## Regras de risco

- Risco máximo por trade configurável.
- Lot size fixo ou automático.
- Stop loss obrigatório.
- Take profit obrigatório.
- Máximo de uma posição aberta por direção.
- Filtro de spread.
- Magic Number próprio.

## Prioridade

Primeiro criar uma versão estável e simples.
Depois melhorar com:
- Backtest otimizado.
- Painel visual.
- Estatísticas.
- Exportação JSON.
- Gestão por basket.
