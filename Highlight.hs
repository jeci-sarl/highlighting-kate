module Main where
import Text.Highlighting.Kate
import Text.Highlighting.Kate.Syntax (languages, languagesByExtension)
import System.IO
import System.Environment
import Text.XHtml.Transitional
import System.Console.GetOpt
import System.Exit
import System.FilePath
import Data.Maybe
import Data.Char (toLower)

data Flag = CssPath String
          | Help
          | List
          | NumberLines
          | Syntax String
          | TitleAttributes
          deriving (Eq, Show)

options :: [OptDescr Flag]
options =
  [ Option ['c'] ["css"] (ReqArg CssPath "PATH") "link CSS file"
  , Option ['h'] ["help"] (NoArg Help)   "show usage message"
  , Option ['l'] ["list"] (NoArg List)   "list available language syntaxes"
  , Option ['n'] ["number-lines"] (NoArg NumberLines)  "number lines"
  , Option ['s'] ["syntax"] (ReqArg Syntax "SYNTAX")  "specify language syntax to use"
  , Option ['t'] ["title-attributes"] (NoArg TitleAttributes)  "include structure in title attributes"
  ]

cssPathOf :: [Flag] -> Maybe String
cssPathOf [] = Nothing
cssPathOf (CssPath s : _) = Just s
cssPathOf (_:xs) = cssPathOf xs

syntaxOf :: [Flag] -> Maybe String
syntaxOf [] = Nothing
syntaxOf (Syntax s : _) = Just s
syntaxOf (_:xs) = syntaxOf xs

main = do
  (opts, fnames, errs) <- getArgs >>= return . getOpt Permute options 
  let usageHeader = "Highlight [options] [files...]"
  if not (null errs)
     then ioError (userError $ concat errs ++ usageInfo usageHeader options)
     else return ()
  if List `elem` opts
     then hPutStrLn stderr (unwords languages) >> exitWith (ExitFailure 2)
     else return ()
  if Help `elem` opts
     then hPutStrLn stderr (usageInfo usageHeader options) >> 
          exitWith (ExitFailure 1)
     else return ()
  code <- if null fnames
             then getContents
             else mapM readFile fnames >>= return . concat
  let lang' = case syntaxOf opts of
                    Just e   -> Just e
                    Nothing  -> if null fnames
                                   then Nothing
                                   else let firstExt = drop 1 $ takeExtension $ head fnames
                                        in  listToMaybe $ languagesByExtension firstExt
  lang <- if lang' == Nothing
             then hPutStrLn stderr "No syntax specified." >>
                  hPutStrLn stderr (usageInfo usageHeader options) >>
                  exitWith (ExitFailure 5)
             else do let (Just l) = lang'
                     return (map toLower l)
  if not (lang `elem` (map (map toLower) languages))
     then hPutStrLn stderr ("Unknown syntax: " ++ lang) >> exitWith (ExitFailure 4)
     else return ()
  let highlightOpts = (if TitleAttributes `elem` opts then [OptTitleAttributes] else []) ++
                      (if NumberLines `elem` opts then [OptNumberLines] else [])
  let css = fromMaybe "css/highlighting-kate.css" $ cssPathOf opts
  let hcode = xhtmlHighlight highlightOpts lang code
  let renderedHtml = renderHtml $ header << [thelink ! [thetype "text/css", href css, rel "stylesheet"] << noHtml] +++
                                  body << hcode
  putStrLn renderedHtml
