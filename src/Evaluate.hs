{-# LANGUAGE BangPatterns #-}

module Evaluate (evaluateStatements, evaluateOneStatement, evaluateExpression) where

import Context (Context (..), InputSource (..), getFun, getVar, loadFunStack, setFun, setVar, unloadFunStack)
import Control.Composition
import Control.Monad.State
import Error (RuntimeError (..))
import Grammar (number)
import Statement (Expression (..), Function (..), Operations (..), Statement (..))
import Text.Megaparsec (eof, runParser)
import Text.Read (readMaybe)

evaluateList :: [Expression] -> StateT Context IO (Maybe [Int])
evaluateList [] = return $ Just []
evaluateList (x : xs) = do
  x' <- evaluateExpression x
  case x' of
    Just y -> do
      xs' <- evaluateList xs
      case xs' of
        Just ys -> return $ Just (y : ys)
        Nothing -> return Nothing
    Nothing -> return Nothing

evaluateExpression :: Expression -> StateT Context IO (Maybe Int)
evaluateExpression (Const x) = return $ Just x
evaluateExpression (VariableName name) = do
  ctx <- get
  case getVar name ctx of
    x@(Just _) -> return x
    Nothing -> do
      put (ctx {Context.error = Just $ VarNotFound name})
      return Nothing
evaluateExpression (FunctionCall name argumentValues) = do
  ctx <- get
  case getFun name ctx of
    Nothing ->
      do
        put $ ctx {Context.error = Just $ FunctionNotFound name}
        return Nothing
    Just f ->
      do
        argumentValues' <- evaluateList argumentValues
        case argumentValues' of
          Nothing -> return Nothing
          Just args -> do
            modify (loadFunStack f args) -- FIXME: check length
            let Function _ statements returnExpr = f
            evaluateStatements statements
            returnValue <- case returnExpr of
              Nothing ->
                do
                  put $ ctx {Context.error = Just $ CallOfVoidFunctionInExpression name}
                  return Nothing
              Just expr ->
                do
                  evaluateExpression expr
            modify unloadFunStack
            return returnValue
evaluateExpression (Application op') = do
  let (x, y, op) = unpack op'
  x' <- evaluateExpression x
  y' <- evaluateExpression y
  case (x', y') of
    (Just val_x, Just val_y) -> return $ Just $ op val_x val_y
    (_, _) -> return Nothing
  where
    -- FIXME: fix that crappy design
    unpack :: Operations -> (Expression, Expression, Int -> Int -> Int)
    unpack (Addition lft rgt) = (lft, rgt, (+))
    unpack (Subtraction lft rgt) = (lft, rgt, (-))
    unpack (Division lft rgt) = (lft, rgt, div)
    unpack (Multiplication lft rgt) = (lft, rgt, (*))
    unpack (Modulo lft rgt) = (lft, rgt, mod)
    unpack (Equals lft rgt) = (lft, rgt, fromBool .* (==))
    unpack (NotEquals lft rgt) = (lft, rgt, fromBool .* (/=))
    unpack (Greater lft rgt) = (lft, rgt, fromBool .* (>))
    unpack (GreaterOrEquals lft rgt) = (lft, rgt, fromBool .* (>=))
    unpack (Less lft rgt) = (lft, rgt, fromBool .* (<))
    unpack (LessOrEquals lft rgt) = (lft, rgt, fromBool .* (<=))
    unpack (LazyAnd lft rgt) = (lft, rgt, lazyAnd)
    unpack (LazyOr lft rgt) = (lft, rgt, lazyOr)

    lazyAnd :: Int -> Int -> Int
    lazyAnd lft rgt = if lft == 0 then 0 else boolToInt rgt

    lazyOr :: Int -> Int -> Int
    lazyOr lft rgt = if lft /= 0 then 1 else boolToInt rgt

    fromBool :: Bool -> Int
    fromBool True = 1
    fromBool False = 0

    boolToInt :: Int -> Int
    boolToInt 0 = 0
    boolToInt _ = 1

toBool :: Int -> Bool
toBool 0 = False
toBool _ = True

evaluateOneStatement :: Statement -> StateT Context IO ()
evaluateOneStatement (Let name value) = do
  value' <- evaluateExpression value
  case value' of
    Just val -> modify (setVar name val)
    Nothing -> pure ()
evaluateOneStatement Skip = pure ()
evaluateOneStatement (While expression statements) = do
  value <- evaluateExpression expression
  case value of
    Just val
      | toBool val -> pure ()
      | otherwise -> evaluateStatements statements
    Nothing -> pure ()
evaluateOneStatement (If expression trueStatements falseStatements) = do
  value <- evaluateExpression expression
  case value of
    Just val
      | toBool val -> evaluateStatements trueStatements
      | otherwise -> evaluateStatements falseStatements
    Nothing -> pure ()
evaluateOneStatement (FunctionCallStatement name argumentValues) = do
  ctx <- get
  case getFun name ctx of
    Nothing ->
      do
        put $ ctx {Context.error = Just $ FunctionNotFound name}
        return ()
    Just f ->
      do
        argumentValues' <- evaluateList argumentValues
        case argumentValues' of
          Nothing -> return ()
          Just args -> do
            modify (loadFunStack f args) -- FIXME: check length
            let Function _ statements returnExpr = f
            evaluateStatements statements
            !returnValue <- case returnExpr of
              Nothing ->
                do
                  put $ ctx {Context.error = Just $ CallOfVoidFunctionInExpression name}
                  return Nothing
              Just expr ->
                do
                  evaluateExpression expr
            modify unloadFunStack
            return ()
evaluateOneStatement (Write expr) = do
  value <- evaluateExpression expr
  case value of
    Just val -> lift $ print val
    Nothing -> pure ()
evaluateOneStatement (Read var) = do
  ctx <- get
  inp <- lift getLine
  case readMaybe inp :: Maybe Int of
    Nothing -> put $ ctx {Context.error = Nothing}
    Just val -> put $ setVar var val ctx
evaluateOneStatement (FunctionDeclaration name f) = do
  modify $ setFun name f

evaluateStatements :: [Statement] -> StateT Context IO ()
evaluateStatements [] = pure ()
evaluateStatements (x : xs) = do
  evaluateOneStatement x
  evaluateStatements xs
