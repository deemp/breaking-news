module Service.Effects.News where

import Effectful (Effect)
import Effectful.TH (makeEffect)
import Service.Types.News as ServiceNews (CreateNews (..), Filters (..), GetNews (..))
import Service.Types.User (Role)

data ServiceNews :: Effect where
  ServiceCreateNews :: CreateNews -> ServiceNews m ()
  ServiceGetNews :: Filters Maybe -> Role -> ServiceNews m [GetNews]

makeEffect ''ServiceNews