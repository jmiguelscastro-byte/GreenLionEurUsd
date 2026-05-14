# 📊 GUIA DE PARÂMETROS DE BACKTEST - GreenLionEURUSD

> **Documento de Referência para Backtesting**  
> Versão: 1.11  
> Atualizado: 07-05-2026

---

## 🎯 CONFIGURAÇÃO RECOMENDADA DO BACKTEST

### ✅ Resposta rápida (Timeframe e Balance)

```text
Timeframe inicial recomendado: M15
Depósito inicial recomendado:  5,000.00 USD
```

### 1️⃣ **PARÂMETROS GERAIS DO MT5**

```
├── Símbolo: EURUSD
├── Timeframe Simulação: M15 (recomendado)
├── Modo: 1 click / OHLC / Open prices
├── Spread: 10 pontos (padrão EURUSD real)
├── Ponto de Partida: 01-01-2024
└── Ponto Final: Atual (07-05-2026)
```

**Como funciona agora:**
- ✓ O timeframe-base do EA passa a ser sempre o timeframe do gráfico onde está anexado.
- ✓ Isto permite testar e ajustar a lógica no timeframe que escolheres sem manter `M15` hardcoded.
- ✓ Os filtros superiores que continuam em `H1/H4` mantêm-se fixos nesta versão.

---

### 2️⃣ **BALANCE E GESTÃO DE RISCO**

```
Depósito Inicial:        5,000.00 USD
├─ Risco por Trade:      1.00% (perfil agressivo)
│  └─ Em caso de falha: 0.50% (modo reduzido)
├─ Máximo Diário:        4.0% (drawdown permitido)
├─ Máximo Semanal:       10.0% (drawdown máximo)
├─ Máximo Trades/Dia:    6 operações
├─ Basket Trading:       Ativo por defeito
├─ Máx. posições/dir.:   3
└─ Máx. posições total:  4
```

**Justificação:**
- Balance de 5K simula conta real profissional
- 1.00% aumenta impacto estatístico por trade sem cair logo em sizing extremo
- Limite diário mais largo evita bloquear o EA cedo demais em fases com múltiplos setups válidos
- Basket controlado permite escalar setups fortes e analisar o PnL por grupo, sem abrir exposição ilimitada

### 2.1️⃣ **BASKET / MULTI-ENTRY / HEDGE**

```
GEN_EnableBasketTrading:      true ⭐ (NOVO - v1.04)
GEN_MaxPositionsPerDirection: 3 ⭐ (AJUSTADO - v1.06)
GEN_MaxTotalPositions:        4 ⭐ (AJUSTADO - v1.06)
GEN_AllowOppositeDirections:  true ⭐ (AJUSTADO - v1.10)
RISK_UseBasketLotProgression: true ⭐ (NOVO - v1.05)
RISK_BasketInitialLot:        0.01 ⭐ (NOVO - v1.05)
RISK_BasketLotMultiplier:     1.30 ⭐ (AJUSTADO - v1.06)
RISK_BasketMaxEntries:        3 ⭐ (AJUSTADO - v1.06)
RISK_BasketMaxRiskPercent:    50.0 ⭐ (NOVO - v1.07)
EXIT_BasketTargetCurrency:    0.0 ⭐ (AJUSTADO - v1.07)
EXIT_BasketTargetRR:          0.0 ⭐ (AJUSTADO - v1.07)
```

**Como interpretar:**
- O EA passa a aceitar mais do que uma posição do mesmo lado quando a conta é `hedging`.
- Cada grupo recebe um `Basket ID` e o log mostra `floating` e `realized profit` por basket.
- O EA passa a tentar abrir posições em direções opostas por defeito, mas isso só funciona de forma independente em contas `hedging`.
- Em contas `netting`, uma posição oposta não coexistirá com a anterior: o MT5 reduz, fecha ou reverte a posição líquida do símbolo.
- O lote da primeira entrada do basket começa em `0.01` e as entradas seguintes escalam por `1.30x` até ao limite configurado.
- Quando o EA está em `RISK_PERCENT_EQUITY`, esta progressão é tratada como teto conservador: não ultrapassa o lote permitido pelo risco do stop.
- O basket passa a ter teto de risco agregado equivalente a `50%` do saldo da conta, medido pelo risco ainda aberto nas posições do grupo.
- O fecho rápido por lucro agregado do basket fica desligado por defeito para dar mais tempo a flutuações e recuperação.

---

### 3️⃣ **PARÂMETROS DE ENTRADA (ENTRY)**

