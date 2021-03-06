{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeApplications      #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE UndecidableInstances  #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeOperators         #-}

import           App
import           Control.Lens             ((&), (<>~))
import qualified Data.Aeson               as Aeson
import qualified Data.Text                as T
import           Data.Word
import           Elm.Module               as Elm
import           Elm.TyRep
import           Health.App

import           Debug.Trace
import           ElmOption                (deriveElmDefOption)
import           Environment.App
import           GHC.TypeLits             (ErrorMessage (Text), KnownSymbol,
                                           Symbol, TypeError, symbolVal)
import           Github.App
import           Http
import           Model                    (CaseInsensitive)
import           RequestCollection.Model
import           RequestComputation.App
import           RequestNode.Model
import           Servant                  ((:<|>))
import           Servant.API              ((:>), Capture, Get, JSON)
import           Servant.API.ContentTypes (NoContent)
import           Servant.API.Flatten      (Flat)
import           Servant.Auth             (Auth (..), Cookie)
import           Servant.Auth.Client      (Token)
import           Servant.Auth.Server      (JWT)
import           Servant.Elm
import           Servant.Foreign          hiding (Static)
import           Session.Model

instance IsElmDefinition Token where
  compileElmDef _ = ETypePrimAlias (EPrimAlias (ETypeName "Token" []) (ETyCon (ETCon "String")))

type family TokenHeaderName xs :: Symbol where
  TokenHeaderName (Cookie ': xs) = "X-XSRF-TOKEN"
  TokenHeaderName (JWT ': xs) = "Authorization"
  TokenHeaderName (x ': xs) = TokenHeaderName xs
  TokenHeaderName '[] = TypeError (Text "Neither JWT nor cookie auth enabled")

instance
  ( TokenHeaderName auths ~ header
  , KnownSymbol header
  , HasForeignType lang ftype Token
  , HasForeign lang ftype sub
  , Show ftype
  )
  => HasForeign lang ftype (Auth auths a :> sub) where
    type Foreign ftype (Auth auths a :> sub) = Foreign ftype sub

    foreignFor lang Proxy Proxy req =
      foreignFor lang Proxy subP $ req & reqHeaders <>~ [HeaderArg arg]
      where
        arg   = Arg
          { _argName = PathSegment . T.pack $ symbolVal @header Proxy
          , _argType = token
          }
        token = typeFor lang (Proxy @ftype) (Proxy @Token)
        subP  = Proxy @sub

-- input
deriveElmDef deriveElmDefOption ''RequestCollection
deriveElmDef deriveElmDefOption ''RequestNode
deriveElmDef deriveElmDefOption ''Method
deriveElmDef deriveElmDefOption ''AppHealth
deriveElmDef deriveElmDefOption ''NoContent
deriveElmDef deriveElmDefOption ''NewRequestFile
deriveElmDef deriveElmDefOption ''ParentNodeId
deriveElmDef deriveElmDefOption ''UpdateRequestNode
deriveElmDef deriveElmDefOption ''NewEnvironment
deriveElmDef deriveElmDefOption ''UpdateEnvironment
deriveElmDef deriveElmDefOption ''Environment
deriveElmDef deriveElmDefOption ''KeyValue
deriveElmDef deriveElmDefOption ''NewKeyValue
deriveElmDef deriveElmDefOption ''CaseInsensitive
deriveElmDef deriveElmDefOption ''Session
deriveElmDef deriveElmDefOption ''RequestComputationInput
deriveElmDef deriveElmDefOption ''RequestComputationOutput
deriveElmDef deriveElmDefOption ''RequestComputationResult
deriveElmDef deriveElmDefOption ''Scheme
deriveElmDef deriveElmDefOption ''NewRequestFolder
deriveElmDef deriveElmDefOption ''NewRootRequestFile
deriveElmDef deriveElmDefOption ''NewRootRequestFolder
deriveElmDef deriveElmDefOption ''UpdateRequestFile
deriveElmDef deriveElmDefOption ''HttpHeader
deriveElmDef deriveElmDefOption ''SignInWithGithub


myElmImports :: T.Text
myElmImports = T.unlines
  [ "import Json.Decode"
  , "import Json.Encode exposing (Value)"
  , "-- The following module comes from bartavelle/json-helpers"
  , "import Json.Helpers exposing (..)"
  , "import Dict exposing (Dict)"
  , "import Set"
  , "import Http"
  , "import String"
  , "import Url.Builder"
  , "import Uuid as Uuid"
  , ""
  , "type alias UUID = Uuid.Uuid"
  , ""
  , "jsonDecUUID : Json.Decode.Decoder UUID"
  , "jsonDecUUID = Uuid.decoder"
  , ""
  , "jsonEncUUID : UUID -> Value"
  , "jsonEncUUID = Uuid.encode"
  ]

{-
  this is used to a convert parameter in a url to a string
  eg : whatever.com/books/:someUuidToConvertToString?arg=:someOtherComplexTypeToConvertToString
-}
myDefaultElmToString :: EType -> T.Text
myDefaultElmToString argType =
  case argType of
    ETyCon (ETCon "UUID") -> "Uuid.toString"
    _                     -> defaultElmToString argType

main :: IO ()
main =
  let
    options :: ElmOptions
    options =
      defElmOptions { urlPrefix = Dynamic
                    , stringElmTypes =
                      [ toElmType (Proxy @String)
                      , toElmType (Proxy @T.Text)
                      , toElmType (Proxy @Token)
                      ]
                    , elmToString = myDefaultElmToString
                    }
    namespace =
      [ "Api"
      , "Generated"
      ]
    targetFolder = "../front/elm"
    elmDefinitions =
      [ DefineElm (Proxy :: Proxy RequestCollection)
      , DefineElm (Proxy :: Proxy RequestNode)
      , DefineElm (Proxy :: Proxy Method)
      , DefineElm (Proxy :: Proxy AppHealth)
      , DefineElm (Proxy :: Proxy NoContent)
      , DefineElm (Proxy :: Proxy NewRequestFile)
      , DefineElm (Proxy :: Proxy ParentNodeId)
      , DefineElm (Proxy :: Proxy UpdateRequestNode)
      , DefineElm (Proxy :: Proxy NewEnvironment)
      , DefineElm (Proxy :: Proxy UpdateEnvironment)
      , DefineElm (Proxy :: Proxy Environment)
      , DefineElm (Proxy :: Proxy KeyValue)
      , DefineElm (Proxy :: Proxy NewKeyValue)
      , DefineElm (Proxy :: Proxy CaseInsensitive)
      , DefineElm (Proxy :: Proxy Session)
      , DefineElm (Proxy :: Proxy Token)
      , DefineElm (Proxy :: Proxy RequestComputationInput)
      , DefineElm (Proxy :: Proxy RequestComputationOutput)
      , DefineElm (Proxy :: Proxy RequestComputationResult)
      , DefineElm (Proxy :: Proxy Scheme)
      , DefineElm (Proxy :: Proxy NewRequestFolder)
      , DefineElm (Proxy :: Proxy NewRootRequestFile)
      , DefineElm (Proxy :: Proxy NewRootRequestFolder)
      , DefineElm (Proxy :: Proxy UpdateRequestFile)
      , DefineElm (Proxy :: Proxy HttpHeader)
      , DefineElm (Proxy :: Proxy SignInWithGithub)
      ]
    proxyApi =
      (Proxy :: Proxy (RestApi '[Cookie]))
  in
    generateElmModuleWith options namespace myElmImports targetFolder elmDefinitions proxyApi
