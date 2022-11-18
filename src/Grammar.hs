module Grammar where

import Control.Monad
import Control.Monad.Combinators.Expr
import Data.Void
import Statement (Expression (..), Operations (..), Statement (..), reservedKeywords)
import Text.Megaparsec
import Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L

type Parser = Parsec Void String

sc :: Parser ()
sc = L.space (void spaceChar) empty empty

lexeme :: Parser a -> Parser a
lexeme = L.lexeme sc

symbol :: String -> Parser String
symbol = L.symbol sc

constValue :: Parser Expression
constValue = Const <$> lexeme L.decimal <?> "const value"

name :: Parser String
name = (lexeme . try) (p >>= check)
  where
    p = (:) <$> letterChar <*> many alphaNumChar <?> "Variable"
    check x
      | x `elem` reservedKeywords = fail $ "keyword " ++ show x ++ " cannot be an identifier"
      | otherwise = return x

varName :: Parser Expression
varName = VariableName <$> name

funCall :: Parser Expression
funCall = do
  FunctionCall <$> (lexeme name <?> "Function name") <*> (arguments <?> "arguments")
  where
    arguments :: Parser [Expression]
    arguments = (:) <$> expression <*> many expression

parens :: Parser a -> Parser a
parens = between (symbol "(") (symbol ")")

expressionTerm :: Parser Expression
expressionTerm =
  choice
    [ parens expression,
      try funCall,
      varName,
      constValue
    ]

expressionOperationsTable :: [[Operator Parser Expression]]
expressionOperationsTable =
  [ [ binary "*" $ compose Multiplication,
      binary "/" $ compose Division,
      binary "%" $ compose Modulo
    ],
    [ binary "+" $ compose Addition,
      binary "-" $ compose Subtraction
    ],
    [ binary "==" $ compose Equals,
      binary "!=" $ compose NotEquals,
      binary "<" $ compose Less,
      binary "<=" $ compose LessOrEquals,
      binary ">=" $ compose GreaterOrEquals,
      binary ">" $ compose Greater
    ],
    [ binary "&&" $ compose LazyAnd
    ],
    [ binary "||" $ compose LazyOr
    ]
  ]
  where
    binary :: String -> (Expression -> Expression -> Expression) -> Operator Parser Expression
    binary name f = InfixL (f <$ symbol name)

    compose :: (Expression -> Expression -> Operations) -> Expression -> Expression -> Expression
    compose f a b = Application $ f a b

expression :: Parser Expression
expression = makeExprParser expressionTerm expressionOperationsTable

letVariable :: Parser Statement
letVariable =
  Let <$> (lexeme name <?> "Variable name") <*> (symbol ":=" *> expression) <?> "Variable let"

write :: Parser Statement
write = do
  Write <$> (symbol "write" *> expression) <?> "while statement"

readVariable :: Parser Statement
readVariable = do
  Read <$> (symbol "read" *> name <?> "Read statement")

while :: Parser Statement
while =
  While
    <$> (between (symbol "while") (symbol "do") expression <?> "While condition")
    <*> (statement <?> "While statement")

ifThenElse :: Parser Statement
ifThenElse =
  If
    <$> (symbol "if" *> expression <?> "If condition")
    <*> (symbol "then" *> statement <?> "True statement")
    <*> (symbol "else" *> statement <?> "False Statement")

funCallStatement :: Parser Statement
funCallStatement =
  FunctionCallStatement
    <$> (name <?> "function name")
    <*> (arguments <?> "arguments")
  where
    arguments :: Parser [Expression]
    arguments = (:) <$> expression <*> many expression

statement :: Parser Statement
statement =
  choice
    [ write,
      readVariable,
      while,
      ifThenElse,
      try funCallStatement,
      letVariable
    ]
