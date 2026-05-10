# TITAN LION FX — Expert Advisor EURUSD

<p align="center">
  <img src="logo.svg" alt="TITAN LION FX Logo" width="520"/>
</p>

> **TITAN LION FX** — poder, precisão e disciplina no mercado forex.

Expert Advisor (EA) em MQL5 para MetaTrader 5, focado no par **EURUSD**.

Bot robusto e testável com gestão de risco clara, entradas técnicas filtradas e controlo rigoroso de drawdown.

---

## Funcionalidades

- **Filtro de tendência** via cruzamento de médias móveis (EMA rápida / EMA lenta)
- **Filtro RSI** para evitar entradas em zonas de sobrecompra / sobrevenda
- **Stop Loss e Take Profit dinâmicos** baseados em ATR (Average True Range)
- **Trailing Stop** baseado em ATR — ajusta o SL automaticamente em favor do trade
- **Lot sizing automático** baseado em risco percentual da conta
- **Filtro de spread** — evita operar quando o spread está alto
- **Prevenção de entradas repetidas** — apenas um sinal por candle fechado
- **Máximo de posições por direção** configurável
- **Magic Number próprio** — compatível com múltiplos EAs na mesma conta
- **Logs detalhados** no Journal do MetaTrader para análise de desempenho

---

## Estratégia

| Parâmetro       | Descrição                                                                 |
|-----------------|---------------------------------------------------------------------------|
| Timeframe       | Recomendado: M15 ou H1                                                   |
| Entrada BUY     | EMA rápida > EMA lenta **e** RSI > 50 **e** RSI < nível de sobrecompra   |
| Entrada SELL    | EMA rápida < EMA lenta **e** RSI < 50 **e** RSI > nível de sobrevenda    |
| Stop Loss       | Preço de entrada ± ATR × Multiplicador SL                                |
| Take Profit     | Preço de entrada ± ATR × Multiplicador TP                                |
| Trailing Stop   | Ajusta SL a cada candle usando ATR × Multiplicador Trail                 |

---

## Ficheiro

| Ficheiro                  | Descrição                            |
|---------------------------|--------------------------------------|
| `GreenLionEurUsd.mq5`     | Código fonte do Expert Advisor       |
| `logo.svg`                | Logótipo oficial TITAN LION FX       |

---

## Instalação

1. Copiar `GreenLionEurUsd.mq5` para a pasta `Experts` do MetaTrader 5:
   - Windows: `C:\Users\<Utilizador>\AppData\Roaming\MetaQuotes\Terminal\<ID>\MQL5\Experts\`
2. Abrir o MetaEditor (F4) e compilar o ficheiro.
3. Abrir o gráfico EURUSD no timeframe desejado (M15 ou H1).
4. Arrastar o EA para o gráfico ou usar `Navigator → Expert Advisors`.
5. Configurar os parâmetros e ativar o trading automático.

---

## Parâmetros de Input

### Geral

| Parâmetro       | Default        | Descrição                         |
|-----------------|----------------|-----------------------------------|
| `InpComment`    | `"GreenLion"`  | Comentário das ordens             |
| `InpMagicNumber`| `20240101`     | Número mágico do EA               |

### Médias Móveis

| Parâmetro          | Default  | Descrição                              |
|--------------------|----------|----------------------------------------|
| `InpFastMAPeriod`  | `20`     | Período da EMA rápida                  |
| `InpSlowMAPeriod`  | `50`     | Período da EMA lenta                   |
| `InpMAMethod`      | `EMA`    | Método da média móvel                  |
| `InpMAPrice`       | `Close`  | Preço aplicado                         |

### RSI

| Parâmetro          | Default | Descrição                    |
|--------------------|---------|------------------------------|
| `InpRSIPeriod`     | `14`    | Período do RSI               |
| `InpRSIOverbought` | `70`    | Nível de sobrecompra         |
| `InpRSIOversold`   | `30`    | Nível de sobrevenda          |

### ATR

| Parâmetro             | Default | Descrição                                       |
|-----------------------|---------|-------------------------------------------------|
| `InpATRPeriod`        | `14`    | Período do ATR                                  |
| `InpSLMultiplier`     | `1.5`   | Multiplicador ATR para Stop Loss                |
| `InpTPMultiplier`     | `2.5`   | Multiplicador ATR para Take Profit              |
| `InpTrailMultiplier`  | `1.0`   | Multiplicador ATR para Trailing Stop            |

### Gestão de Risco

| Parâmetro           | Default | Descrição                                              |
|---------------------|---------|--------------------------------------------------------|
| `InpAutoLot`        | `true`  | Ativar lot automático baseado em risco percentual      |
| `InpRiskPercent`    | `1.0`   | Risco por trade em % do saldo da conta (se AutoLot)   |
| `InpFixedLot`       | `0.01`  | Lot fixo (se AutoLot desativado)                       |
| `InpMaxSpreadPips`  | `2.0`   | Spread máximo permitido em pips                        |
| `InpMaxPositions`   | `1`     | Máximo de posições abertas por direção                 |

---

## Regras de Risco

- Stop Loss **obrigatório** em todas as ordens
- Take Profit **obrigatório** em todas as ordens
- Máximo de **1 posição por direção** (configurável)
- Filtro de spread para evitar execução em condições desfavoráveis
- Trailing stop move o SL apenas na direção favorável (nunca contra o trade)
- Lot calculado automaticamente para nunca exceder o risco definido

---

## Logs

O EA regista no Journal do MetaTrader:

```
[TitanLionFX] Initialized on EURUSD H1 | Magic=20240101 | AutoLot=true | Risk=1.0%
[TitanLionFX] BUY signal | Ask=1.08500 SL=1.08350 TP=1.08800 Lot=0.10 | FastMA=1.08480 SlowMA=1.08200 RSI=55.3 ATR=0.00100
[TitanLionFX] BUY opened #12345 at 1.08500
[TitanLionFX] TRAIL BUY #12345 | SL moved to 1.08420
[TitanLionFX] DEAL CLOSED | #12346 EURUSD DEAL_TYPE_SELL 0.10 @ 1.08800 | Profit: 30.00
```

---

## Melhorias Futuras

- [ ] Painel visual no gráfico (informação de conta e estado do EA)
- [ ] Exportação de estatísticas em JSON
- [ ] Gestão por basket (múltiplos trades correlacionados)
- [ ] Otimização de parâmetros com Walk-Forward Analysis
- [ ] Filtro por sessão de mercado (Londres / Nova Iorque)
- [ ] Notificações Push para dispositivos móveis
