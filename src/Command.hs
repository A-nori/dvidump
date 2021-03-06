module Command (
  Command(..),
  convert
  ) where

import qualified Data.ByteString as B
import Data.Word
import Data.Bits

data Command =
    Set_Char Word8
  | Set Word8 Int
  | Set_Rule Int Int
  | Put Word8 Int
  | Put_Rule Int Int
  | Nop
  | Bop [Int] Int
  | Eop
  | Push
  | Pop
  | Right Word8 Int
  | W0
  | W Word8 Int
  | X0
  | X Word8 Int
  | Down Word8 Int
  | Y0
  | Y Word8 Int
  | Z0
  | Z Word8 Int
  | Fnt_Num Word8
  | Fnt Word8 Int
  | Xxx Word8 Int String
  | Fnt_Def Word8 Int Int Int Int Int Int String
  | Pre Int Int Int Int Int String
  | Post Int Int Int Int Int Int Int Int 
  | Post_Post Int Word8
  | Undifined
  deriving Show

-- convert Word8 to Int
toInt :: Integral a => a -> Int
toInt = fromInteger . toInteger

-- convert 4 Word8s to Int
fourbytes_to_Int :: Word8 -> Word8 -> Word8 -> Word8 -> Int
fourbytes_to_Int a b c d =
  shiftL (toInt a) 24 + shiftL (toInt b) 16 + shiftL (toInt c) 8 + toInt d

-- fetch n (<= 4) bytes and convert them to singed Int
fetch_signed :: Word8 -> [Word8] -> (Int, [Word8])
fetch_signed 0 xs = (0, xs)
fetch_signed 1 (x:xs) = 
  let 
    ret =
      if x <= 127 then
        fourbytes_to_Int 0 0 0 x
      else
        fourbytes_to_Int 0 0 0 (x - 128) - 2^7
  in
    (ret, xs)
fetch_signed 2 (x1:x2:xs) =
  let 
    ret =
      if x1 <= 127 then
        fourbytes_to_Int 0 0 x1 x2
      else
        fourbytes_to_Int 0 0 (x1 - 128) x2 - 2^15
  in
    (ret, xs)
fetch_signed 3 (x1:x2:x3:xs) = 
  let 
    ret =
      if x1 <= 127 then
        fourbytes_to_Int 0 x1 x2 x3
      else
        fourbytes_to_Int 0 (x1 - 128) x2 x3 - 2^23
  in
    (ret, xs)
fetch_signed 4 (x1:x2:x3:x4:xs) = 
  let 
    ret =
      if x1 <= 127 then
        fourbytes_to_Int x1 x2 x3 x4
      else
        fourbytes_to_Int (x1 - 128) x2 x3 x4 - 2^31
  in
    (ret, xs)

