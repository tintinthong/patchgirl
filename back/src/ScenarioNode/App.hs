{-# LANGUAGE FlexibleContexts #-}

module ScenarioNode.App where

import           Control.Lens.Operators ((^.))
import qualified Control.Monad          as Monad
import qualified Control.Monad.Except   as Except (MonadError)
import qualified Control.Monad.IO.Class as IO
import qualified Control.Monad.Loops    as Loops
import qualified Control.Monad.Reader   as Reader
import           Data.Functor           ((<&>))
import qualified Data.Maybe             as Maybe
import           Data.UUID
import qualified Servant

import           DB
import           PatchGirl
import           ScenarioCollection.Sql
import           ScenarioNode.Model
import           ScenarioNode.Sql


-- * update scenario node


updateScenarioNodeHandler
  :: ( Reader.MonadReader Config m
     , IO.MonadIO m
     , Except.MonadError Servant.ServerError m
     )
  => UUID
  -> UUID
  -> UUID
  -> UpdateScenarioNode
  -> m ()
updateScenarioNodeHandler accountId scenarioCollectionId scenarioNodeId updateScenarioNode = do
  connection <- getDBConnection
  let scenarioCollectionAuthorized = doesScenarioCollectionBelongsToAccount accountId scenarioCollectionId connection
  let scenarioNodeAuthorized =
        selectScenarioNodesFromScenarioCollectionId scenarioCollectionId connection <&>
        (Maybe.isJust . (findNodeInScenarioNodes scenarioNodeId))

  authorized <- IO.liftIO $ Loops.andM [ scenarioCollectionAuthorized, scenarioNodeAuthorized ]
  case authorized of
    False ->
      Servant.throwError Servant.err404
    True -> do
      IO.liftIO $ print "test2"
      IO.liftIO $
        Monad.void (updateScenarioNodeDB scenarioNodeId updateScenarioNode connection)


-- * delete scenario node

{-
deleteScenarioNodeHandler
  :: ( Reader.MonadReader Config m
     , IO.MonadIO m
     , Except.MonadError Servant.ServerError m
     )
  => UUID
  -> Int
  -> UUID
  -> m ()
deleteScenarioNodeHandler accountId requestCollectionId requestNodeId = do
  undefined
  {

  connection <- getDBConnection
  IO.liftIO (selectRequestCollectionId accountId connection) >>= \case
    Nothing ->
      Servant.throwError Servant.err404
    Just requestCollectionId' | requestCollectionId /= requestCollectionId' ->
      Servant.throwError Servant.err404
    _ -> do
      requestNodes <- IO.liftIO $ selectRequestNodesFromRequestCollectionId requestCollectionId connection
      case findNodeInRequestNodes requestNodeId requestNodes of
        Nothing ->
          Servant.throwError Servant.err404
        _ ->
          IO.liftIO $ deleteRequestNodeDB requestNodeId connection
-}


-- * util

findNodeInScenarioNodes :: UUID -> [ScenarioNode] -> Maybe ScenarioNode
findNodeInScenarioNodes nodeIdToFind scenarioNodes =
  Maybe.listToMaybe . Maybe.catMaybes $ map findNodeInScenarioNode scenarioNodes
  where
    findNodeInScenarioNode :: ScenarioNode -> Maybe ScenarioNode
    findNodeInScenarioNode scenarioNode =
      case scenarioNode ^. scenarioNodeId == nodeIdToFind of
        True -> Just scenarioNode
        False ->
          case scenarioNode of
            ScenarioFile {} ->
              Nothing
            ScenarioFolder {} ->
              findNodeInScenarioNodes nodeIdToFind (scenarioNode ^. scenarioNodeChildren)