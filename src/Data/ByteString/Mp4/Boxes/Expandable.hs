{-# LANGUAGE UndecidableInstances #-}
module Data.ByteString.Mp4.Boxes.Expandable where

import           Prelude hiding ( (.) )
import           Control.Category
import           Data.ByteString.IsoBaseFileFormat.Box
import           Data.ByteString.IsoBaseFileFormat.ReExports
import           Data.Type.BitRecords
import           Data.ByteString.IsoBaseFileFormat.Util.BoxFields


-- * Static Expandable

staticExpandable
  :: forall record
   . (ToM BitStringBuilder
          (Proxy (StaticExpandableContent record))
          (StaticExpandable record)
      ~ StaticExpandable record
   , ToHoley BitStringBuilder
          (Proxy (StaticExpandableContent record))
          (StaticExpandable record)
   , KnownExpandable record
   )
   => Proxy record -> StaticExpandable record
staticExpandable = runHoley . staticExpandableHoley

staticExpandableWithArgs
  :: forall record
   . ( ToHoley BitStringBuilder
          (Proxy (StaticExpandableContent record))
          (StaticExpandable record)
   , KnownExpandable record )
   => Proxy record -> ToM BitStringBuilder (Proxy (StaticExpandableContent record)) (StaticExpandable record)
staticExpandableWithArgs = runHoley . staticExpandableHoley

staticExpandableHoley
  :: forall record r
   . ( KnownExpandable record
     , ToHoley BitStringBuilder (Proxy (StaticExpandableContent record)) r)
   => Proxy record -> Holey (StaticExpandable record) r (ToM BitStringBuilder (Proxy (StaticExpandableContent record)) r)
staticExpandableHoley _ =
  hoistM StaticExpandable (bitBoxHoley (Proxy :: Proxy (StaticExpandableContent record)))

newtype StaticExpandable r =
  StaticExpandable (BitBox (StaticExpandableContent r))
  deriving (Monoid)

deriving instance (KnownExpandable r) => IsBoxContent (StaticExpandable r)

type KnownExpandable record =
  (KnownNat
    (GetRecordSize
      (StaticExpandableContent record)))

type StaticExpandableContent record =
  ExpandableSize (ShiftR 64 (GetRecordSize record) 3) :>: record

type family ExpandableSize (s :: Nat) where
  ExpandableSize 0 = Field 0
  ExpandableSize s =
    If (s <=? 127)
      (                                       ExpandableSizeLastChunk s)
      (ExpandableSizeNext (ShiftR 64 s 7) :>: ExpandableSizeLastChunk s)

type ExpandableSizeLastChunk (s :: Nat) = Flag := 0 :>: (Field 7 := s)

type family ExpandableSizeNext (s :: Nat) where
  ExpandableSizeNext 0 = Field 0
  ExpandableSizeNext s =
    If (s <=? 127)
      (                                        ExpandableSizeNextChunk s)
      (ExpandableSizeNext (ShiftR 64 s 7) :>:  ExpandableSizeNextChunk s)

type ExpandableSizeNextChunk (s :: Nat) = Flag := 1 :>: (Field 7 := s)


-- * Runtime-value Expandable

newtype Expandable t where
    Expandable :: t -> Expandable t

instance IsBoxContent t => IsBoxContent (Expandable t) where
  boxSize (Expandable x) = expandableSizeSize (boxSize x) + boxSize x
  boxBuilder (Expandable x) = expandableSizeBuilder (boxSize x) <> boxBuilder x

expandableSizeSize :: BoxSize -> BoxSize
expandableSizeSize UnlimitedSize = error "Unlimited size not supported by expandable"
expandableSizeSize (BoxSize s)
  | s >= 2^(28 :: Int) = error "Expandable size >= 2^(28 :: Int)"
  | s >= 2^(21 :: Int) = 4
  | s >= 2^(14 :: Int) = 3
  | s >= 2^(7 :: Int) = 2
  | otherwise = 1

expandableSizeBuilder :: BoxSize -> Builder
expandableSizeBuilder UnlimitedSize = error "Unlimited size not supported by expandable"
expandableSizeBuilder (BoxSize s)
    | s >= 2 ^( 28 :: Int) = error "Expandable size >= 2^(28 :: Int)"
    | s >= 2 ^( 21 :: Int) = word8 (fromIntegral (0x80 .|. (s `unsafeShiftR` 21))) <>
          word8 (fromIntegral (0x80 .|. ((s `unsafeShiftR` 14) .&. 0x7F))) <>
          word8 (fromIntegral (0x80 .|. ((s `unsafeShiftR` 7) .&. 0x7F))) <>
          word8 (fromIntegral (s .&. 0x7F))
    | s >= 2 ^( 14 :: Int) = word8 (fromIntegral (0x80 .|. (s `unsafeShiftR` 14))) <>
          word8 (fromIntegral (0x80 .|. ((s `unsafeShiftR` 7) .&. 0x7F))) <>
          word8 (fromIntegral (s .&. 0x7F))
    | s >= 2 ^( 7 :: Int) = word8 (fromIntegral (0x80 .|. (s `unsafeShiftR` 7))) <>
          word8 (fromIntegral (s .&. 0x7F))
    | otherwise = word8 (fromIntegral s)