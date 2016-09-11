{-# LANGUAGE UndecidableInstances #-}
module Data.Type.BitRecords.Core where

import Data.Int
import Data.Kind (Type, Constraint)
import Data.Kind.Extra
import Data.Proxy
import Data.Type.BitRecords.Arithmetic

import Data.Type.Pretty
import Data.Word
import GHC.TypeLits

-- * Records

-- ** Record ADT

-- | 'BitRecordField's assembly
data BitRecord where
  BitRecordMember    :: forall (t :: RecordFieldType rt st len) . BitRecordField t -> BitRecord
  (:>:)              :: BitRecord      -> BitRecord -> BitRecord
  BitRecordDoc       :: PrettyType     -> BitRecord
  BitRecordDocNested :: PrettyType     -> BitRecord -> BitRecord
  EmptyBitRecord     :: BitRecord
  -- TODO  MissingBitRecord          :: ErrorMessage     -> BitRecord
infixl 3 :>:

-- | A conditional 'BitRecord'
type family WhenR (b :: Bool) (x :: BitRecord) :: BitRecord where
  WhenR 'False r = 'EmptyBitRecord
  WhenR 'True r  = r

-- *** Basic Accessor

-- | Eval the size in as a number of bits from a 'BitRecord'
type family BitRecordSize (x :: BitRecord) :: Nat where
  BitRecordSize ('BitRecordMember f)      = BitRecordFieldSize f
  BitRecordSize (l ':>: r)                = BitRecordSize l + BitRecordSize r
  BitRecordSize ('BitRecordDoc d)         = 0
  BitRecordSize ('BitRecordDocNested d r) = BitRecordSize r
  BitRecordSize 'EmptyBitRecord           = 0

-- | The total number of members in a record.
type family BitRecordMemberCount (b :: BitRecord) :: Nat where
  BitRecordMemberCount ('BitRecordMember f)      = 1
  BitRecordMemberCount (l ':>: r)                = BitRecordMemberCount l + BitRecordMemberCount r
  BitRecordMemberCount ('BitRecordDoc r)         = 0
  BitRecordMemberCount ('BitRecordDocNested d r) = BitRecordMemberCount r
  BitRecordMemberCount 'EmptyBitRecord           = 0

-- | Return the size of the record.
getRecordSizeFromProxy
  :: forall px (rec :: BitRecord) . KnownNat (BitRecordSize rec) => px rec -> Integer
getRecordSizeFromProxy _ = natVal (Proxy :: Proxy (BitRecordSize rec))

-- | Either use the value from @Just@ or return a 'EmptyBitRecord' value(types(kinds))
type OptionalRecordOf f s =
  (Optional (Pure 'EmptyBitRecord) f $~ s :: IsA BitRecord)

-- TODO remove??

-- ** Record PrettyPrinting

-- | Augment the pretty printed output of a 'BitRecord'
data (prettyTitle :: PrettyType) #: (r :: IsA BitRecord) :: IsA BitRecord
infixr 4 #:
type instance Eval (prettyTitle #: r)  = ('BitRecordDoc prettyTitle) ':>: Eval r

-- | Augment the pretty printed output of a 'BitRecord'
data (prettyTitle :: PrettyType) #$ (r :: IsA BitRecord) :: IsA BitRecord
infixr 2 #$
type instance Eval (prettyTitle #$ r) = 'BitRecordDocNested prettyTitle (Eval r)

-- ** Record composition

-- | Combine two 'BitRecord's to form a new 'BitRecord'. If the parameters are
-- not of type 'BitRecord' they will be converted.
data (:>:) (l :: IsA BitRecord) (r :: IsA BitRecord) :: IsA BitRecord
type instance Eval (l :>: r) = Eval l ':>: Eval r

-- | Append a 'BitRecord' and a 'BitRecordField'
data (:>.) ::
  forall (t1 :: RecordFieldType rt1 st1 len1) .
   IsA BitRecord
  -> IsA (BitRecordField t1)
  -> IsA BitRecord
infixl 6 :>.
type instance Eval (l :>. r) = Eval l ':>: 'BitRecordMember (Eval r)

-- | Append a 'BitRecordField' and a 'BitRecord'
data (.>:) ::
  forall (t1 :: RecordFieldType rt1 st1 len1) .
     IsA (BitRecordField t1)
  -> IsA BitRecord
  -> IsA BitRecord
infixr 6 .>:
type instance Eval (l .>: r) = 'BitRecordMember (Eval l) ':>: Eval r

-- | Append a 'BitRecordField' and a 'BitRecordField' forming a 'BitRecord' with
-- two members.
data (.>.) ::
  forall (t1 :: RecordFieldType rt1 st1 len1)
     (t2 :: RecordFieldType rt2 st2 len2) .
     IsA (BitRecordField t1)
  -> IsA (BitRecordField t2)
  -> IsA BitRecord
infixr 6 .>.
type instance Eval (l .>. r) = 'BitRecordMember (Eval l) ':>: 'BitRecordMember (Eval r)

-- | Set a field to either a static, compile time, value or a dynamic, runtime value.
data (:~) :: forall (t :: RecordFieldType rt st len) .
    IsA (BitRecordField t)
  -> IsA (FieldValue st)
  -> IsA (BitRecordField t)
infixl 7 :~
type instance Eval (fld :~ StaticFieldValue v)  = Eval (fld := v)
type instance Eval (fld :~ RuntimeFieldValue l) = Eval (l   @: fld)

-- | Like ':~' but for a 'Maybe' parameter. In case of 'Just' it behaves like ':~'
-- in case of 'Nothing' it return an 'EmptyBitRecord'.
data (:~?) :: forall (t :: RecordFieldType rt st len) .
             IsA (BitRecordField t)
           -> Maybe (IsA (FieldValue st))
           -> IsA BitRecord
infixl 7 :~?
type instance Eval (fld :~? ('Just v)) = 'BitRecordMember (Eval (fld :~ v))
type instance Eval (fld :~? 'Nothing) = 'EmptyBitRecord

-- | The field value parameter for ':~', either a static, compile time, value or
-- a dynamic, runtime value.
data FieldValue staticRep
data StaticFieldValue  :: staticRep -> IsA (FieldValue staticRep)
data RuntimeFieldValue :: Symbol -> IsA (FieldValue staticRep)

-- *** Record Arrays and Repitition

-- | An array of records with a fixed number of elements, NOTE: this type is
-- actually not really necessary since 'ReplicateRecord' exists, but this allows
-- to have a different 'showRecord' output.
data RecArray :: IsA BitRecord -> Nat -> IsA BitRecord

type r ^^ n = RecArray r n
infixl 5 ^^

type instance Eval (RecArray (r :: IsA BitRecord) n ) = RecArrayToBitRecord (Eval r) n

-- | Repeat a bit record @n@ times.
type family RecArrayToBitRecord (r :: BitRecord) (n :: Nat) :: BitRecord where
  RecArrayToBitRecord r 0 = 'EmptyBitRecord
  RecArrayToBitRecord r 1 = r
  RecArrayToBitRecord r n = r ':>: RecArrayToBitRecord r (n - 1)

-- *** Lists of Records

-- | Let type level lists also be records
type family
    BitRecordOfList
      (f :: IsA ((foo :: Type) :-> IsA BitRecord))
      (xs :: [foo])
      :: IsA BitRecord
  where
    BitRecordOfList f xs = FoldMap (Fun2 (:>:)) (Pure 'EmptyBitRecord) f xs

-- *** Maybe Record

-- | Either use the value from @Just@ or return a 'EmptyBitRecord' value(types(kinds))
data OptionalRecord :: Maybe (IsA BitRecord) -> IsA BitRecord
type instance Eval (OptionalRecord ('Just t)) = Eval t
type instance Eval (OptionalRecord 'Nothing)  = 'EmptyBitRecord

-- ** Field ADT

-- | A family of bit fields.
--
-- A bit field always has a size, i.e. the number of bits it uses, as well as a
-- term level value type and a type level value type. It also has an optional
-- label, and an optional value assigned to it.
data BitRecordField (t :: RecordFieldType rt (st :: l) len) where
  -- | A field with a value set at compile time.
  AssignF :: value
          -> BitRecordField (t :: RecordFieldType rt value len)
          -> BitRecordField t
  -- | A bit record field with a number of bits
  MkField :: forall rt k (st :: k) (len :: Nat) (t :: RecordFieldType rt st len) . Proxy t -> BitRecordField t
  -- | A bit record field with a number of bits
  LabelF :: Symbol -> BitRecordField t -> BitRecordField t

-- | Types of this kind define the basic type of a 'BitRecordField'. Sure, this
-- could have been an open type, but really, how many actual useful field types
-- exist? Well, from a global perspective, uncountably infinite, but the focus
-- of this library is to blast out bits over the network, using usual Haskell
-- libraries, and hence, there is actually only very little reason to
-- differentiate types of record fields, other than what low-level library
-- function to apply and how to pretty print the field.
data RecordFieldType
     (runtimeRep :: Type)
     (staticRep :: k)
     (bitCount :: Nat)
  where
    MkFieldFlag :: RecordFieldType Bool Bool 1
    MkFieldBits :: forall (n :: Nat) . RecordFieldType Word64 Nat n
    MkFieldBitsXXL :: forall (n :: Nat) . RecordFieldType Integer Nat n
    -- TODO:
    -- MkFieldBits :: forall (n :: Nat) . n <= 64 => Proxy n -> RecordFieldType Word64 Nat n
    -- MkFieldBitsXXL :: forall (n :: Nat) . n <= 4294967295 => Proxy n -> RecordFieldType Integer Nat n
    MkFieldU8  :: RecordFieldType Word8 Nat 8
    MkFieldU16 :: RecordFieldType Word16 Nat 16
    MkFieldU32 :: RecordFieldType Word32 Nat 32
    MkFieldU64 :: RecordFieldType Word64 Nat 64
    MkFieldI8  :: RecordFieldType Int8  SignedNat 8
    MkFieldI16 :: RecordFieldType Int16 SignedNat 16
    MkFieldI32 :: RecordFieldType Int32 SignedNat 32
    MkFieldI64 :: RecordFieldType Int64 SignedNat 64
    MkFieldCustom :: Proxy t -> Proxy n -> RecordFieldType () t n
    -- TODO : MkFieldCustom :: forall (t :: Type) (n :: Nat) . n <= 4294967295  => RecordFieldType () t n

--type family UntaggedFieldType (bf

-- | A signed field value.
data SignedNat where
  PositiveNat :: Nat -> SignedNat
  NegativeNat :: Nat -> SignedNat

-- *** Primitive Records and Field Types

-- | A single bit (boolean) field
data Flag :: IsA (BitRecordField 'MkFieldFlag)
type instance Eval Flag = 'MkField ('Proxy :: Proxy  'MkFieldFlag)

-- | Define a field of bits with a size and 'Word64' as default demote rep.
data Field n :: IsA (BitRecordField ('MkFieldBits :: RecordFieldType Word64 Nat n))
type instance Eval (Field n) = 'MkField ('Proxy :: Proxy ('MkFieldBits :: RecordFieldType Word64 Nat n))

-- data FieldXXL n :: n <= 4294967295
--                 => IsA (BitRecordField ('MkFieldBitsXXL :: RecordFieldType Integer Nat n))

data FieldU8 :: IsA (BitRecordField 'MkFieldU8)
type instance Eval (FieldU8) = 'MkField ('Proxy :: Proxy  'MkFieldU8)

data FieldU16 :: IsA (BitRecordField 'MkFieldU16)
type instance Eval (FieldU16) = 'MkField ('Proxy :: Proxy  'MkFieldU16)

data FieldU32 :: IsA (BitRecordField 'MkFieldU32)
type instance Eval (FieldU32) = 'MkField ('Proxy :: Proxy  'MkFieldU32)

data FieldU64 :: IsA (BitRecordField 'MkFieldU64)
type instance Eval (FieldU64) = 'MkField ('Proxy :: Proxy  'MkFieldU64)

data FieldI8 :: IsA (BitRecordField 'MkFieldI8)
type instance Eval (FieldI8) = 'MkField ('Proxy :: Proxy  'MkFieldI8)

data FieldI16 :: IsA (BitRecordField 'MkFieldI16)
type instance Eval (FieldI16) = 'MkField ('Proxy :: Proxy  'MkFieldI16)

data FieldI32 :: IsA (BitRecordField 'MkFieldI32)
type instance Eval (FieldI32) = 'MkField ('Proxy :: Proxy  'MkFieldI32)

data FieldI64 :: IsA (BitRecordField 'MkFieldI64)
type instance Eval (FieldI64) = 'MkField ('Proxy :: Proxy  'MkFieldI64)

-- *** Composed Fields

-- | A Flag (1-bit) that is true if the type level maybe is 'Just'.
data FlagJust (a :: Maybe v) :: IsA (BitRecordField 'MkFieldFlag)
type instance Eval (FlagJust ('Just x)) = Eval (Flag := 'True)
type instance Eval (FlagJust 'Nothing)  = Eval (Flag := 'False)

-- | A Flag (1-bit) that is true if the type level maybe is 'Nothing'.
data FlagNothing (a :: Maybe v) :: IsA (BitRecordField 'MkFieldFlag)
type instance Eval (FlagNothing ('Just x)) = Eval (Flag := 'False)
type instance Eval (FlagNothing 'Nothing)  = Eval (Flag := 'True)

-- | A field that renders to the length of a 'SizedString' using the given
-- word type for the size.
data ToStringLength :: Type -> Type -> Type -- TODO move

-- | An optional field in a bit record
data MaybeField :: Maybe (IsA (BitRecordField t)) -> IsA BitRecord
type instance Eval (MaybeField ('Just  fld)) =
  'BitRecordDoc (PutStr "Just") ':>: 'BitRecordMember (Eval fld)
type instance Eval (MaybeField 'Nothing) =
  'BitRecordDoc (PutStr "Nothing")

-- | A 'BitRecordField' can be used as 'BitRecordMember'
data RecordField :: IsA (BitRecordField t) -> IsA BitRecord
type instance Eval (RecordField f) = 'BitRecordMember (Eval f)

-- | Calculate the size as a number of bits from a 'BitRecordField'
type family BitRecordFieldSize (x :: BitRecordField t) where
  BitRecordFieldSize (x :: BitRecordField (t :: RecordFieldType rt st size)) = size

-- *** Field Constructor

-- **** Setting a Label

-- | A field with a label assigned to it.
data (@:) :: Symbol -> IsA (BitRecordField t) -> IsA (BitRecordField t)
infixr 8 @:
type instance Eval (l @: f) = 'LabelF l (Eval f)

-- **** Assignment

-- | A field with a (type-level-) value assigned to.
data (:=) :: IsA (BitRecordField t) -> st -> IsA (BitRecordField t)
infixl 7 :=

type instance Eval ((b :: IsA (BitRecordField t)) := (v :: k))
  = AssignFChecked (Eval b) v

type family AssignFChecked (b :: BitRecordField (t :: RecordFieldType (rt :: Type) (st :: Type) (s :: Nat))) (v :: st) :: BitRecordField t where
  AssignFChecked ('MkField ('Proxy :: Proxy t) :: BitRecordField t) (v :: st) =
    'AssignF v ('MkField ('Proxy :: Proxy t) :: BitRecordField t)
  AssignFChecked o v = TypeError ('Text "Cannot assign (type-level-) value "
                         ':<>: 'ShowType v
                         ':<>: 'Text " to field, that is already assigned: "
                         ':<>: 'ShowType o)

-- ** Auto-Padding

type Align padRight a f =
    AddPadding padRight ((a - (BitRecordSize f `Rem` a)) `Rem` a) f

type family
  AddPadding (padRight :: Bool) (n :: Nat) (r :: BitRecord) :: BitRecord where
  AddPadding padRight 0 r = r
  AddPadding 'True n r  =
    r ':>:
    'BitRecordMember
       ('AssignF 0 ('MkField
                    ('Proxy :: Proxy
                              ('MkFieldBits :: RecordFieldType Word64 Nat n))))

  AddPadding 'False n r =
    'BitRecordMember
    ('AssignF 0 ('MkField
                  ('Proxy :: Proxy
                            ('MkFieldBits :: RecordFieldType Word64 Nat n))))
    ':>: r

-- * Field and Record PrettyType Instances

-- | Render @rec@ to a pretty, human readable form. Internally this is a wrapper
-- around 'ptShow' using 'PrettyRecord'.
showRecord
  :: forall proxy (rec :: BitRecord) . PrettyTypeShow (PrettyRecord rec)
  => proxy rec -> String
showRecord _ = showPretty (Proxy :: Proxy (PrettyRecord rec))

type instance ToPretty (rec :: BitRecord) = PrettyRecord rec

type family PrettyRecord (rec :: BitRecord) :: PrettyType where
   PrettyRecord ('BitRecordMember m) = PrettyField m
   PrettyRecord ' EmptyBitRecord = 'PrettyNewline
   PrettyRecord (l ':>: r) = PrettyRecord l <$$> PrettyRecord r
   PrettyRecord ('BitRecordDoc p) = p
   PrettyRecord ('BitRecordDocNested p r) = p <$$--> PrettyRecord r

type instance ToPretty (f :: BitRecordField t) = PrettyField f

type family PrettyField (f :: BitRecordField (t :: RecordFieldType (rt :: Type) (st :: Type) (size :: Nat))) :: PrettyType where
  PrettyField ('MkField ('Proxy :: Proxy t)) = PrettyFieldType t
  PrettyField ('AssignF v (f :: BitRecordField (t :: RecordFieldType rt st size))) =
    PrettyField f <+> PutStr ":=" <+> PrettyFieldValue t v
  PrettyField ('LabelF l f) = l <:> PrettyField f

type family PrettyFieldType (t :: RecordFieldType (rt :: Type) (st :: Type) (size :: Nat)) :: PrettyType where
  PrettyFieldType ('MkFieldFlag) = PutStr "boolean"
  PrettyFieldType ('MkFieldBits :: RecordFieldType Word64 Nat (s :: Nat)) = PutStr "bits" <++> PrettyParens (PutNat s)
  PrettyFieldType ('MkFieldBitsXXL :: RecordFieldType Integer Nat (s :: Nat)) = PutStr "bits-XXL" <++> PrettyParens (PutNat s)
  PrettyFieldType ('MkFieldU64) = PutStr "U64"
  PrettyFieldType ('MkFieldU32) = PutStr "U32"
  PrettyFieldType ('MkFieldU16) = PutStr "U16"
  PrettyFieldType ('MkFieldU8) = PutStr "U8"
  PrettyFieldType ('MkFieldI64) = PutStr "I64"
  PrettyFieldType ('MkFieldI32) = PutStr "I32"
  PrettyFieldType ('MkFieldI16) = PutStr "I16"
  PrettyFieldType ('MkFieldI8) = PutStr "I8"
  PrettyFieldType ('MkFieldCustom ('Proxy :: Proxy ct) ('Proxy :: Proxy size)) = PutStr "custom" <++> PrettyParens (PutNat size) <+> ToPretty ct

type family PrettyFieldValue (t :: RecordFieldType (rt :: Type) (st :: Type) (size :: Nat)) (v :: st) :: PrettyType where
  PrettyFieldValue ('MkFieldFlag) 'True = PutStr "yes"
  PrettyFieldValue ('MkFieldFlag) 'False = PutStr "no"
  PrettyFieldValue ('MkFieldBits :: RecordFieldType Word64 Nat (s::Nat)) v =
    'PrettyNat 'PrettyUnpadded ('PrettyPrecision s) 'PrettyBit v  <+> PrettyParens (("hex" <:> PutHex v) <+> ("dec" <:> PutNat v))
  PrettyFieldValue ('MkFieldU8)  v = ("hex" <:> PutHex8 v) <+> PrettyParens ("dec" <:> PutNat v)
  PrettyFieldValue ('MkFieldU16) v = ("hex" <:> PutHex16 v) <+> PrettyParens ("dec" <:> PutNat v)
  PrettyFieldValue ('MkFieldU32) v = ("hex" <:> PutHex32 v) <+> PrettyParens ("dec" <:> PutNat v)
  PrettyFieldValue ('MkFieldU64) v = ("hex" <:> PutHex64 v) <+> PrettyParens ("dec" <:> PutNat v)
  PrettyFieldValue ('MkFieldI8)  ('PositiveNat v) = ("hex" <:> (PutStr "+" <++> PutHex8 v)) <+> PrettyParens ("dec"  <:> (PutStr "+" <++> PutNat v))
  PrettyFieldValue ('MkFieldI16) ('PositiveNat v) = ("hex" <:> (PutStr "+" <++> PutHex16 v)) <+> PrettyParens ("dec" <:> (PutStr "+" <++> PutNat v))
  PrettyFieldValue ('MkFieldI32) ('PositiveNat v) = ("hex" <:> (PutStr "+" <++> PutHex32 v)) <+> PrettyParens ("dec" <:> (PutStr "+" <++> PutNat v))
  PrettyFieldValue ('MkFieldI64) ('PositiveNat v) = ("hex" <:> (PutStr "+" <++> PutHex64 v)) <+> PrettyParens ("dec" <:> (PutStr "+" <++> PutNat v))
  PrettyFieldValue ('MkFieldI8)  ('NegativeNat v) = ("hex" <:> (PutStr "-" <++> PutHex8 v)) <+> PrettyParens ("dec"  <:> (PutStr "-" <++> PutNat v))
  PrettyFieldValue ('MkFieldI16) ('NegativeNat v) = ("hex" <:> (PutStr "-" <++> PutHex16 v)) <+> PrettyParens ("dec" <:> (PutStr "-" <++> PutNat v))
  PrettyFieldValue ('MkFieldI32) ('NegativeNat v) = ("hex" <:> (PutStr "-" <++> PutHex32 v)) <+> PrettyParens ("dec" <:> (PutStr "-" <++> PutNat v))
  PrettyFieldValue ('MkFieldI64) ('NegativeNat v) = ("hex" <:> (PutStr "-" <++> PutHex64 v)) <+> PrettyParens ("dec" <:> (PutStr "-" <++> PutNat v))
  PrettyFieldValue t v = ToPretty v


-- * Constraint Utilities

-- | A wrapper around 'Constraint' that propagates 'TypeError'.
type ConstraintE = Either Constraint Constraint

-- | Unwrap a 'ConstraintE', this is where 'TypeError's might be /thrown/.
type family
  RunConstraintE t :: Constraint where
  RunConstraintE ('Left t) = t
  RunConstraintE ('Right t) = t











-- -- | A setter for 'f', that assigns a value.
-- --
-- -- An alias for 'SetWith' using the 'StdSetter' 'Assign'.
-- type SetTo f v = SetWith f (OverwriteWith v)

-- -- | Alternative version of 'SetTo'
-- type SetToAlt f v = SetWith f (AltSetter (OverwriteWith v))

-- -- | A setter for 'f', that creates a named parameter for runtime
-- -- values to set the field.
-- --
-- -- An alias for 'SetWith' using the 'StdSetter' 'Assign'.
-- type Defer label f = SetWith f (NamedRuntimeParameter label)

-- -- | Alternative version of 'Defer'
-- type DeferAlt label f = SetWith f (AltSetter (NamedRuntimeParameter label))

-- -- | Set something to a value in a specific way.
-- --
-- -- The way how a field is assigned to a value is controlled through the 'Eval'
-- -- instances, that can vary depending on @f@ and @setter v@.
-- data SetWith :: IsAn f -> IsA Setter -> IsAn f

-- -- | Abstract kind of 'SetWith' setter parameter
-- data Setter

-- -- | Assign to a value known at compile-time.
-- data OverwriteWith v :: IsA Setter

-- -- | Assign a value obtained from a named parameter, e.g. with a value
-- -- obtained at runtime.
-- data NamedRuntimeParameter :: Symbol -> IsA Setter

-- -- | Assign a value obtained from a named parameter, e.g. with a value
-- -- obtained at runtime.
-- data AltSetter :: IsA Setter -> IsA Setter
