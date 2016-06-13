{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE TypeApplications #-}

module Main where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BSL
import           Data.Hex
import           Data.ProtocolBuffers
import           Data.Serialize.Get
import           Data.Serialize.Put
import qualified Gaia.VectorTile.Raw as R
import           Test.Tasty
import           Test.Tasty.HUnit
import qualified Text.ProtocolBuffers.WireMessage as PB
import qualified Vector_tile.Tile as VT

---

main :: IO ()
main = BS.readFile "streets.mvt" >>= defaultMain . suite

{- SUITES -}

suite :: BS.ByteString -> TestTree
suite vt = testGroup "Unit Tests"
  [ testGroup "Serialization Isomorphism"
    [ testCase ".mvt <-> Raw.Tile" $ fromRaw vt
    , testCase "testTile <-> protobuf" testTileIso
    ]
  , testGroup "Testing auto-generated code"
    [ testCase ".mvt <-> PB.Tile" $ pbRawIso vt
    ]
  , testGroup "Cross-codec Isomorphisms"
    [ testCase "ByteStrings only" crossCodecIso1
    , testCase "Full encode/decode" crossCodecIso
    ]
  ]

fromRaw :: BS.ByteString -> Assertion
fromRaw vt = case decodeIt vt of
--               Right l -> hex (encodeIt l) @=? hex vt
               Right l -> if runPut (encodeMessage l) == vt
                          then assert True
                          else assertString "Isomorphism failed."
               Left e -> assertFailure e

testTileIso :: Assertion
testTileIso = case decodeIt pb of
                 Right tl -> assertEqual "" tl testTile
                 Left e -> assertFailure e
  where pb = encodeIt testTile

pbRawIso :: BS.ByteString -> Assertion
pbRawIso vt = case pbIso vt of
                Right vt' -> assertEqual "" (hex vt) (hex vt')
                Left e -> assertFailure e

-- | Can an `R.VectorTile` be converted to a `Vector_tile.Tile` and back?
crossCodecIso :: Assertion
crossCodecIso = case pbIso (encodeIt testTile) >>= decodeIt of
                  Left e -> assertFailure e
                  Right t -> t @=? testTile

-- | Will just their `ByteString` forms match?
crossCodecIso1 :: Assertion
crossCodecIso1 = case pbIso vt of
                  Left e -> assertFailure e
                  Right t -> hex t @=? hex vt
  where vt = encodeIt testTile

-- | Isomorphism for Vector_tile.Tile
pbIso :: BS.ByteString -> Either String BS.ByteString
pbIso (BSL.fromStrict -> vt) = do
   (t,_) <- PB.messageGet @VT.Tile vt
   pure . BSL.toStrict $ PB.messagePut @VT.Tile t

decodeIt :: BS.ByteString -> Either String R.VectorTile
decodeIt = runGet decodeMessage

encodeIt :: R.VectorTile -> BS.ByteString
encodeIt = runPut . encodeMessage

{- UTIL -}

isRight :: Either a b -> Bool
isRight (Right _) = True
isRight _ = False

testTile :: R.VectorTile
testTile = R.VectorTile $ putField [l]
  where l = R.Layer { R.version = putField 2
                    , R.name = putField "testlayer"
                    , R.features = putField [f]
                    , R.keys = putField ["somekey"]
                    , R.values = putField [v]
                    , R.extent = putField $ Just 4096
                    }
        f = R.Feature { R.featureId = putField $ Just 0
                      , R.tags = putField [0,0]
                      , R.geom = putField $ Just R.Point
                      , R.geometries = putField [9, 50, 34]  -- MoveTo(+25,+17)
                      }
        v = R.Val { R.string = putField $ Just "Some Value"
                  , R.float = putField Nothing
                  , R.double = putField Nothing
                  , R.int64 = putField Nothing
                  , R.uint64 = putField Nothing
                  , R.sint = putField Nothing
                  , R.bool = putField Nothing
                  }