#### EMAs (Médias Móveis)
```
EMA Rápida (H1):    20 períodos
EMA Média (H1):     50 períodos
EMA Lenta (H1):     200 períodos
EMA Média (H4):     50 períodos
EMA Lenta (H4):     200 períodos
```

#### RSI (Índice de Força Relativa)
```
Período:            14 (padrão)
Entrada H1:         > 50 (compra) ou < 50 (venda)
Rejeição:           Entre 45-55 = neutro
```

#### ATR (Average True Range)
```
Período:            14 (padrão)
Mínimo H1:          80 pts
Máximo H1:          700 pts
Multiplicador SL:   2.40 ⭐ (AJUSTADO - v1.08)
```

**Nota de calibração:**
- Nesta versão o stop foi alargado para `2.40x ATR` para dar mais espaço de recuperação e reduzir saídas prematuras por ruído intraday.
- Isto aumenta bastante a distância ao SL, por isso o impacto real no lote depende ainda do teto de risco do basket e do modelo de sizing.

#### MACD
```
Fast:               12
Slow:               26
Signal:             9
Validação:          MACD > ATR*0.02 (novo filtro)
```

#### Bollinger Bands (M15)
```
Período:            20
Desvio:             2.0
Validação:          Espaço > 10 pts
```

#### Tendência (Bias Filter)
```
Separação EMA:      100 pontos ⭐ (AJUSTADO - v1.03)
MACD Threshold:     ATR * 0.02 ⭐ (NOVO - v1.01)
Confirmação:        EMA50 > EMA200 (uptrend)
                    EMA50 < EMA200 (downtrend)
```

**Motivo do ajuste:**
- O report atual mostrou sub-exposição severa: apenas 7 trades em 2024-2026, quase todos por breakout.
- Para intraday, EMAs mais responsivas, neutral zone mais curta e um bias menos rígido tendem a aumentar frequência sem remover a confirmação estrutural.

#### Pullback / Breakout
```
Pullback Tolerance ATR:  0.65 ⭐ (AJUSTADO - v1.03)
Breakout Buffer:         8 pontos ⭐ (AJUSTADO - v1.03)
Asian Range Mínimo:      80 pontos ⭐ (AJUSTADO - v1.03)
Squeeze Width Máx:       320 pontos ⭐ (AJUSTADO - v1.03)
```

**Motivo do ajuste:**
- O backtest mostrou que a estratégia estava praticamente dependente do setup `BO` e a perder demasiadas oportunidades por filtros encadeados em excesso.
- A nova calibração tenta desbloquear mais trades sem retirar SL, TP, spread filter ou limites de drawdown.

---

### 4️⃣ **PARÂMETROS DE SAÍDA (EXIT)**

```
Take Profit RR:            2.20 (Risk:Reward)
Break-Even Ativação:       RR 1.00 (50% do TP)
Trailing Stop Ativação:    RR 1.50
Trailing Stop ATR Mult:    1.50
Break-Even Buffer:         5 pontos
Basket Target USD:         18.0 ⭐ (NOVO - v1.06)
Basket Target RR:          1.20 ⭐ (NOVO - v1.06)
```

### Defaults atuais de proteção - v1.08
```
Break-Even Ativação:       RR 1.80 ⭐ (DESLIGADO quando modo basket-loss-only está ativo)
Trailing Stop Ativação:    RR 2.80 ⭐ (DESLIGADO quando modo basket-loss-only está ativo)
Basket Target USD / RR:    0.0 / 0.0 ⭐ (DESATIVADO - v1.07)
Basket Loss Close %:       50.0 ⭐ (NOVO - v1.09)
Basket Profit Trail Start: 2.0% do saldo ⭐ (NOVO - v1.09)
Basket Profit Trail Back:  0.75% do saldo ⭐ (NOVO - v1.09)
```

**Exemplo de Trade:**
```
Entrada (ASK):      1.10000
Stop Loss (SL):     1.09880 (-120 pts)
Take Profit (TP):   1.10264 (+264 pts = 120 * 2.20)

Ao atingir RR 1.00 (-5 pts = TP/2):
  → Move SL para Break-Even + 5pts

Ao atingir RR 1.50:
  → Ativa Trailing Stop (ATR * 1.50)

No modo atual, a perda só é fechada manualmente quando o basket aberto atinge perda agregada igual a `50%` do saldo.
   → O basket deixa de sair por perda individual normal e passa a usar trailing do lucro ao nível do grupo.
```

