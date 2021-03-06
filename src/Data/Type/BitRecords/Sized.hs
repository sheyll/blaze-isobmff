-- | Size Fields
{-# LANGUAGE UndecidableInstances #-}
module Data.Type.BitRecords.Sized
  ( type Sized, type Sized8, type Sized16, type Sized32, type Sized64
  , type SizedField, type SizedField8, type SizedField16, type SizedField32, type SizedField64
  , type SizeFieldValue)
  where

import Data.Type.Pretty
import Data.Type.BitRecords.Core
import Data.Word
import GHC.TypeLits
import Data.Kind.Extra
import Data.Kind (type Type)

-- | A record with a /size/ member, and a nested record that can be counted
-- using 'SizeFieldValue'.
data Sized
  (sf :: IsA (BitRecordField (t :: BitField (rt :: Type) Nat (size :: Nat))))
  (r :: BitRecord)
  :: IsA BitRecord
type instance Eval (Sized sf r) =
   "size" @: sf := SizeFieldValue r .+: r

-- | A convenient alias for a 'Sized' with an 'FieldU8' size field.
type Sized8 t = Sized FieldU8 t

-- | A convenient alias for a 'Sized' with an 'FieldU16' size field.
type Sized16 t = Sized FieldU16 t

-- | A convenient alias for a 'Sized' with an 'FieldU32' size field.
type Sized32 t = Sized FieldU32 t

-- | A convenient alias for a 'Sized' with an 'FieldU64' size field.
type Sized64 t = Sized FieldU64 t

-- | A record with a /size/ member, and a nested field that can be counted
-- using 'SizeFieldValue'.
data SizedField
  (sf :: IsA (BitRecordField (t :: BitField (rt :: Type) Nat (size :: Nat))))
  (r :: IsA (BitRecordField (u :: BitField (rt' :: Type) (st' :: k0) (len0 :: Nat))))
  :: IsA BitRecord
type instance Eval (SizedField sf r) =
   "size" @: sf := SizeFieldValue r .+. r

-- | A convenient alias for a 'SizedField' with an 'FieldU8' size field.
type SizedField8 t = SizedField FieldU8 t

-- | A convenient alias for a 'SizedField' with an 'FieldU16' size field.
type SizedField16 t = SizedField FieldU16 t

-- | A convenient alias for a 'SizedField' with an 'FieldU32' size field.
type SizedField32 t = SizedField FieldU32 t

-- | A convenient alias for a 'SizedField' with an 'FieldU64' size field.
type SizedField64 t = SizedField FieldU64 t

-- | For something to be augmented by a size field there must be an instance of
-- this family to generate the value of the size field, e.g. by counting the
-- elements.
type family SizeFieldValue (c :: k) :: Nat

type instance SizeFieldValue (b :: BitRecord) = BitRecordMemberCount b
type instance SizeFieldValue (f := v) = SizeFieldValue v
type instance SizeFieldValue (LabelF l f) = SizeFieldValue f
type instance SizeFieldValue (MkField (t :: BitField (rt:: Type) (st::k) (size::Nat))) = size

type family PrintHexIfPossible t (s :: Nat) :: PrettyType where
  PrintHexIfPossible Word64 s = PutHex64 s
  PrintHexIfPossible Word32 s = PutHex32 s
  PrintHexIfPossible Word16 s = PutHex16 s
  PrintHexIfPossible Word8 s = PutHex8 s
  PrintHexIfPossible x s = TypeError ('Text "Invalid size field type: " ':<>: 'ShowType x)