-- fetch n (<= 4) bytes and convert them to unsinged Int
fetch_unsigned :: Word8 -> [Word8] -> (Int, [Word8])
fetch_unsigned 0 xs = (0, xs)
fetch_unsigned 1 (x:xs) = (toInt x, xs)
fetch_unsigned 2 (x1:x2:xs) = (fourbytes_to_Int 0 0 x1 x2, xs)
fetch_unsigned 3 (x1:x2:x3:xs) = (fourbytes_to_Int 0 x1 x2 x3, xs)
fetch_unsigned 4 xs = fetch_signed 4 xs -- 4$B$N;~$O(Bsigned

-- fetch 4n bytes and convert them to [Int]
fetch_4nbytes_to_Int :: Int -> [Word8] -> ([Int], [Word8])
fetch_4nbytes_to_Int 0 xs = ([], xs)
fetch_4nbytes_to_Int n (x1:x2:x3:x4:xs) =
  let 
    (l, ret) = fetch_4nbytes_to_Int (n - 1) xs
  in
    (fst (fetch_signed 4 [x1, x2, x3, x4]) : l, ret)

-- fetch n bytes and vovert them to String
fetch_nbytes_to_String :: Int -> [Word8] -> (String, [Word8])
fetch_nbytes_to_String 0 xs = ("", xs)
fetch_nbytes_to_String n (x:xs) =
  let
    (l, ret) = fetch_nbytes_to_String (n - 1) xs
  in
    ((toEnum $ fromEnum x) : l, ret)
fetch_nbytes_to_String n [] = error "hoge"



devour_df :: [Word8] -> ()
devour_df (223:xs) = devour_df xs
devour_df [] = ()
  

-- convert [Word8] to [Command]
-- tail recursion
convert_sub [] l = reverse l
convert_sub (x : xs) l
  |  0 <= x && x <= 127 = -- set_char
    let currcom = Set_Char x
    in convert_sub xs (currcom : l)
  |  x <= 131 = -- set
    let 
      n = x - 127
      (c, xs') = fetch_unsigned n xs
      currcom = Set n c
    in
      convert_sub xs' (currcom : l)
  | x == 132 = -- set_rule
    let
      ([a, b], xs') = fetch_4nbytes_to_Int 2 xs
      currcom = Set_Rule a b
    in
      convert_sub xs' (currcom : l)
  | x <= 136 = -- put
    let 
      n = x - 132
      (c, xs') = fetch_unsigned  n xs
      currcom = Put n c
    in
      convert_sub xs' (currcom : l)
  | x == 137 = -- put_rule
    let
      ([a, b], xs') = fetch_4nbytes_to_Int 2 xs
      currcom = Put_Rule a b
    in
      convert_sub xs' (currcom : l)
  | x == 138 = -- nop
    convert_sub xs (Nop : l)
  | x == 139 = -- bop
    let
      (params, xs') = fetch_4nbytes_to_Int 11 xs
      cs = init params
      p = last params
      currcom = Bop cs p
    in
      convert_sub xs' (currcom : l)
  | x == 140 = -- eop
    convert_sub xs (Eop : l)
  | x == 141 = -- push
    convert_sub xs (Push : l)
  | x == 142 = -- pop
    convert_sub xs (Pop : l)
  | x <= 146 = -- right 
    let 
      n = x - 142
      (c, xs') = fetch_signed n xs
      currcom = Command.Right n c
    in
      convert_sub xs' (currcom : l)
  | x == 147 = -- w0
    convert_sub xs (W0 : l)
  | x <= 151 = -- w
    let 
      n = x - 147
      (c, xs') = fetch_signed n xs
      currcom = W n c
    in
      convert_sub xs' (currcom : l)
  | x == 152 = -- x0
    convert_sub xs (X0 : l)
  | x <= 156 = -- x
    let 
      n = x - 152
      (c, xs') = fetch_signed n xs
      currcom = X n c
    in
      convert_sub xs' (currcom : l)
  | x <= 160 = -- down
    let 
      n = x - 156
      (c, xs') = fetch_signed n xs
      currcom = Down n c
    in
      convert_sub xs' (currcom : l)
  | x == 161 = -- y0
    convert_sub xs (Y0 : l)
  | x <= 165 = -- y
    let 
      n = x - 161
      (c, xs') = fetch_signed n xs
      currcom = Y n c
    in
      convert_sub xs' (currcom : l)
  | x == 166 = -- z0
    convert_sub xs (Z0 : l)
  | x <= 170 = -- z
    let 
      n = x - 166
      (c, xs') = fetch_signed n xs
      currcom = Z n c
    in
      convert_sub xs' (currcom : l)
  | x <= 234 = -- fnt_num
    convert_sub xs (Fnt_Num (x - 171) : l)
  | x <= 238 = -- fnt
    let 
      n = x - 234
      (c, xs') = fetch_unsigned n xs
      currcom = Fnt n c
    in
      convert_sub xs' (currcom : l)
  | x <= 242 = -- xxx
    let 
      n = x - 238
      (k, xs') = fetch_unsigned n xs
      (str, xs'') = fetch_nbytes_to_String k xs'
      currcom = Xxx n k str
    in
      convert_sub xs'' (currcom : l)
  | x <= 246 = -- fnt_def
    let
      i = x - 242
      (k, xs') = fetch_unsigned i xs
      ([c, s, d], xs'') = fetch_4nbytes_to_Int 3 xs'
      (a, xs''') = fetch_unsigned 1 xs''
      (m, xs'''') = fetch_unsigned 1 xs'''
      (n, xs''''') = fetch_nbytes_to_String (a + m) xs''''
      currcom = Fnt_Def i k c s d a m n
    in
      convert_sub xs''''' (currcom : l)
  | x == 247 = -- pre
    let 
      (i, xs') = fetch_unsigned 1 xs
      ([num, den, mag], xs'') = fetch_4nbytes_to_Int 3 xs'
      (k, xs''') = fetch_unsigned 1 xs''
      (x, xs'''') = fetch_nbytes_to_String k xs'''
      currcom = Pre i num den mag k x
    in
      convert_sub xs'''' (currcom : l)
  | x == 248 = -- post
    let 
      ([p, num, den, mag, l', u], xs') = fetch_4nbytes_to_Int 6 xs
      (s, xs'') = fetch_unsigned 2 xs'
      (t, xs''') = fetch_unsigned 2 xs''
      currcom = Post p num den mag l' u s t
    in
      convert_sub xs''' (currcom : l)
  | x == 249 = -- post_post
    let 
      (q, xs') = fetch_unsigned 4 xs
      (i, xs'') = fetch_unsigned 1 xs'
      _ = devour_df xs''
      currcom = Post_Post q (fromInteger $ toInteger i)
    in
      convert_sub [] (currcom : l)
         
  | otherwise =
    convert_sub [] l

convert :: [Word8] -> [Command]
convert l = convert_sub l []


