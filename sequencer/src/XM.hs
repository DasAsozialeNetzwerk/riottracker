module Main where

import qualified Data.ByteString.Lazy     as BL
import qualified Codec.Tracker.XM         as XM
import qualified Codec.Tracker.XM.Header  as XM
import qualified Codec.Tracker.XM.Pattern as XM
--import           Control.Monad.Loops
import qualified Sound.RtMidi as Rt
import           Data.Binary.Get
import           Data.Maybe
import           Data.Char
import           Data.List
import           Data.List.Split
import           Graphics.Vty

import           App
import           Images
import           Editor

import Sequencer
import Control.Monad.IO.Class (liftIO, )
import Control.Monad
import Control.Concurrent
import Control.Concurrent.STM
import Debug.Trace

n2pitch :: Int -> Maybe Pitch
n2pitch 97 = Nothing
n2pitch n  = Just (Pitch ((cycle notes) !! (n - 1)) (div n 12))
  where notes = [Cn, C', Dn, D', En, Fn, F', Gn, G', An, A', Bn]

cell2cell :: XM.Cell -> Cell
cell2cell (XM.Cell n i v et ep) = Cell (fromIntegral <$> n >>= n2pitch) (fromIntegral <$> i) (fromIntegral <$> v) (fromIntegral <$> et) (fromIntegral <$> ep)

main = do
    fl <- BL.readFile "test.xm"
    device <- Rt.defaultOutput
    numPorts <- Rt.portCount device
    ports <- mapM (Rt.portName device) [0..numPorts-1]
    mapM_ (\t -> putStrLn $ show t) $ zip [0..] ports
    putStrLn "select port: "
    selection <- getLine
    Rt.openPort device (read selection) "riottracker"
    config <- standardIOConfig
    vty <- mkVty config
    withApp vty device (toSong $ runGet XM.getModule fl) run

checkA :: App -> IO Bool
checkA a = do x <- readTVarIO (editor a)
              return $ quitEditor x

run app = do
  renderThread <- forkIO $ forever $ render app
  let k = do handleEvents app 
             e <- readTVarIO (editor app)
             if quitEditor e then return () else k
  k

toSong :: XM.Module -> Song
toSong mod = Song $ transpose rows
  where rows  = chunksOf (fromIntegral . XM.numChannels . XM.header $ mod) cells
        cells = map cell2cell $ concat $ map XM.patternData $ XM.patterns mod

