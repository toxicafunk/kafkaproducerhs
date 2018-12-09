module Main where

import System.Environment (getArgs)
import Control.Exception
import Control.Parallel.Strategies
import Control.Applicative
import Control.Concurrent.Async
import Data.Maybe
import Haskakafka
import qualified Data.ByteString.Char8 as C8

type Producer = (Kafka -> KafkaTopic -> IO (Maybe KafkaError)) -> IO (Maybe KafkaError)

sendMessage :: Producer -> C8.ByteString -> C8.ByteString -> IO (Maybe KafkaError)
sendMessage producer msg key = producer $ \kafka topic -> do
    let keyMessage = KafkaProduceKeyedMessage key msg
    produceKeyedMessage topic keyMessage

extractKey :: String -> C8.ByteString
extractKey line = {-# SCC "extractKey" #-} do
  let from_comma = dropWhile (/= ':') line
  let txt = drop 2 $ takeWhile (/= ',') from_comma
  C8.pack $ take (length txt - 1) txt

processMessage :: Producer -> String -> IO (Maybe KafkaError)
processMessage producer line = sendMessage producer (C8.pack line) (extractKey line)

main :: IO ()
main = do
  [f] <- getArgs
  let kafkaConfig = [("queue.buffering.max.ms", "0"),
                     ("request.timeout.ms", "5000"),
                     ("message.timeout.ms", "300000")]
      producer = withKafkaProducer kafkaConfig [] "172.18.0.2:9092,172.18.0.4:9092,172.18.0.5:9092" "julio.genio.stream"
  file <- readFile f

  let ios = mapConcurrently (processMessage producer) (lines file) --`using` parList rseq
  ios >>= \lst -> print (length $ filter isJust lst)
