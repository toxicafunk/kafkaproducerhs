#!/usr/bin/env stack
-- stack script --resolver lts-11.7
import Conduit

main :: IO ()
main = runConduit
     $ yieldMany [1..10]
    .| iterMC print
    .| liftIO (putStrLn "I was called")
    .| sinkNull