**Nota crítica:**
- `50%` de risco por basket é extremamente agressivo. Isto resolve o problema de baskets demasiado pequenos, mas aumenta muito a variância e o risco de drawdown severo.
- As trades continuam a ter `SL` obrigatório por exigência operacional, mas nesta versão o `SL` enviado é apenas um stop de segurança distante; a saída em prejuízo passa a ser controlada pelo basket loss agregado.
- O trailing do lucro também deixa de ser por trade individual e passa a atuar ao nível do lucro total do basket.

---

### 5️⃣ **FILTROS (FILTERS)**

#### Spread
```
Máximo Permitido:    18 pontos ⭐ (AJUSTADO - v1.02)
Rejeição:            > 18 pts = Não entra
```

#### Horários (UTC) - v1.03
```
Janela Principal 1:  07:00 - 12:30
Janela Principal 2:  12:30 - 18:00
Janela Breakout:     06:30 - 10:00
Sessão Asiática:     00:00 - 07:00
```

**Motivo do ajuste:**
- A janela anterior era curta demais para um sistema que já filtrava por spread, ATR, bias e estrutura. Isto aumentava qualidade marginalmente, mas cortava demasiado a amostra.

#### Horários (UTC)
```
Janela Principal 1:  07:00 - 11:30 (Londres abertura)
Janela Principal 2:  13:00 - 16:30 (Nova York abertura)
Janela Breakout:     06:55 - 09:00 (Asian breakout)
Sessão Asiática:     00:00 - 06:45
```

#### Notícias
```
Ativado:             NÃO (por enquanto)
Modo:                Manual (verificar calendário)
```

---

## 📈 **CHECKLIST DE BACKTEST**

### Antes de começar:
- [ ] Histórico EURUSD atualizado (até 07-05-2026)
- [ ] Visualizar 2-3 anos de dados no gráfico
- [ ] Verificar spread padrão (10 pts)
- [ ] Comissão ativada: SIM
- [ ] Slippage: 1-2 pontos

### Durante o backtest:
- [ ] Anotar período com melhor performance
- [ ] Anotar período com pior performance
- [ ] Contar operações por tipo (long/short)
- [ ] Monitorar draw-down máximo
- [ ] Verificar sequência de perdas

### Após backtest:
- [ ] Win Rate deve ser > 35%
- [ ] Razão R:R deve ser > 1.0
- [ ] Máxima sequência de perdas < 5
- [ ] Draw-down < 10% do balance
- [ ] Operações > 50 (amostra significativa)

---

## 🔍 **COMPARAÇÃO: v1.00 vs v1.01**

| Parâmetro | v1.00 | v1.01 | Impacto |
|-----------|-------|-------|--------|
| Stop Loss ATR | 1.40 | 1.20 | -30% perdas |
| Spread Máx | 15 pts | 18 pts | +frequência de entrada |
| Separação EMA | 200 pts | 100 pts | +frequência de setup |
| MACD Validação | ≥ 0 | ≥ ATR*0.02 | +10% filtro |
| Risco por Trade | 0.50% | 1.00% | +exposição por oportunidade |
| Máx Trades/Dia | 2 | 6 | +amostra operacional |
| Janelas Horárias | curtas | alargadas | +mais contexto negociável |
| **Resultado Esperado** | conservador | **mais agressivo e mais ativo** | **mais retorno e mais DD** |

---

## 📊 **MÉTRICAS ESPERADAS (v1.03)**

```
Period:              01-10-2025 a 07-05-2026 (7 meses)
Total Operations:    25-45
├─ Winning:         40-55%
├─ Losing:          35-50%
└─ Break-Even:      5-15%

Performance:
├─ Win Rate:        40%+ ✓
├─ Avg Win:         +70-140 pts
├─ Avg Loss:        -60-110 pts
├─ Razão R:R:       1.0-1.6
└─ Total P&L:       materialmente superior ao perfil conservador, com mais variabilidade
```

---

## 🛠️ **COMO EXECUTAR NO MT5**

### Passo 1: Preparar
```
1. Abrir MetaTrader 5
2. Selecionar EURUSD (M15)
3. Ir a: View > Strategy Tester (Ctrl+R)
```

### Passo 2: Configurar
```
EA Name:             GreenLionEurUsd.ex5
Symbol:              EURUSD
Timeframe:           M15
Date From:           01-01-2024
Date To:             Hoje
Initial Deposit:     5000.00
```

