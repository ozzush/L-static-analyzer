module Test.Console where

import Grammar (Parser)
import CommandLineParser (varArg)
import Test.HUnit
import Text.Megaparsec

parseSuccessful :: Eq a => Parser a -> String -> a -> Bool
parseSuccessful parser line result = case parse (parser <* eof) "" line of
  Left _ -> False
  Right a -> a == result

parseFailed :: Parser a -> String -> Bool
parseFailed parser line = case parse (parser <* eof) "" line of
  Left _ -> True
  Right _ -> False

unit_varParser = do
  let success = parseSuccessful varArg
  let fail = parseFailed varArg

  assertBool "1" $ success "x=10" ("x", 10)
  assertBool "3" $ success "x=0" ("x", 0)

  assertBool "4" $ fail "x tr=1"
  assertBool "5" $ fail "1tr=5"
  assertBool "6" $ fail "x=vr"
