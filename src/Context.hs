{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE PatternSynonyms #-}

module Context where

import qualified Data.Map as Map
import Error (RuntimeError)

data FunContext = FunContext deriving (Show, Eq)

newtype VarContext = VarContext {context :: Map.Map String Int} deriving (Show, Eq)

data InputSource = InputSource {fileName :: String, inputLines :: [String]} deriving (Show)

emptyVarContext :: VarContext
emptyVarContext = VarContext {context = Map.empty}

setVarContext :: String -> Int -> VarContext -> VarContext
setVarContext name val ctx =
  let mp = context ctx in 
  VarContext $ Map.insert name val mp

data Context = Context
  { funs :: FunContext,
    vars :: VarContext,
    error :: Maybe RuntimeError
  }
  deriving (Show)

pattern ErrorContext :: Context
pattern ErrorContext <- Context { Context.error = (Just _) }

instance Eq Context where
  (==) :: Context -> Context -> Bool
  (==) c1 c2 = funs c1 == funs c2 && vars c1 == vars c2

newContext :: Context
newContext =
  Context
    { funs = FunContext,
      vars = emptyVarContext,
      Context.error = Nothing
    }

getVar :: Context -> String -> Maybe Int
getVar cxt var =
  let mp = context . vars $ cxt
   in Map.lookup var mp

setVar :: String -> Int -> Context -> Context
setVar name val ctx =
  let mp = context . vars $ ctx
   in ctx {vars = VarContext $ Map.insert name val mp}
