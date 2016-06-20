{-# LANGUAGE StrictData #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- |
-- Module    : Geography.VectorTile
-- Copyright : (c) Azavea, 2016
-- License   : Apache 2
-- Maintainer: Colin Woodbury <cwoodbury@azavea.com>
--
-- GIS Vector Tiles, as defined by Mapbox.
--
-- This library implements version 2.1 of the official Mapbox spec, as defined
-- here: https://github.com/mapbox/vector-tile-spec/tree/master/2.1
--
-- Note that currently this library ignores top-level protobuf extensions,
-- /Value/ extensions, and /UNKNOWN/ geometries.
--
-- The order in which to explore the modules of this library is as follows:
--
-- 1. "Geography.VectorTile" (here)
-- 2. "Geography.VectorTile.Geometry"
-- 3. "Geography.VectorTile.Protobuf"
--
-- == Usage
--
-- This library reads and writes strict `ByteString`s. Given some legal
-- VectorTile file called @roads.mvt@:
--
-- > import qualified Data.ByteString as BS
-- > import           Data.Text (Text)
-- > import           Geography.VectorTile
-- > import qualified Geography.VectorTile.Protobuf as PB
-- >
-- > -- | Read in raw protobuf data and decode it into a high-level type.
-- > roads :: IO (Either Text VectorTile)
-- > roads = do
-- >   mvt <- BS.readFile "roads.mvt"
-- >   pure $ PB.decode mvt >>= PB.tile
--
-- Or encode a `VectorTile` back into a `ByteString`:
--
-- > roadsBytes :: VectorTile -> BS.ByteString
-- > roadsBytes = PB.encode . PB.untile

module Geography.VectorTile
  ( -- * Types
    VectorTile(..)
  , Layer(..)
  , Feature(..)
  , Val(..)
    -- * Lenses
    -- | This section can be safely ignored if one isn't concerned with lenses.
    -- Otherwise, see the following for a good primer on Haskell lenses:
    -- http://hackage.haskell.org/package/lens-tutorial-1.0.1/docs/Control-Lens-Tutorial.html
    --
    -- These lenses are written in a generic way to avoid taking a dependency
    -- on one of the lens libraries.
  , layers
  , version
  , name
  , points
  , linestrings
  , polygons
  , extent
  , featureId
  , metadata
  , geometries
  ) where

import           Control.DeepSeq (NFData)
import           Data.Int
import qualified Data.Map.Lazy as M
import           Data.Text (Text)
import qualified Data.Vector as V
import           Data.Word
import           GHC.Generics (Generic)
import           Geography.VectorTile.Geometry

---

-- | A high-level representation of a Vector Tile. At its simplest, a tile
-- is just a list of `Layer`s.
--
-- There is potential to implement `_layers` as a `M.Map`, with its String-based
-- `name` as a key.
newtype VectorTile = VectorTile { _layers :: V.Vector Layer } deriving (Eq,Show,Generic)

-- | > Lens' VectorTile (Vector Layer)
layers :: Functor f => (V.Vector Layer -> f (V.Vector Layer)) -> VectorTile -> f VectorTile
layers f v = VectorTile <$> f (_layers v)
{-# INLINE layers #-}

instance NFData VectorTile

-- | A layer, which could contain any number of `Feature`s of any `Geometry` type.
-- This codec only respects the canonical three `Geometry` types, and we split
-- them here explicitely to allow for more fine-grained access to each type.
data Layer = Layer { _version :: Int  -- ^ The version of the spec we follow. Should always be 2.
                   , _name :: Text
                   , _points :: V.Vector (Feature Point)
                   , _linestrings :: V.Vector (Feature LineString)
                   , _polygons :: V.Vector (Feature Polygon)
                   , _extent :: Int  -- ^ Default: 4096
                   } deriving (Eq,Show,Generic)

-- | > Lens' Layer Int
version :: Functor f => (Int -> f Int) -> Layer -> f Layer
version f l = fmap (\v -> l { _version = v }) $ f (_version l)
{-# INLINE version #-}

-- | > Lens' Layer Text
name :: Functor f => (Text -> f Text) -> Layer -> f Layer
name f l = fmap (\v -> l { _name = v }) $ f (_name l)
{-# INLINE name #-}

-- | > Lens' Layer (Vector (Feature Point))
points :: Functor f => (V.Vector (Feature Point) -> f (V.Vector (Feature Point))) -> Layer -> f Layer
points f l = fmap (\v -> l { _points = v }) $ f (_points l)
{-# INLINE points #-}

-- | > Lens' Layer (Vector (Feature LineString)))
linestrings :: Functor f => (V.Vector (Feature LineString) -> f (V.Vector (Feature LineString))) -> Layer -> f Layer
linestrings f l = fmap (\v -> l { _linestrings = v }) $ f (_linestrings l)
{-# INLINE linestrings #-}

-- | > Lens' Layer (Vector (Feature Polygon)))
polygons :: Functor f => (V.Vector (Feature Polygon) -> f (V.Vector (Feature Polygon))) -> Layer -> f Layer
polygons f l = fmap (\v -> l { _polygons = v }) $ f (_polygons l)
{-# INLINE polygons #-}

-- | > Lens' Layer Int
extent :: Functor f => (Int -> f Int) -> Layer -> f Layer
extent f l = fmap (\v -> l { _extent = v }) $ f (_extent l)
{-# INLINE extent #-}

instance NFData Layer

-- | A geographic feature. Features are a set of geometries that share
-- some common theme:
--
-- * Points: schools, gas station locations, etc.
-- * LineStrings: Roads, power lines, rivers, etc.
-- * Polygons: Buildings, water bodies, etc.
--
-- Where, for instance, all school locations may be stored as a single
-- `Feature`, and no `Point` within that `Feature` would represent anything
-- else.
--
-- Note: Each `Geometry` type and their /Multi*/ counterpart are considered
-- the same thing, as a `V.Vector` of that `Geometry`.
data Feature g = Feature { _featureId :: Int  -- ^ Default: 0
                         , _metadata :: M.Map Text Val
                         , _geometries :: V.Vector g } deriving (Eq,Show,Generic)

-- | > Lens' (Feature g) Int
featureId :: Functor f => (Int -> f Int) -> Feature g -> f (Feature g)
featureId f l = fmap (\v -> l { _featureId = v }) $ f (_featureId l)
{-# INLINE featureId #-}

-- | > Lens' (Feature g) (Map Text Val)
metadata :: Functor f => (M.Map Text Val -> f (M.Map Text Val)) -> Feature g -> f (Feature g)
metadata f l = fmap (\v -> l { _metadata = v }) $ f (_metadata l)
{-# INLINE metadata #-}

-- | > Lens' (Feature g) (Vector g)
geometries :: Functor f => (V.Vector g -> f (V.Vector g)) -> Feature g -> f (Feature g)
geometries f l = fmap (\v -> l { _geometries = v }) $ f (_geometries l)
{-# INLINE geometries #-}

instance NFData g => NFData (Feature g)

-- | Legal Metadata /Value/ types. Note that `S64` are Z-encoded automatically
-- by the underlying "Data.ProtocolBuffers" library.
data Val = St Text | Fl Float | Do Double | I64 Int64 | W64 Word64 | S64 Int64 | B Bool
         deriving (Eq,Show,Generic)

instance NFData Val
