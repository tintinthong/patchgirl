{-# LANGUAGE DataKinds                 #-}
{-# LANGUAGE DuplicateRecordFields     #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE FlexibleInstances         #-}
{-# LANGUAGE MultiParamTypeClasses     #-}
{-# LANGUAGE NamedFieldPuns            #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE OverloadedStrings         #-}
{-# LANGUAGE ScopedTypeVariables       #-}
{-# LANGUAGE TypeOperators             #-}


module RequestNode.AppSpec where

import           Control.Lens.Getter     ((^.))
import           Data.UUID
import qualified Data.UUID               as UUID
import qualified Network.HTTP.Types      as HTTP
import           Servant
import qualified Servant.Auth.Client     as Auth
import qualified Servant.Auth.Server     as Auth
import           Servant.Client          (ClientM, client)
import           Test.Hspec

import           Account.DB
import           App
import           Helper.App
import           RequestCollection.DB
import           RequestCollection.Model
import           RequestNode.DB
import           RequestNode.Model


-- * client


updateRequestNodeHandler :: Auth.Token -> Int -> UUID -> UpdateRequestNode -> ClientM ()
deleteRequestNodeHandler :: Auth.Token -> Int -> UUID -> ClientM ()
updateRequestNodeHandler :<|> deleteRequestNodeHandler =
  client (Proxy :: Proxy (PRequestNodeApi '[Auth.JWT]))


-- * spec


spec :: Spec
spec =
  withClient (mkApp defaultConfig) $ do


-- ** update request node


    describe "update request node" $ do
      it "returns 404 when request node doesnt exist" $ \clientEnv ->
        cleanDBAfter $ \connection -> do
          accountId <- insertFakeAccount defaultNewFakeAccount1 connection
          token <- signedUserToken accountId
          try clientEnv (updateRequestNodeHandler token 1 UUID.nil updateRequestNode) `shouldThrow` errorsWithStatus HTTP.notFound404

      it "returns 404 if the request node doesnt belong to the account" $ \clientEnv ->
        cleanDBAfter $ \connection -> do
          accountId2 <- insertFakeAccount defaultNewFakeAccount2 connection
          accountId1 <- insertFakeAccount defaultNewFakeAccount1 connection
          RequestCollection requestCollectionId requestNodes <- insertSampleRequestCollection accountId2 connection
          let nodeId = head requestNodes ^. requestNodeId
          token <- signedUserToken accountId1
          try clientEnv (updateRequestNodeHandler token requestCollectionId nodeId updateRequestNode) `shouldThrow` errorsWithStatus HTTP.notFound404

      it "modifies a request folder" $ \clientEnv ->
        cleanDBAfter $ \connection -> do
          accountId <- insertFakeAccount defaultNewFakeAccount1 connection
          RequestCollection requestCollectionId requestNodes <- insertSampleRequestCollection accountId connection
          let nodeId = head requestNodes ^. requestNodeId
          token <- signedUserToken accountId
          _ <- try clientEnv (updateRequestNodeHandler token requestCollectionId nodeId updateRequestNode)
          FakeRequestFolder { _fakeRequestFolderName } <- selectFakeRequestFolder nodeId connection
          _fakeRequestFolderName `shouldBe` "newName"


-- ** delete request node


    describe "delete request node" $ do
      it "returns 404 when request node doesnt exist" $ \clientEnv ->
        cleanDBAfter $ \connection -> do
          accountId <- insertFakeAccount defaultNewFakeAccount1 connection
          token <- signedUserToken accountId
          try clientEnv (deleteRequestNodeHandler token 1 UUID.nil) `shouldThrow` errorsWithStatus HTTP.notFound404

      it "returns 404 if the request node doesnt belong to the account" $ \clientEnv ->
        cleanDBAfter $ \connection -> do
          accountId1 <- insertFakeAccount defaultNewFakeAccount1 connection
          accountId2 <- insertFakeAccount defaultNewFakeAccount2 connection
          RequestCollection requestCollectionId requestNodes <- insertSampleRequestCollection accountId2 connection
          let nodeId = head requestNodes ^. requestNodeId
          token <- signedUserToken accountId1
          try clientEnv (deleteRequestNodeHandler token requestCollectionId nodeId) `shouldThrow` errorsWithStatus HTTP.notFound404

      it "delete a request node" $ \clientEnv ->
        cleanDBAfter $ \connection -> do
          accountId <- insertFakeAccount defaultNewFakeAccount1 connection
          RequestCollection requestCollectionId requestNodes <- insertSampleRequestCollection accountId connection
          let nodeId = head requestNodes ^. requestNodeId
          token <- signedUserToken accountId
          selectNodeExists nodeId connection `shouldReturn` True
          _ <- try clientEnv (deleteRequestNodeHandler token requestCollectionId nodeId)
          selectNodeExists nodeId connection `shouldReturn` False

  where
    updateRequestNode :: UpdateRequestNode
    updateRequestNode =
      UpdateRequestNode { _updateRequestNodeName = "newName" }
