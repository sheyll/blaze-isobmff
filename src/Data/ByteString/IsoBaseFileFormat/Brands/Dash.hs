-- | Predefined Box composition matching the @dash@ brand. TODO this is an
-- incomplete,  special-purpose variant of this brand, serving my personal,
-- educational, current need.
-- This is a convenient way of building documents of that kind.
module Data.ByteString.IsoBaseFileFormat.Brands.Dash
       (Dash(..), mkDash, mvhd, tkhd, module X)
       where

import Data.ByteString.IsoBaseFileFormat.Boxes as X
import Data.Kind (Type, Constraint)
import Control.Lens


-- | A 'BoxLayout' which contains the stuff needed for the 'dash' brand.
-- TODO incomplete
instance KnownNat v => IsBrand (Dash v) where
  type GetVersion (Dash v) = v
  type BoxLayout (Dash v) =
    '[ OM_ FileType
     , OM  Movie
          '[ OM_ (MovieHeader v)
           , SM  Track
                '[ OM_ (TrackHeader v)
                 , OM_ Media
                      -- '[ OM_ (MediaHeader v)
                      --  , OM_ (MediaHandler v)
                      --  , OM  (MediaInformation v)
                      --       '[ OO_ (SoundMediaHeader v)
                      --        , OM  (DataInformation v)
                      --             '[ OM_ (DataReference v) ]
                      --        , OM  (SampleTable v)
                      --             '[ OM_ (SampleDescriptions v)
                      --              , OM_ (TimeToSample v)
                      --              , OM_ (SampleToChunk v)
                      --              , OO_ (SampleSizes v)
                      --              , OM_ (SampleChunkOffset v)
                      --              ]
                      --        ]
                      --  ]
                 ]
           ]
     , SO_ Skip
     ]

-- Missing Boxes
-- START 17:47:
--  mdia
--  mdhd
--  hdlr
--  minf
--  smhd
--  dinf
--  dref
--  ??url
--  stbl
--  stsd
--  stts
--  stsc
--  stsz
--  stco

--  soun
--  mp4a
--  esds
--  mvex
--  trex
-- For media
-- styp
-- moof
-- mfhd
-- traf
-- tfhd
-- trun


-- | A record which contains the stuff needed for the 'dash' brand. TODO
-- incomplete
data Dash (version :: Nat) =
  Dash {_mvhd :: MovieHeader version
       ,_tkhd :: TrackHeader version
       }

type Todo = ()

makeLenses ''Dash

-- | Convert a 'Dash' record to a generic 'Boxes' collection.
mkDash
  :: KnownNat v
  => Dash v -> MediaFile (Dash v)
mkDash doc =
  MediaFile
      $  fileTypeBox (FileType "iso5" 0 ["isom","iso5","dash","mp42"])
     .:. movie
           $  movieHeader (doc ^. mvhd)
          .:. track
                $  trackHeader (doc ^. tkhd)
               .:. media NoBoxes
