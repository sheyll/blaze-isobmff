module BoxSpec (spec) where

import Test.Hspec
import Data.ByteString.IsoBaseFileFormat.Builder
import qualified Data.ByteString.Builder as B
import qualified Data.ByteString.Lazy as BL
import qualified Data.Binary.Get as Binary

spec :: Spec
spec =
  do describe "IsBoxContent instances" $
       do describe "()" $
            do describe "boxSize" $ it "returns 0" $ boxSize () `shouldBe` 0
               describe "boxBuilder" $
                 it "emits no data" $
                 BL.length (B.toLazyByteString (boxBuilder ())) `shouldBe` 0
          describe "Box" $
            do describe "boxSize" $
                 it "returns the header size if the content is empty" $
                 boxSize testBox1 `shouldBe` (4 + 4)
          describe "Boxes" $
            do describe "boxSize" $
                 do describe "a box with one nested box" $
                      do it "returns the sum of both boxSizes" $
                           boxSize (testParentBox1 ^- Nested testBox1) `shouldBe`
                           (boxSize (toBox testParentBox1) + boxSize testBox1)
                         it "returns the same value as written by boxBuilder" $
                           let b = testParentBox1 ^- Nested testBox1
                               writtenSize =
                                 let out = toLazyByteString (boxBuilder b)
                                     getSize = Binary.runGet Binary.getWord32be
                                 in BoxSize $ fromIntegral $ getSize out
                               reportedSize = boxSize b
                           in writtenSize `shouldBe` reportedSize

toBox :: IsBoxType t
      => ParentBox t -> Box t
toBox (ParentBox t c) = Box t c

type TestBox1 = Box "box1"

testBox1 :: TestBox1
testBox1 = emptyBox

instance BoxRules "box1" where
  type RestrictedTo "box1" = 'Nothing

type TestParentBox1 = ParentBox "par1"

testParentBox1 :: TestParentBox1
testParentBox1 = emptyParentBox

instance BoxRules "par1" where
  type RestrictedTo "par1" = 'Nothing