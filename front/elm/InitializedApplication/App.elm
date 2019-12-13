module InitializedApplication.App exposing (..)

import InitializedApplication.Model exposing (..)

import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Html exposing (Html)

import BuilderApp.BuilderTree.View as BuilderTree
import BuilderApp.BuilderTree.Util as BuilderTree
import Postman.View as Postman
import EnvironmentEdition.App as EnvironmentEdition
import EnvironmentToRunSelection.App as EnvSelection
import MainNavBar.App as MainNavBar
import VarApp.View as VarApp

import BuilderApp.Model as BuilderApp
import BuilderApp.View as BuilderApp

import Util.List as List
import List.Extra as List

import BuilderApp.App as BuilderApp
import BuilderApp.Model as BuilderApp
import BuilderApp.Message as BuilderApp
import BuilderApp.App as BuilderApp
import BuilderApp.Message as BuilderApp

import BuilderApp.Builder.App as Builder
import BuilderApp.Builder.Model as Builder
import BuilderApp.Builder.App as Builder
import BuilderApp.Builder.Message as Builder

import BuilderApp.BuilderTree.View as BuilderTree
import BuilderApp.BuilderTree.Message as BuilderTree
import BuilderApp.BuilderTree.App as BuilderTree

import Postman.View as Postman
import Postman.Model as Postman
import Postman.Message as Postman
import Postman.App as Postman

import Signin.App as Signin

import EnvironmentEdition.App as EnvironmentEdition

import EnvironmentToRunSelection.Message as EnvSelection
import EnvironmentToRunSelection.App as EnvSelection

import RequestRunner.App as RequestRunner
import RequestRunner.Message as RequestRunner
import RequestRunner.Model as RequestRunner
import RequestRunner.Util as RequestRunner

import MainNavBar.App as MainNavBar

import VarApp.Model as VarApp
import VarApp.View as VarApp
import VarApp.Message as VarApp
import VarApp.App as VarApp

import Api.Generated as Client

import Util.Flip exposing (..)
import Util.List as List
import List.Extra as List

import Curl.Util as Curl
import Http as Http

import Application.Type exposing (..)


-- * message


type Msg
    = BuilderTreeMsg BuilderTree.Msg
    | BuilderAppMsg BuilderApp.Msg
    | PostmanMsg Postman.Msg
    | EnvironmentEditionMsg EnvironmentEdition.Msg
    | RequestRunnerMsg RequestRunner.Msg
    | MainNavBarMsg MainNavBar.Msg
    | VarAppMsg VarApp.Msg
    | SigninMsg Signin.Msg


-- * update


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        BuilderTreeMsg subMsg ->
            let
                newModel = BuilderTree.update subMsg model
            in
                (newModel, Cmd.none)

        BuilderAppMsg subMsg ->
            case subMsg of
                {-
                BuilderApp.BuilderMsg Builder.AskRun ->
                    (model, Cmd.none)-}
--                    case getEnvironmentToRun model of
                        {-
                        Just environment ->
                            case RequestRunner.update (RequestRunner.Run environment.keyValues model.varAppModel builder) Nothing of
                              (_, runnerSubMsg) -> (model, Cmd.map RequestRunnerMsg runnerSubMsg)

                        Nothing ->-}


                BuilderApp.BuilderMsg (Builder.ShowRequestAsCurl) ->
                    (model, Cmd.none)

                _ ->
                    let
                        (newModel, newMsg) = BuilderApp.update subMsg model
                    in
                        (newModel, Cmd.map BuilderAppMsg newMsg)

        EnvironmentEditionMsg subMsg ->
            case EnvironmentEdition.update subMsg model of
                (newModel, newSubMsg) ->
                    (newModel, Cmd.map EnvironmentEditionMsg newSubMsg)

        PostmanMsg subMsg ->
            case Postman.update subMsg model.postmanModel of
                (_, _) -> (model, Cmd.none)

        RequestRunnerMsg subMsg ->
            (model, Cmd.none)

        MainNavBarMsg subMsg ->
            case MainNavBar.update subMsg model of
                newModel ->
                    ( newModel
                    , Cmd.none
                    )

        VarAppMsg subMsg ->
            case VarApp.update subMsg model.varAppModel of
                newVarAppModel ->
                    ( { model | varAppModel = newVarAppModel }
                    , Cmd.none
                    )

        SigninMsg subMsg ->
            case Signin.update subMsg model of
                newModel ->
                    ( newModel
                    , Cmd.none
                    )

subscriptions : Model -> Sub Msg
subscriptions _ =
  Sub.none

replaceEnvironmentToEdit : Model -> Environment -> Model
replaceEnvironmentToEdit model newEnvironment =
    let newEnvironments =
            case model.selectedEnvironmentToEditId of
                Just idx ->
                    List.updateListAt model.environments idx (\formerEnvironment -> newEnvironment)
                Nothing ->
                    model.environments
    in
        { model | environments = newEnvironments }


-- * view


view : Model -> Element Msg
view model =
    case model.session of
        Visitor {} ->
            visitorView model

        SignedUser {} ->
            signedUserView model


signedUserView : Model -> Element Msg
signedUserView model =
    let
        contentView : Element Msg
        contentView =
            el [ width fill ] <|
                case model.mainNavBarModel of
                    ReqTab -> builderView model
                    EnvTab -> map EnvironmentEditionMsg (EnvironmentEdition.view model)
                    SigninTab -> map SigninMsg (Signin.view model)
    in
        column [ width fill, centerY, spacing 30 ]
            [ map MainNavBarMsg (MainNavBar.view model)
            , contentView
            ]

visitorView : Model -> Element Msg
visitorView model =
    let
        contentView : Element Msg
        contentView =
            el [ width fill, centerX, centerY ] <|
                case model.mainNavBarModel of
                    ReqTab -> builderView model
                    EnvTab -> map EnvironmentEditionMsg (EnvironmentEdition.view model)
                    SigninTab -> map SigninMsg (Signin.view model)
    in
        column [ width fill, centerY, spacing 30 ]
            [ map MainNavBarMsg (MainNavBar.view model)
            , contentView
            ]


builderView : Model -> Element Msg
builderView model =
  let
    envSelectionView : Element Msg
    envSelectionView =
        none
--        map EnvSelectionMsg (EnvSelection.view (List.map .name model.environments))
  in
    row [ width fill ]
      [ el [ width fill ] (map BuilderAppMsg (BuilderApp.view model))
      , el [] envSelectionView
      ]

--postmanView : Element Msg
--postmanView =
--  Html.map PostmanMsg Postman.view
