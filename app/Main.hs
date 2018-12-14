{-# LANGUAGE OverloadedStrings #-}
module Main where

import Prelude hiding (readFile, lines, length, drop, dropWhile, take, takeWhile)
import System.Environment (getArgs)
import Control.Exception (bracket)
--import Control.Concurrent.Async
import Control.Lens
import Control.Monad.Except (catchError, throwError)
import Control.Monad.Trans (liftIO)
import Control.Monad.Trans.State.Lazy (StateT)
import Control.Monad.Trans.Except (ExceptT)
import Data.ByteString (ByteString, length, drop, take, readFile)
import Data.ByteString.Char8 (dropWhile, lines, takeWhile, pack)
import Data.Maybe (isNothing)
import Data.Either (isRight)
import qualified Data.Foldable as F (length)
import Network.Kafka
import Network.Kafka.Producer
import Network.Kafka.Protocol (ProduceResponse(..), KafkaError(..), CompressionCodec(..), Message, TopicName)

main :: IO ()
main =  do
  let topic = "julio.genio.stream"
      bootstrapServers = "172.18.0.3"
      run = runKafka $ mkKafkaState "milena-test-client" (bootstrapServers, 9092)
      requireAllAcks = do
        stateRequiredAcks .= -1
        stateWaitSize .= 1
        stateWaitTime .= 1000

  [f] <- getArgs
  file <- readFile f
  result <- run $ do
        requireAllAcks
        processMessages topic (lines file)
  print result

processMessages :: TopicName -> [ByteString] -> StateT KafkaState (ExceptT KafkaClientError IO) [ProduceResponse]
processMessages topic lineArr = produceMessages $ mkMessage topic lineArr

mkMessage :: TopicName -> [ByteString] -> [TopicAndMessage]
mkMessage topic msgs =
  fmap (TopicAndMessage topic . toTopicMessage) msgs
  where
    toTopicMessage :: ByteString -> Message
    toTopicMessage msg = makeKeyedMessage (extractKey msg) msg

extractKey :: ByteString -> ByteString
extractKey line = do
  let from_comma = dropWhile (/= ':') line
  let txt = drop 2 $ takeWhile (/= ',') from_comma
  take (length txt - 1) txt
