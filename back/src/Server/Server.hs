module Server.Server (Server, runServerEffect, startServer, getWaiApplication, writeJWK) where

import API.Endpoints.API1.News as ApiNews (API (API, create, get))
import API.Endpoints.API1.Root as API1 (API (API, news, user))
import API.Endpoints.API1.User as ApiUser (API (..))
import API.Root (Routes (..))
import API.Types.Instances ()
import API.Types.News ()
import API.Types.User (AccessToken)
import Control.Monad.Except (ExceptT (..), runExceptT)
import Controller.Effects.News (NewsController)
import Controller.Effects.Users (UserController)
import Controller.News qualified as NewsController
import Controller.User qualified as UserController
import Crypto.JOSE (JWK, KeyMaterialGenParam (..), genJWK)
import Data.Aeson qualified
import Data.ByteString.Lazy qualified as BSL
import Data.String (fromString)
import Effectful (Eff, Effect, IOE, Limit (..), MonadIO (liftIO), Persistence (Ephemeral), UnliftStrategy (ConcUnlift), withEffToIO, withUnliftStrategy, type (:>))
import Effectful.Dispatch.Dynamic (interpret)
import Effectful.TH (makeEffect)
import External.Logger (Logger, logInfo, withLogger)
import GHC.Generics (Generic (..))
import Network.Wai (Application)
import Network.Wai.Handler.Warp qualified as Warp
import Servant (Context (EmptyContext), HasServer (ServerT))
import Servant.API (GServantProduct, NamedRoutes, ToServant, ToServantApi, toServant)
import Servant.Auth.Server (AuthResult (..), defaultCookieSettings, defaultJWTSettings)
import Servant.Auth.Server.Internal.AddSetCookie (AddSetCookieApi, AddSetCookies (..), Nat (S))
import Servant.Server qualified as Servant
import Servant.Server.Generic (AsServerT, genericServeTWithContext)
import Servant.Server.Named ()
import Servant.Server.Record ()
import Server.Config (App (_app_web), Loader, Web (_web_port), getConfig)

-- wire up all controllers here

data Server :: Effect where
  GetWaiApplication :: Server m Application
  StartServer :: Server m ()

makeEffect ''Server

withAccessToken :: AuthResult AccessToken -> (AccessToken -> a) -> a
withAccessToken r f = case r of
  Authenticated c -> f c
  _ -> error "sdsdfsd"

type Constraints es =
  ( IOE :> es
  , Loader App :> es
  , Loader JWK :> es
  , Logger :> es
  , NewsController :> es
  , UserController :> es
  )

runServerEffect :: forall es a. Constraints es => Eff (Server : es) a -> Eff es a
runServerEffect = interpret $ \_ -> \case
  StartServer -> do
    port <- getConfig (_web_port . _app_web)
    jwk <- getConfig id
    waiApp <- getWaiApplication' jwk
    withLogger . logInfo . fromString $ "listening at port " <> show port
    liftIO $ Warp.run port waiApp
  GetWaiApplication -> getConfig id >>= getWaiApplication'

type instance AddSetCookieApi (NamedRoutes api) = AddSetCookieApi (ToServantApi api)
instance
  {-# OVERLAPS #-}
  ( AddSetCookies ('S n) (ServerT (ToServantApi api) m) cookiedApi
  , Generic (api (AsServerT m))
  , GServantProduct (Rep (api (AsServerT m)))
  , ToServant api (AsServerT m) ~ ServerT (ToServantApi api) m
  ) =>
  AddSetCookies ('S n) (api (AsServerT m)) cookiedApi
  where
  addSetCookies cookies = addSetCookies cookies . toServant

getWaiApplication' :: forall es. Constraints es => JWK -> Eff es Application
getWaiApplication' jwk = do
  withUnliftStrategy (ConcUnlift Ephemeral Unlimited) $ withEffToIO $ \unlift -> do
    let
      serverToHandler :: ExceptT Servant.ServerError (Eff es) x -> Servant.Handler x
      serverToHandler = Servant.Handler . ExceptT . liftIO . unlift . runExceptT
      waiApp =
        genericServeTWithContext
          serverToHandler
          Routes
            { api1 =
                API1.API
                  { user = ApiUser.API{
                      register = UserController.register jwk,
                      login = UserController.login jwk,
                      rotateRefreshToken = UserController.rotateRefreshToken jwk refreshToken}
                  , news = \token ->
                      ApiNews.API
                        { create = withAccessToken token NewsController.create
                        , get = withAccessToken token NewsController.get
                        }
                  }
            }
          (defaultJWTSettings jwk Servant.:. defaultCookieSettings Servant.:. EmptyContext)
    pure waiApp

writeJWK :: IO ()
writeJWK = do
  jwk <- genJWK (RSAGenParam 1000)
  BSL.writeFile "jwk.json" (Data.Aeson.encode jwk)