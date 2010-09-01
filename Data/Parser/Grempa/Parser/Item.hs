{-# LANGUAGE MultiParamTypeClasses #-}
module Data.Parser.Grempa.Parser.Item where

import qualified Control.Arrow as A
import Control.Applicative
import Control.Monad.Reader
import Data.Function
import Data.List
import Data.Map(Map)
import qualified Data.Map as M
import Data.Maybe
import Data.Set(Set)
import qualified Data.Set as S

import Data.Parser.Grempa.Aux.Aux
import Data.Parser.Grempa.Grammar.Untyped
import Data.Parser.Grempa.Parser.Table
import Data.Parser.Grempa.Grammar.Token

import Debug.Trace

class (Eq (i s), Ord (i s), Show (i s), Token s) => It i s where
    itRId     :: i s -> RId s
    itProd    :: i s -> ProdI
    getItPos  :: i s -> Int
    setItPos  :: i s -> Int -> i s
    closure   :: Set (i s) -> Set (i s)
    startItem :: RId s -> i s

getItProd :: It i s => i s -> Prod s
getItProd i = rIdRule (itRId i) !! itProd i

isKernelIt :: It i s => RId s -> i s -> Bool
isKernelIt st it = pos > 0 || (itRId it == st && pos == 0)
  where pos = getItPos it

kernel :: It i s => RId s -> Set (i s) -> Set (i s)
kernel st = S.filter $ isKernelIt st

-- | Return the symbol to the right of the "dot" in the item
nextSymbol :: It i s => i s -> Tok (Symbol s)
nextSymbol i
    | pos < length prod = Tok $ prod !! pos
    | otherwise         = EOF
  where prod = getItProd i
        pos  = getItPos i

-- | Determine the state transitions in the parsing
goto :: (It i s, Token s) => Set (i s) -> Symbol s -> Set (i s)
goto is s = closure $ setFromJust $ S.map (nextTest s) is
  where
    nextTest x i
      | nextSymbol i == Tok x = Just $ nextItPos i
      | otherwise             = Nothing

nextItPos :: It i s => i s -> i s
nextItPos i = setItPos i $ getItPos i + 1

-- | The sets of items for a grammar
itemSets :: (It i s, Token s) => RId s -> [RId s] -> Set (Set (i s))
itemSets rid rids = S.delete S.empty $ recTraverseG itemSets' c1
  where
    c1            = S.singleton $ closure $ S.singleton $ startItem rid
    symbols       = terminals rids ++ nonTerminals rids
    itemSets' c   = (c `S.union` gs, gs)
      where gs    = S.fromList [goto i x | i <- S.toList c, x <- symbols]

data GenData i s = GenData
  { gItemSets     :: [(Set (i s), StateI)]
  , gItemSetIndex :: Map (Set (i s)) StateI
  , gRules        :: [RId s]
  , gTerminals    :: [Symbol s]
  , gNonTerminals :: [Symbol s]
  , gSymbols      :: [Symbol s]
  , gStartState   :: Int
  , gStartRule    :: RId s
  } deriving Show

type Gen i s = Reader (GenData i s)
runGen :: Gen i s a -> GenData i s -> a
runGen = runReader

gen :: (It i s, Token s) => RId s -> GenData i s
gen g = GenData is ix rs ts nt sys ss g
  where
    is  = zip (S.toList $ itemSets g rs) [0..]
    ix  = M.fromList is
    rs  = rules g
    ts  = terminals rs
    nt  = nonTerminals rs
    sys = ts ++ nt
    ss  = snd $ fromMaybe (error "gen: maybe")
              $ find (S.member (startItem g) . fst) is


askItemSet :: (It i s, Token s) => Set (i s) -> Gen i s (Maybe StateI)
askItemSet x | x == S.empty = return Nothing
askItemSet x = do
    res <- M.lookup x <$> asks gItemSetIndex
    case res of
        Just r  -> return $ Just r
        Nothing -> do
            g <- asks gStartRule
            is <- asks gItemSets
            return $ snd <$> listToMaybe (filter (S.isSubsetOf x . fst) is)