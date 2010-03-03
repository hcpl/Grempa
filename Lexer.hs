module Lexer where
import ParserCore
import Control.Applicative
import Data.Char

data Symbol
  = Id String
  | LParen | RParen
  | UScore
  | Arrow
  | HasType
  | Comment
  | LComment | RComment
  | LBrace   | RBrace
  | Spc
  deriving (Show, Eq)

(-->) :: Eq s => [s] -> a -> Parser s a
str --> sym = do
    match  str
    return sym

(|->) :: Eq s => [[s]] -> a -> Parser s a
ss |-> sym = oneOf $ map (--> sym) ss

lexer :: Parser Char [Symbol]
lexer = some . oneOf $
    [ "("    --> LParen
    , ")"    --> RParen
    , "_"    --> UScore
    , ["->"] |-> Arrow
    , ["::"] |-> HasType
    , "--"   --> Comment
    , "{-"   --> LComment
    , "-}"   --> RComment
    , "{"    --> LBrace
    , "}"    --> RBrace
    , const Spc <$> mmunch isSpace
    , Id        <$> mmunch (not . isSpace)
    ]

-------------------------------------------------------------------------------
-- Helper functions

match :: Eq s => [s] -> Parser s [s]
match y = do x <- look; m y x
  where 
    m (r:rs) (s:ss) 
      | r == s = do symbol; ss' <- m rs ss; return (s : ss')
    m [] _ = return []
    m _  _ = pfail

mmunch :: (s -> Bool) -> Parser s [s]
mmunch p = do
    ss <- look
    case ss of
      s:ss | p s -> munch p
      _ -> pfail

oneOf :: [Parser s a] -> Parser s a
oneOf = foldl1 (<|>)

-------------------------------------------------------------------------------
-- Indentation syntax

indentToBraces :: String -> String
indentToBraces inp = {-f ++-} indent [0] $ map startSpaces (s:ss)
  where
    (n, f) = startSpaces s
    (s:ss) = lines inp

    indent :: [Int] -> [(Int, String)] -> String
    indent ns ((_,[]):xs) = indent ns xs
    indent (n:ns) ((s,x):xs) = case compare s n of
        GT -> " { " ++ x ++ indent (s : n : ns) xs
        EQ -> " ; " ++ x ++ indent (n : ns)     xs
        LT -> " } "      ++ indent ns ((s, x) : xs)
    indent [] [] = ""
    indent (n:ns) [] = " } " ++ indent ns []

    startSpaces :: String -> (Int, String)
    startSpaces (s:ss) | isSpace s = let (sp, str) = startSpaces ss in (sp + 1, str)
    startSpaces ss                 = (0, ss)

testFile = readFile "Test.fs"
testStr s = return s

indentTest i = indentToBraces <$> i
test i = parse lexer . indentToBraces <$> i

mmunchTest = parse (Id <$> mmunch (not . isSpace))
