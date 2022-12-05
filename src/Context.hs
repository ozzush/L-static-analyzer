{-# LANGUAGE InstanceSigs #-}

module Context (Context (..), InputSource (..), newContext, getVar, setVar) where

import qualified Data.Map as Map
import Error (RuntimeError)

data FunContext = FunContext deriving (Show, Eq)

newtype VarContext = VarContext {context :: Map.Map String Int} deriving (Show, Eq)

data InputSource = InputSource {fileName :: String, inputLines :: [String]} deriving (Show)

emptyVarContext :: VarContext
emptyVarContext = VarContext {context = Map.empty}

data Context = Context
  { funs :: [FunContext],
    vars :: [VarContext],
    error :: Maybe RuntimeError
  }
  deriving (Show)

instance Eq Context where
  (==) :: Context -> Context -> Bool
  (==) c1 c2 = funs c1 == funs c2 && vars c1 == vars c2

newContext :: Context
newContext =
  Context
    { funs = [FunContext],
      vars = [emptyVarContext],
      Context.error = Nothing
    }

getVar :: Context -> String -> Maybe Int
getVar ctx var = helper . vars $ ctx
  where
  helper :: [VarContext] -> Maybe Int
  helper [] = Nothing
  helper (x : xs) = case Map.lookup var (context x) of
       Nothing -> helper xs
       j -> j


setVar :: String -> Int -> Context -> Context
setVar name val ctx =
  let mp = context . head . vars $ ctx
   in let vc = VarContext $ Map.insert name val mp
   in ctx {vars = vc : (tail . vars)  ctx}
