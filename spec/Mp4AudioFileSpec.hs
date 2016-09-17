{-# LANGUAGE OverloadedStrings #-}
module Mp4AudioFileSpec (spec) where -- TODO rename to mp4 audio init spec

import Test.Hspec
import Data.ByteString.Mp4.Boxes.BaseDescriptor
import Data.ByteString.Mp4.Boxes.AudioSpecificConfig
import Data.ByteString.Mp4.Boxes.Mp4AudioSampleEntry
import Data.ByteString.Mp4.AudioFile
import Data.ByteString.IsoBaseFileFormat.ReExports
import Data.ByteString.IsoBaseFileFormat.Util.BoxFields
import Data.ByteString.IsoBaseFileFormat.Util.Time
import qualified Data.ByteString.Lazy as BL
import Data.Text ()

spec :: Spec
spec =
  do describe "Mp4AacAudioDecoderConfigDescriptor" $ do
       it "can be pretty printed" $
         showRecord (Proxy @(BitRecordOfDescriptor
                              $~ (Eval (Mp4AacAudioDecoderConfigDescriptor
                                        (AudioConfigAacLc
                                         (EnumParam "samplingFreq" SamplingFreq)
                                          (EnumParam "channelConfig" ChannelConfig))))))
         `shouldEndWith`
         "has-gas-extension: boolean := no"

       it "can be transformed to binary output" $
         let actual =
              bitStringPrinter
                (Proxy @(BitRecordOfDescriptor
                               $~ Eval  (Mp4AacAudioDecoderConfigDescriptor
                                         (AudioConfigAacLc
                                          (EnumParam "samplingFreq" SamplingFreq)
                                           (EnumParam "channelConfig" ChannelConfig)))))
                True
                1
                2
                3
                (MkEnumValue (Proxy @'SF16000))
                (MkEnumValue (Proxy @'SingleChannel))
             expexted = "<< 04 11 40 17 00 00 01 00 00 00 02 00 00 00 03 05 02 14 10 >>"
         in actual `shouldBe` expexted
     describe "Mp4AacLcEsDescriptor" $
       do it "can be transformed to binary output" $
            bitStringPrinter (Proxy @(BitRecordOfDescriptor $~ Eval Mp4AacLcEsDescriptor))
                             False 0 0 0
                             (MkEnumValue (Proxy @'SF48000))
                             (MkEnumValue (Proxy @'SingleChannel))
            `shouldBe`
              "<< 03 19 00 01 00 04 11 40 15 00 00 00 00 00 00 00 00 00 00 00 05 02 11 90 06 01 02 >>"
          it "can be pretty printed" $
            showRecord (Proxy @(BitRecordOfDescriptor $~ Eval Mp4AacLcEsDescriptor))
            `shouldStartWith` "base-descriptor: 03\n"
     describe "Mp4HeAacEsDescriptor" $
       do it "can be transformed to binary output" $
            bitStringPrinter (Proxy @(BitRecordOfDescriptor $~ Eval Mp4HeAacEsDescriptor))
                             False 0 0 0
                             (MkEnumValue (Proxy @'SF48000))
                             (MkEnumValue (Proxy @'SingleChannel))
                             (MkEnumValue (Proxy @'SF24000))
            `shouldBe`
              "<< 03 1a 00 01 00 04 12 40 15 00 00 00 00 00 00 00 00 00 00 00 05 03 29 93 08 03 00 81 00 >>"
          it "can be pretty printed" $
            showRecord (Proxy @(BitRecordOfDescriptor $~ Eval Mp4HeAacEsDescriptor))
            `shouldStartWith` "base-descriptor: 03\n"
     describe "SingleAudioTrackInit version 0" $
       do it "renders some output at all" $
            do creationTime <- mp4CurrentTime
               let ct :: Word32
                   ct = fromScalar creationTime
                   ct3 = (ct `shiftR` 24) .&. 255
                   ct2 = (ct `shiftR` 16) .&. 255
                   ct1 = (ct `shiftR` 8) .&. 255
                   ct0 = (ct `shiftR` 0) .&. 255
                   cts :: [Word8]
                   cts = fromIntegral <$> [ct3,ct2,ct1,ct0]
               let args = exampleSingleTrackInit creationTime
                   doc = buildAacMp4StreamInit args
                   rendered = BL.unpack $ toLazyByteString $ doc
                   expected =
                     [
                      -- ftyp box
                       0,0,0,32
                     ,102,116,121,112
                     ,105,115,111,53,0,0,0,0
                     ,105,115,111,109
                     ,105,115,111,53
                     ,100,97,115,104
                     ,109,112,52,50

                     -- moov box
                     ,0,0,2,57,109 ,111 ,111 ,118
                      -- mvhd box
                     ,0 ,0 ,0 ,108 ,109 ,118 ,104 ,100 ,0 ,0 ,0 ,0]
                      ++ cts ++ [0 ,0 ,0 ,0 ,0
                     ,1 ,95 ,144 ,0 ,1 ,95 ,144 ,0 ,1 ,0 ,0 ,1 ,0 ,0 ,0
                     ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,1 ,0 ,0 ,0 ,0 ,0 ,0
                     ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,1 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0
                     ,0 ,0 ,0 ,0 ,0 ,0 ,64 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0
                     ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0
                     ,255 ,255 ,255 ,255
                     -- trak box
                     ,0 ,0 ,1,157
                     ,116 ,114 ,97 ,107
                     -- tkhd box
                     ,0 ,0 ,0 ,92
                     ,116 ,107 ,104 ,100
                     ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0
                     ,0 ,1 ,0 ,0 ,0 ,0 ,0 ,1 ,95 ,144 ,0 ,0
                     ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,1 ,0 ,0 ,0
                     ,0 ,1 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0
                     ,0 ,1 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0
                     ,0 ,64 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0
                     -- mdia box
                     ,0,0,1,57
                     ,109,100,105,97
                     -- mdhd box
                     ,0,0,0,32
                     ,109,100,104,100,0,0,0,0,0,0,0,0,0,0,0,0,0
                     ,1,95,144,0,0,0,0,16,181,0,0
                     -- hdlr box
                     ,0,0,0,44
                     ,104,100,108,114
                     ,0,0,0,0,0,0,0,0,115,111,117,110,0,0,0,0,0,0,0,0,0,0,0,0
                     ,72,101,108,108,111,32,119,111,114,108,100,0
                     -- minf box
                     ,0,0,0,229
                     ,109,105,110,102
                     -- smhd box
                     ,0,0,0,16
                     ,115,109,104,100,0,0,0,0,0,0,0,0
                     -- dinf boimport Data.ByteString.IsoBaseFileFormat.Boxes
                     ,0,0,0,36
                     ,100,105,110,102
                     -- dref box
                     ,0,0,0,28
                     ,100,114,101,102
                     ,0,0,0,0,0,0,0,1
                     -- url  box
                     ,0,0,0,12
                     ,117,114,108,32
                     ,0,0,0,1
                     -- stbl box
                     ,0,0,0,169
                     ,115,116,98,108
                     -- stsd box
                     ,0,0,0,93
                     ,115,116,115,100
                     ,0,0,0,0,0,0,0,1
                     -- mp4a box
                     ,0,0,0,77
                     ,109,112,52,97
                     ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,16,0,0,0,0,187,128,0,0
                     -- esds box
                     ,0,0,0,41
                     ,101,115,100,115
                     ,0,0,0,0,3,26,0,1,0,4,18,64,21
                     ,0,0,0,0,0,0,0,0,0,0,0,5,3,41,145,136,3,0,129,0
                     -- stts box
                     ,0,0,0,16
                     ,115,116,116,115,0,0,0,0,0,0,0,0
                     -- stsc box
                     ,0,0,0,16
                     ,115,116,115,99,0,0,0,0,0,0,0,0
                     -- stc0 box
                     ,0,0,0,16
                     ,115,116,99,111,0,0,0,0,0,0,0,0
                     -- stsz box
                     ,0,0,0,20
                     ,115,116,115,122,0,0,0,0,0,0,0,0,0,0,0,0
                     -- mvex box
                     ,0,0,0,40
                     ,109,118,101,120
                     -- trex box
                     ,0,0,0,32
                     ,116,114,101,120,0,0,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0]

               BL.writeFile "/tmp/isobmff-test-case-dash-spec.mp4" (BL.pack rendered)
               rendered `shouldBe`
                 expected

exampleSingleTrackInit :: U32 "creation_time" -> AacMp4StreamConfig
exampleSingleTrackInit creationTime =
  AacMp4StreamConfig creationTime "Hello world" 1 True SF48000 SingleChannel
