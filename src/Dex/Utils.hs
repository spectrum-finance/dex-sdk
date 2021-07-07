{-# LANGUAGE RecordWildCards #-}

module Dex.Utils where

import           Dex.Models as ROp  (RedeemOpData(..)) 
import           Dex.Models as DOp  (DepositOpData(..)) 
import           Dex.Models
import           Ledger                           hiding (txOutValue)
import qualified PlutusTx.Builtins                as Builtins
import           Plutus.V1.Ledger.Value as Value
import qualified PlutusTx.AssocMap                as Map
import           Plutus.V1.Ledger.Address

fullTxOut2TxOut :: FullTxOut -> TxOut
fullTxOut2TxOut _ = undefined

generateUserSwapOutput :: SwapOpData -> Pool -> TxOut
generateUserSwapOutput SwapOpData{..} Pool{..} =
    let
        address = pubKeyHashAddress $ PubKeyHash userPubKey
        toSwapTokenSymbol = if (inputTokenSymbol == (tokenXSymbol poolData)) then (tokenYSymbol poolData) else (tokenXSymbol poolData)
        toSwapTokenName = if (inputTokenName == (tokenXName poolData)) then (tokenYName poolData) else (tokenXName poolData)
        currentRate = calculateSwapRate toSwapTokenSymbol toSwapTokenName (txOutValue proxyBox) fullTxOut
        -- value = Value { Map.Map toSwapToken }
    in undefined --TxOut {}

generatePoolSwapOutput :: SwapOpData -> Pool -> TxOut
generatePoolSwapOutput swapData pool = undefined
    -- let

    -- in TxOut {}

generateUserDepositOutput :: DepositOpData -> Pool -> TxOut
generateUserDepositOutput depositData pool = 
    let address = Dex.Models.txOutAddress $ fullTxOut pool
        currentPoolData = poolData pool
        poolValue = txOutValue $ fullTxOut pool
        reward = rewardLP depositData pool
        poolLPTokenValue = valueOf poolValue (CurrencySymbol $ tokenLPSymbol currentPoolData) (TokenName $ tokenLPName currentPoolData)
        newAmountLP = poolLPTokenValue - reward
        lpValue = Value.singleton (CurrencySymbol $ tokenLPSymbol currentPoolData) (TokenName $ tokenLPName currentPoolData) newAmountLP
        poolDatum = fullTxOutDatum $ fullTxOut pool
        poolDatumHash = datumHash poolDatum
    in TxOut address lpValue (Just poolDatumHash)

generatePoolDepositOutput :: DepositOpData -> Pool -> TxOut
generatePoolDepositOutput depositData pool =
    let address = Dex.Models.txOutAddress $ fullTxOut pool
        depositValue = txOutValue $ DOp.proxyBox depositData
        currentPoolData = poolData pool
        poolValue = txOutValue $ fullTxOut pool
        reward = rewardLP depositData pool
        poolXTokenValue = valueOf poolValue (CurrencySymbol $ tokenXSymbol currentPoolData) (TokenName $ tokenXName currentPoolData)
        poolYTokenValue = valueOf poolValue (CurrencySymbol $ tokenYSymbol currentPoolData) (TokenName $ tokenYName currentPoolData)
        poolLPTokenValue = valueOf poolValue (CurrencySymbol $ tokenLPSymbol currentPoolData) (TokenName $ tokenLPName currentPoolData)
        depositXValue = valueOf depositValue (CurrencySymbol $ inputTokenXSymbol depositData) (TokenName $ inputTokenXName depositData)
        depositYValue = valueOf depositValue (CurrencySymbol $ inputTokenYSymbol depositData) (TokenName $ inputTokenYName depositData)
        newAmountLP = poolLPTokenValue - reward
        newAmountX = poolXTokenValue + depositXValue
        newAmountY = poolYTokenValue + depositYValue
        xValue = Value.singleton (CurrencySymbol $ tokenXSymbol currentPoolData) (TokenName $ tokenXName currentPoolData) newAmountX
        yValue = Value.singleton (CurrencySymbol $ tokenYSymbol currentPoolData) (TokenName $ tokenYName currentPoolData) newAmountY
        lpValue = Value.singleton (CurrencySymbol $ tokenLPSymbol currentPoolData) (TokenName $ tokenLPName currentPoolData) newAmountLP
        resultedValue = xValue <> yValue <> lpValue
        poolDatum = fullTxOutDatum $ fullTxOut pool
        poolDatumHash = datumHash poolDatum
    in TxOut address resultedValue (Just poolDatumHash)

rewardLP :: DepositOpData -> Pool -> Integer
rewardLP depositData pool =
    let depositValue = txOutValue $ DOp.proxyBox depositData
        currentPoolData = poolData pool
        poolValue = txOutValue $ fullTxOut pool
        depositXValue = valueOf depositValue (CurrencySymbol $ inputTokenXSymbol depositData) (TokenName $ inputTokenXName depositData)
        depositYValue = valueOf depositValue (CurrencySymbol $ inputTokenYSymbol depositData) (TokenName $ inputTokenYName depositData)
        poolXTokenValue = valueOf poolValue (CurrencySymbol $ tokenXSymbol currentPoolData) (TokenName $ tokenXName currentPoolData)
        poolYTokenValue = valueOf poolValue (CurrencySymbol $ tokenYSymbol currentPoolData) (TokenName $ tokenYName currentPoolData)
        poolLPTokenValue = valueOf poolValue (CurrencySymbol $ tokenLPSymbol currentPoolData) (TokenName $ tokenLPName currentPoolData)
        currentSupply = totalEmissionLP - poolLPTokenValue
        minX = depositXValue * currentSupply `div` poolXTokenValue
        minY = depositYValue * currentSupply `div` poolYTokenValue
        result = if (minX < minY) then minX else minY
    in result

generateUserRedeemOutput :: RedeemOpData -> Pool -> TxOut
generateUserRedeemOutput redeemData pool =
    let address = pubKeyHashAddress $ PubKeyHash $ ROp.userPubKey redeemData
        currentPoolData = poolData pool
        (shareX, shareY) = sharesLP redeemData pool
        xValue = Value.singleton (CurrencySymbol $ tokenXSymbol currentPoolData) (TokenName $ tokenXName currentPoolData) shareX
        yValue = Value.singleton (CurrencySymbol $ tokenYSymbol currentPoolData) (TokenName $ tokenYName currentPoolData) shareY
        -- redeemBox.value - minerFeeBox.value - dexFeeBox.value ???
        newValue = xValue <> yValue
        poolDatum = fullTxOutDatum $ fullTxOut pool
        poolDatumHash = datumHash poolDatum
    in TxOut address newValue (Just poolDatumHash)

generatePoolRedeemOutput :: RedeemOpData -> Pool -> TxOut
generatePoolRedeemOutput redeemData pool =
    let address = Dex.Models.txOutAddress $ fullTxOut pool
        currentPoolData = poolData pool
        poolValue = txOutValue $ fullTxOut pool
        poolXTokenValue = valueOf poolValue (CurrencySymbol $ tokenXSymbol currentPoolData) (TokenName $ tokenXName currentPoolData)
        poolYTokenValue = valueOf poolValue (CurrencySymbol $ tokenYSymbol currentPoolData) (TokenName $ tokenYName currentPoolData)
        poolLPTokenValue = valueOf poolValue (CurrencySymbol $ tokenLPSymbol currentPoolData) (TokenName $ tokenLPName currentPoolData)
        redeemLPToken = valueOf (txOutValue $ ROp.proxyBox redeemData) (CurrencySymbol $ tokenLPSymbol currentPoolData) (TokenName $ tokenLPName currentPoolData)
        (shareX, shareY) = sharesLP redeemData pool
        newAmountLP = poolLPTokenValue + redeemLPToken
        newAmountX = poolXTokenValue - shareX
        newAmountY = poolYTokenValue - shareY
        xValue = Value.singleton (CurrencySymbol $ tokenXSymbol currentPoolData) (TokenName $ tokenXName currentPoolData) newAmountX
        yValue = Value.singleton (CurrencySymbol $ tokenYSymbol currentPoolData) (TokenName $ tokenYName currentPoolData) newAmountY
        lpValue = Value.singleton (CurrencySymbol $ tokenLPSymbol currentPoolData) (TokenName $ tokenLPName currentPoolData) newAmountLP
        newValue = xValue <> yValue <> lpValue
        poolDatum = fullTxOutDatum $ fullTxOut pool
        poolDatumHash = datumHash poolDatum
    in TxOut address newValue (Just poolDatumHash)

totalEmissionLP :: Integer
totalEmissionLP = 0x7fffffffffffffff

sharesLP :: RedeemOpData -> Pool -> (Integer, Integer)
sharesLP redeemData pool =
    let poolValue = txOutValue $ fullTxOut pool
        currentPoolData = poolData pool
        poolLPTokenValue = valueOf poolValue (CurrencySymbol $ tokenLPSymbol currentPoolData) (TokenName $ tokenLPName currentPoolData)
        redeemLPToken = valueOf (txOutValue $ ROp.proxyBox redeemData) (CurrencySymbol $ tokenLPSymbol currentPoolData) (TokenName $ tokenLPName currentPoolData)
        poolXTokenValue = valueOf poolValue (CurrencySymbol $ tokenXSymbol currentPoolData) (TokenName $ tokenXName currentPoolData)
        poolYTokenValue = valueOf poolValue (CurrencySymbol $ tokenYSymbol currentPoolData) (TokenName $ tokenYName currentPoolData)
        supplyLP = totalEmissionLP - poolLPTokenValue
        xValue = redeemLPToken * poolXTokenValue `div` supplyLP
        yValue = redeemLPToken * poolYTokenValue `div` supplyLP
    in (xValue, yValue)

generateEmptyValue :: Value
generateEmptyValue = Value Map.empty

calculateSwapRate :: Builtins.ByteString -> Builtins.ByteString -> Value -> FullTxOut -> Integer
calculateSwapRate tokenSymbolToSwap tokenNameToSwap boxToSwapValue currentPool = undefined