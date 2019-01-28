{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE TypeFamilies #-}

module Main where

import Diagrams.Prelude
import Diagrams.Backend.Cairo
import Diagrams.TwoD.Arc
import Linear.V2

import Data.Random
import Data.Random.Distribution.Bernoulli
import Data.Random.Source.StdGen
import Data.Time.Clock.POSIX

import Data.Maybe

import Control.Monad.State

data Brush a = Arc a
             | None a

main :: IO ()
main = do
  seed <- round . (*1000) <$> getPOSIXTime
  let src = mkStdGen seed

  let arcs' = fmap (\(dir, sweep) -> arc (angleDir dir) sweep)
                   . fmap (\(dir, sweep) -> (dir @@ deg, sweep @@deg))
                   . catMaybes
                   . flip evalState []
                   . mapM nom
                   . flip evalState (src, None 0.0)
                   . mapM assignPoint
                   $ [0, 0.5 .. 360]
  let diagram = foldr atop mempty arcs'

  renderCairo "./out.png" (dims $ V2 300 300) $ diagram # bgFrame 1 white

nom :: Brush Double -> State [Double] (Maybe (Double, Double))
nom (None _) = do
  workingArc <- get
  put []
  if (length workingArc < 2)
     then do
       return Nothing
     else do
       let direction = head workingArc
       let end = last workingArc
       let sweep = end - direction
       return $ Just (direction, sweep)
nom (Arc d) = do
  workingArc <- get
  put $ workingArc ++ [d]
  return Nothing

assignPoint :: Double -> State (StdGen, (Brush Double)) (Brush Double)
assignPoint d = do
  (src, prev) <- get
  let p = case prev of
            (None _) -> 0.40::Double
            (Arc _)  -> 0.88
  let (coin, src') = flip runState src $ runRVar (boolBernoulli p) StdRandom
  let brush = case coin of
                True -> Arc d
                False -> None d
  put (src', brush)
  return brush

-- Get the points of a circle's perimeter
-- at every point, flip a koin to decide if we connect the next point into an arc
-- when in connecting point state, then it's biased to stay that way and vice versa
--  (monad?)
-- do this multiple times with circles whose origins drift along a path (start with diagonal)
--
-- State s <thing I need that is obtained using s>
-- one function will be the mega computation
-- it will call other functions I had
