# FX_Combined_Portfolio_Currency_V1_1 仕様書 / Codexレビュー用

## 1. 目的

既存の `Combined_Portfolio_DowFib_plus_BuySell.mq5` をベースに、Gold/XAUUSD向けだったpips・ロット・決済・スプレッド設定を、EURUSD / USDJPY向けの通貨EA叩き台へ変更する。

今回のV1.0では、まず「通貨で通常Buy/Sellロジックが復活するか」を検証するため、EA② BUY/SELL Portfolio側を主役にする。

## 2. 開発方針

- いきなりGold / EURUSD / USDJPY統合プリセット版にはしない。
- まず通貨専用版としてEURUSD / USDJPYを同一設定でテストする。
- 初期値はドル円のボラに寄せたやや守り設定。
- Goldで封印していたEA②通常Sellロジックを復活させる。
- Sell専用スナイパー型は初期OFF。
- EA① DowFibは初期OFF。ただし、通貨用pipsに数値変更済みなので後でON検証可能。
- ナンピンは初期OFF。素のエントリーと決済性能を確認する。

## 3. 対象ファイル

- 元ファイル: `Combined_Portfolio_DowFib_plus_BuySell.mq5`
- 通貨版: `FX_Combined_Portfolio_Currency_V1_1.mq5`

## 4. 主要変更点

### 4.1 起動スイッチ

| 項目 | Gold版 | 通貨版V1 |
|---|---:|---:|
| `ComboUse_DowFibEA` | true | false |
| `ComboUse_BuySellEA` | true | true |

理由: 最初の検証ではEA②の通常Buy/Sellロジックを単体評価したい。

### 4.2 pips換算の修正

元Gold版のEA②には以下の補正が入っていた。

```mq5
return pips * 10.0;
```

通貨版ではこれを無効化し、入力値を一般的なFX pipsとして扱う。

```mq5
return pips;
```

これにより、EURUSDでは 1pip = 0.0001、USDJPYでは 1pip = 0.01 として扱う。

重要: この修正をしないと、`InpTP_Pips = 15` が実質150pips級になってしまう可能性がある。


### 4.3 Sell専用スナイパー側のpips換算も通貨用へ統一

V1.1では、初期OFFのSell専用スナイパー側も今後ON検証できるように、Gold用の固定pips値を通貨用へ変更した。

主な修正:

| 項目 | Gold版 | 通貨版V1.1 |
|---|---:|---:|
| `S_InpPipSize` | 0.01固定 | 0.0 = 自動判定 |
| `S_InpLots` | 1.00 | 0.01 |
| `S_InpMaxSpreadPips` | 50 | 2 |
| `S_InpMinFVGSizePips` | 25 | 2 |
| `S_InpMaxFVG_OB_DistancePips` | 100 | 10 |
| `S_InpRetestTolerancePips` | 10 | 3 |
| `S_InpSL_BufferPips` | 30 | 3 |
| `S_InpMinSL_Pips` | 100 | 10 |
| `S_InpMaxSL_Pips` | 700 | 25 |
| `S_InpZoneMatchTolerancePips` | 5 | 3 |

`S_Pip()` は `S_InpPipSize > 0` の場合のみ手動値を使い、0ならシンボル桁数から自動判定する。

```mq5
double S_Pip()
{
   if(S_InpPipSize > 0.0) return S_InpPipSize;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5) return _Point * 10.0;
   return _Point;
}
```

これで、EA① / EA② / Sell専用スナイパーのすべてが、EURUSDでは1pip=0.0001、USDJPYでは1pip=0.01の標準換算になる。

## 5. EA② BUY/SELL Portfolio 通貨用初期設定

| パラメータ | Gold版目安 | 通貨版V1 | 目的 |
|---|---:|---:|---|
| `InpBuyLots` | 1.00 | 0.01 | 固定ロット時の安全初期値 |
| `InpMinConfluence` | 1.5 | 1.5 | 初期は取引回数確保 |
| `InpTP_Pips` | 350 | 15 | 通貨用TP |
| `InpSL_Pips` | 120 | 20 | 通貨用SL |
| `InpNanpinStepPips` | 30 | 12 | 後で使う場合の幅 |
| `InpMaxNanpinCount` | 3 | 0 | 初期はナンピンOFF |
| `InpOB_MinBodyPips` | 10.0 | 2.0 | 通貨用OB実体幅 |
| `InpTouchTolerancePips` | 20.0 | 3.0 | 通貨用タッチ許容幅 |
| `InpAllowBuy` | true | true | Buy許可 |
| `InpAllowSell` | false | true | 通貨版で通常Sell復活 |
| `InpUseBuyTrendFilter` | false | true | 通貨版初期ON |
| `InpUseSellTrendFilter` | true | true | SellフィルターON |
| `InpUsePullbackEntry` | false | false | 初期は即時エントリー |
| `InpPullbackEntryPips` | 25 | 5 | 押し戻り待ち使用時 |
| `InpBETriggerPips` | 200 | 8 | 建値発動 |
| `InpBEOffsetPips` | 10 | 1 | 建値+1pip保護 |
| `InpPartialTriggerPips` | 250 | 10 | 部分利確発動 |
| `InpPartialSLPips` | 100 | 5 | 部分利確後SL |
| `InpPartialClosePercent` | 60.0 | 50.0 | 半利確割合 |
| `InpUseSpreadFilter` | false | true | 通貨では必須 |
| `InpMaxSpreadPips` | 2.0 | 1.5 | 最大スプレッド |
| `InpUseAutoLot` | true | true | リスク%運用 |
| `InpRiskPercentPerTrade` | 1.0 | 0.25 | 初期は小さく |
| `InpFixedLotFallback` | 0.10 | 0.01 | 予備ロット |
| `InpMaxLot` | 1.00 | 0.10 | 最大ロット制限 |
| `InpMaxTotalLotsPerCycle` | 100.00 | 0.10 | サイクル合計ロット上限 |
| `InpMaxCycleRiskPercent` | 5.0 | 1.0 | サイクル最大リスク |
| `InpMasterStopLosses` | 5 | 2 | 2連敗停止 |
| `InpMaxDrawdownPercent` | 10.0 | 5.0 | 最大DD停止 |