### Passo 3: Inputs
```
GEN_MagicNumber:     26050701
RISK_Model:          1 (Percent Equity)
RISK_PercentPerTrade: 1.00
RISK_ReducedPercentPerTrade: 0.50
RISK_MaxTradesPerDay: 6
FILTER_MaxSpreadPoints: 18.0
FILTER_MinATRH1Points: 60.0
ENTRY_MinTrendSeparationPoints: 100.0
ENTRY_PullbackToleranceATR: 0.65
ENTRY_BreakoutBufferPoints: 8.0
ENTRY_MinAsianRangePoints: 80.0
ENTRY_MaxSqueezeWidthPoints: 320.0
ENTRY_StopATRMultiplier: 1.20
GEN_OnlyOnNewBar:     false
```

### Passo 4: Rodar
```
1. Cliccar "Start"
2. Esperar conclusão (~5-10 min)
3. Analisar resultados
4. Exportar relatório (HTML/CSV)
```

---

## 📉 **BENCHMARK DE SUCESSO**

> **Importante:** este perfil 1.03 existe para corrigir sub-exposição severa observada no backtest. Valida sempre em walk-forward e forward demo antes de usar em real.

```
🟢 EXCELENTE (Implementar em Real)
   ├─ Win Rate: 55%+
   ├─ Razão R:R: 1.5+
   ├─ Draw-down: < 5%
   └─ Lucro: +1% ao mês

🟡 BOM (Otimizar mais)
   ├─ Win Rate: 45-55%
   ├─ Razão R:R: 1.0-1.5
   ├─ Draw-down: 5-10%
   └─ Lucro: 0-1% ao mês

🔴 RUIM (Revisar parâmetros)
   ├─ Win Rate: < 45%
   ├─ Razão R:R: < 1.0
   ├─ Draw-down: > 10%
   └─ Lucro: Negativo
```

---

## 🔧 **AJUSTES SE NECESSÁRIO**

### Se Win Rate muito baixo (<35%):
```
1. Aumentar ENTRY_MinTrendSeparationPoints → 250
2. Aumentar ENTRY_RSI_Period → 21
3. Reduzir ENTRY_PullbackToleranceATR → 0.25
4. Aumentar ENTRY_BBands_Deviation → 2.5
```

### Se Perdas muito grandes (>100 pts):
```
1. Reduzir ENTRY_StopATRMultiplier → 1.0
2. Reduzir RISK_PercentPerTrade → 0.25
3. Aumentar FILTER_MaxSpreadPoints → 18
```

### Se sem operações (0 trades):
```
1. Reduzir ENTRY_MinTrendSeparationPoints → 150
2. Ampliar FILTER_MainWindow1EndHourUTC → 12:30
3. Desabilitar FILTER_UseNewsFilter
4. Reduzir ENTRY_StopATRMultiplier → 1.40
```

---

## 📝 **LOG DO BACKTEST**

Modelo para anotar resultados:

```markdown
## Backtest Report - v1.01

Data:          07-05-2026
Período:       01-01-2024 to 07-05-2026
Balance Inicial: 5000.00
Balance Final:   [___________]
P&L:            [___________]
% Retorno:      [___________]

Operações:
├─ Total:       [____]
├─ Ganhos:      [____] ([__]%)
├─ Perdas:      [____] ([__]%)
└─ Neutros:     [____] ([__]%)

Performance:
├─ Maior Ganho:     [___________]
├─ Maior Perda:     [___________]
├─ Draw-down Max:   [___________]
├─ Sequência Perdas: [____] operações
└─ Avg Win/Loss:    [___________]

Conclusão:
[Escrever análise aqui]

Próximos Passos:
[ ] Fase 2: Break-Even + Trailing Stop
[ ] Fase 3: Otimização de parâmetros
[ ] Fase 4: Forward test (50 dias reais)
```

---

## ⚠️ **OBSERVAÇÕES IMPORTANTES**

1. **Backtest vs Real:** Resultados em backtest podem variar 20-30% em conta real
2. **Slippage:** MT5 simula automaticamente; em real pode ser +5-10 pts
3. **Comissão:** Verificar se está incluída (+0.5-1 USD por operação)
4. **Horários:** Todos em UTC; ajustar para seu servidor
5. **Spread:** EURUSD varia 5-20 pts; máximo teste é 15 pts

---

**📌 Última atualização:** 07-05-2026 (v1.01)  
**👤 Autor:** GreenLion EA Development  
**📧 Questões:** Verificar Agent.md para regras
