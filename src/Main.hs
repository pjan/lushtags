----------------------------------------------------------------------------
-- |
-- Module      :  Main
-- License     :  MIT (see LICENSE)
-- Authors     :  Bit Connor <bit@mutantlemon.com>
--
-- Maintainer  :  Bit Connor <bit@mutantlemon.com>
-- Stability   :  unstable
-- Portability :  portable
--
-- lushtags, Create ctags compatible tags files for Haskell programs
--
-----------------------------------------------------------------------------

module Main (main) where

import Data.List (isPrefixOf, partition)
import Data.Vector(Vector, fromList)
import Language.Haskell.Exts (parseFileContentsWithMode, ParseMode(..), knownExtensions, ParseResult(ParseOk, ParseFailed))
import Language.Haskell.Exts.Extension (Language(..), KnownExtension(..), Extension(..))
import Language.Preprocessor.Cpphs hiding (filename)
import System.Environment (getArgs, getProgName)
import System.IO (hPutStrLn, stderr)
import qualified Data.Text as T (unpack, lines, pack, unlines)
import qualified Data.Text.IO as T (readFile, putStr)

import Tags (Tag, createTags, tagToString)

main :: IO ()
main = do
    rawArgs <- getArgs
    let (options, files) = getOptions rawArgs
        ignore_parse_error = "--ignore-parse-error" `elem` options
    case files of
        [] -> do
            progName <- getProgName
            hPutStrLn stderr $ "Usage: " ++ progName ++ " [options] [--] <file>"
        filename:_ -> processFile filename ignore_parse_error >>= printTags

printTags :: [Tag] -> IO ()
printTags tags =
    T.putStr $ T.unlines $ map (T.pack . tagToString) tags

processFile :: FilePath -> Bool -> IO [Tag]
processFile file ignore_parse_error =
    let parse f = runCpphs defaultCpphsOptions file f
    in do
    (fileContents, fileLines) <- loadFile file
    parsed <- parse fileContents
    case parseFileContentsWithMode parseMode parsed of
        ParseFailed loc message ->
            if ignore_parse_error then
                return []
            else
                -- TODO Better error reporting
                fail $ "Parse error: " ++ show loc ++ ": " ++ message
        ParseOk parsedModule -> return $ createTags (parsedModule, fileLines)
    where
        parseMode = ParseMode
            { parseFilename = file
            , baseLanguage = Haskell2010
            , extensions = knownExtensions ++ [EnableExtension QuasiQuotes,
                                               EnableExtension OverloadedStrings,
                                               EnableExtension GADTs,
                                               EnableExtension CPP,
                                               EnableExtension MultiParamTypeClasses,
                                               EnableExtension MultiWayIf,
                                               EnableExtension TypeFamilies,
                                               EnableExtension GeneralizedNewtypeDeriving,
                                               EnableExtension FlexibleContexts,
                                               EnableExtension EmptyDataDecls,
                                               EnableExtension ViewPatterns,
                                               EnableExtension TupleSections,
                                               EnableExtension DeriveDataTypeable,
                                               EnableExtension TemplateHaskell,
                                               EnableExtension RecordWildCards
                                              ]
            , ignoreLanguagePragmas = False
            , ignoreLinePragmas = True
            , fixities = Nothing
            , ignoreFunctionArity = False
            }

loadFile :: FilePath -> IO (String, Vector String)
loadFile file = do
    text <- T.readFile file
    let fullContents = T.unpack text
    let textLines = T.lines text
    let stringLines = map T.unpack textLines
    let fileLines = fromList stringLines
    return (fullContents, fileLines)

getOptions :: [String] -> ([String], [String])
getOptions args =
    let (start, end) = span (/= "--") args
        (options, nonOptions) = partition (isPrefixOf "-") start
    in (options, nonOptions ++ dropSep end)
    where
        dropSep ("--":xs) = xs
        dropSep xs        = xs