## 6. EA① DowFib 通貨用初期値

EA①は初期OFF。ただし、後で検証できるように通貨用数値へ変更済み。

| パラメータ | Gold版 | 通貨版V1 |
|---|---:|---:|
| `D_InpMaxSpreadPips` | 80 | 2 |
| `D_InpDailyMaxLossPercent` | 2.5 | 1.5 |
| `D_InpMaxOpenPositions` | 5 | 3 |
| `D_InpMaxLotPerTrade` | 20.0 | 0.10 |
| `D_InpRiskPercent_*` | 0.5 | 0.25 |
| `D_InpMinImpulsePips` | 500 | 30 |
| `D_InpSLBufferPips` | 50 | 3 |
| `D_InpMinSLPips` | 500 | 10 |
| `D_InpMaxSLPips` | 1000 | 25 |
| `D_InpMinFVGSizePips` | 20 | 2 |
| `D_InpMinBodyPips` | 20 | 2 |
| `D_InpMoveSLPlusPips` | 200 | 2 |
| `D_InpTrailBufferPips` | 30 | 3 |

## 7. Sell専用スナイパー

通貨版V1.1でも初期OFF。ただし、将来ON検証できるようにpips・ロット・SL関連の初期値は通貨用へ修正済み。

追加した入力:

```mq5
input bool S_InpEnable = false;
```

`S_InpEnable == true` の時だけ、`S_OnInitModule()` と `S_OnTickModule()` を実行する。

理由:

- 今回はEA②の通常Sell復活が主目的。
- Sell専用スナイパーはGold特化色が強く、最初に入れると検証が濁る。

## 8. 推奨バックテスト手順

### 8.1 最初の対象

- EURUSD M15
- USDJPY M15

### 8.2 テスト期間

- 2024-01-01 ～ 2025-12-31
- 2026-01-01 ～ 最新
- 可能なら2024〜2026通し

### 8.3 最初の比較

1. EA② Buyのみ: `InpAllowBuy=true`, `InpAllowSell=false`
2. EA② Sellのみ: `InpAllowBuy=false`, `InpAllowSell=true`
3. EA② Buy/Sell両方: `InpAllowBuy=true`, `InpAllowSell=true`
4. 半利確ON/OFF比較
5. `InpMinConfluence=1.5` と `2.0` 比較
6. TP/SLセット比較
   - 標準: TP15 / SL20 / BE8
   - 守り: TP12 / SL18 / BE7
   - PF重視: TP18 / SL20 / BE10

## 9. 合格目安

| 指標 | 目安 |
|---|---:|
| PF | 1.3以上で検証継続、1.5以上なら有望 |
| 勝率 | 55〜70% |
| 最大DD | 低いほど良い。単発巨大DDがないこと |
| 取引回数 | 少なすぎないこと |
| Buy/Sell | 片側だけが足を引っ張っていないか確認 |
| 月別成績 | 大負け月が連続しないこと |
| ナンピン | OFFでも成立することが理想 |

## 10. Codexレビュー依頼ポイント

Codexには以下を重点的に見てもらう。

1. MQL5としてコンパイルエラーがないか。
2. `S_InpEnable` 追加によるSell専用スナイパーOFF処理が正しく効いているか。
3. EA②のpips換算変更により、EURUSD / USDJPYで一般的なpips換算になっているか。
4. Sell専用スナイパー側の `S_Pip()` が `S_InpPipSize=0` の時に自動pips判定になっているか。
5. `IsSpreadAllowed()` が通貨pips基準で正しく判定しているか。
6. `InpMaxNanpinCount=0` の時にナンピンが完全に止まるか。
7. `InpAllowSell=true` でEA②通常Sellが正しく動くか。
8. Buy/Sell両方ON時に、BuyScore / SellScore の比較で意図しない同時エントリーが起きないか。
9. MagicNumber分離とGlobalVariable名に、通貨版として危険な干渉がないか。
10. 既存ポジション管理がBuy/Sell両方向で正しく動くか。
11. `PipsToPrice()` 修正により、既存のロット計算・SL計算・TP計算で副作用がないか。

## 11. 注意事項

- このV1は完成版ではなく、通貨移植の叩き台。
- まずはナンピンOFFで素の優位性を確認する。
- EA① DowFibは後でONにして個別検証する。
- 最終的にGold / EURUSD / USDJPYのプリセット統合版を作る場合は、今回の結果を元に別途統合する。
