{-# LANGUAGE OverloadedStrings #-}
module Main where

import Prelude hiding (readFile, lines, length, drop, dropWhile, take, takeWhile)
import System.Environment (getArgs)
import Control.Exception
import Control.Monad (forM_)
--import Control.Applicative
import Control.Concurrent.Async
import Data.ByteString (ByteString, length, drop, take, readFile)
import Data.ByteString.Char8 (dropWhile, lines, takeWhile)
import Data.Maybe (isJust)
import qualified Data.Foldable as F (length)
import Kafka.Producer

--import Control.Parallel.Strategies

producerProps :: ProducerProperties
producerProps = brokersList [BrokerAddress "172.18.0.2:9092,172.18.0.4:9092,172.18.0.5:9092"]
             <> logLevel KafkaLogDebug

targetTopic :: TopicName
targetTopic = TopicName "julio.genio.stream"

main :: IO ()
main = do
  [f] <- getArgs
  file <- readFile f
  producer  <- newProducer producerProps
  --ioEithers <- sequence $ parMap rseq (processMessage producer) (lines file) --`using` parList rseq)
  ioEithers <- mapConcurrently (processMessage producer) (lines file)
  print $ F.length $ filter isJust ioEithers

processMessage :: Either KafkaError KafkaProducer -> ByteString -> IO (Maybe KafkaError)
processMessage (Right producer) line = sendMessage producer (extractKey line) line
processMessage (Left err) line = return (Just err)


sendMessage :: KafkaProducer -> ByteString -> ByteString -> IO (Maybe KafkaError)
sendMessage prod key msg = produceMessage prod (mkMessage (Just key) (Just msg))

mkMessage :: Maybe ByteString -> Maybe ByteString -> ProducerRecord
mkMessage k v = ProducerRecord
                  { prTopic = targetTopic
                  , prPartition = UnassignedPartition
                  , prKey = k
                  , prValue = v
                  }

extractKey :: ByteString -> ByteString
extractKey line = do
  let from_comma = dropWhile (/= ':') line
  let txt = drop 2 $ takeWhile (/= ',') from_comma
  take (length txt - 1) txt
