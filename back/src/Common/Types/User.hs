module Common.Types.User where

import API.Prelude (Generic, PersistField, UTCTime, ToHttpApiData, FromHttpApiData)
import Common.Prelude (Text)
import Common.TH (processRecords, processSums)
import Data.Aeson (encode)
import Data.String (IsString)
import Data.String.Interpolate (i)
import Database.Esqueleto.Experimental (PersistField (..), PersistFieldSql (sqlType), PersistValue (PersistInt64), SqlType (SqlInt64))
import Servant.Auth.JWT (FromJWT, ToJWT)

newtype Password = Password Text
  deriving (Show, Eq, Generic)
  deriving newtype (IsString)

newtype HashedPassword = HashedPassword Text
  deriving (Generic)
  deriving newtype (PersistField, Eq, Ord, Show, PersistFieldSql, IsString)

newtype UserName = UserName Text
  deriving (Generic)
  deriving newtype (PersistField, Eq, Ord, Show, PersistFieldSql, IsString)

newtype AuthorName = AuthorName Text
  deriving (Generic)
  deriving newtype (PersistField, Eq, Ord, Show, PersistFieldSql, IsString, ToHttpApiData, FromHttpApiData)

newtype UserId = UserId Int
  deriving (Generic)
  deriving newtype (Num, Enum, Show, Eq, Ord, Real, Integral)

-- | Role of a user
data Role
  = RoleUser
  | RoleAdmin
  deriving (Generic, Eq, Ord, Show)

newtype TokenId = TokenId Int
  deriving (Generic)
  deriving newtype (Num, PersistField, Eq, Ord, Show, PersistFieldSql)

newtype SessionId = SessionId Int
  deriving (Generic)
  deriving newtype (Num, Integral, Enum, Real, Ord, Eq)

newtype ExpiresAt = ExpiresAt UTCTime
  deriving (Generic)
  deriving newtype (PersistField, Eq, Ord, Show, PersistFieldSql)

data AccessToken = AccessToken
  { _accessToken_role :: Role
  , _accessToken_userId :: UserId
  , _accessToken_id :: TokenId
  -- ^ index within a session
  , _accessToken_sessionId :: SessionId
  -- ^ coincides with the id of the corresponding refresh token
  }
  deriving (Generic)

data RefreshToken = RefreshToken
  { _refreshToken_sessionId :: SessionId
  -- ^ id of a session starting from registration or login
  , _refreshToken_id :: TokenId
  -- ^ index within that session
  }
  deriving (Generic)

data InsertUser = InsertUser
  { _insertUser_userName :: UserName
  , _insertUser_hashedPassword :: HashedPassword
  , _insertUser_authorName :: AuthorName
  , _insertUser_role :: Role
  }
  deriving (Show, Eq, Generic)

data SelectUser = SelectUser
  { _selectUser_userName :: UserName
  , _selectUser_password :: Password
  }
  deriving (Show, Eq, Generic)

instance PersistField Role where
  toPersistValue :: Role -> PersistValue
  toPersistValue =
    PersistInt64 . \case
      RoleUser -> 1
      RoleAdmin -> 2
  fromPersistValue :: PersistValue -> Either Text Role
  fromPersistValue v
    | v == toPersistValue RoleUser = Right RoleUser
    | v == toPersistValue RoleAdmin = Right RoleAdmin
    | otherwise = Left [i|Role #{v} is undefined|]

instance PersistFieldSql Role where
  sqlType _ = SqlInt64

data DBUser = DBUser
  { _user_userName :: UserName
  , _user_hashedPassword :: HashedPassword
  , _user_authorName :: AuthorName
  , _user_role :: Role
  , _user_id :: UserId
  }
  deriving (Show, Eq, Generic)

data Session = Session
  { _session_tokenId :: TokenId
  , _session_tokenExpiresAt :: ExpiresAt
  , _session_id :: SessionId
  }
  deriving (Generic)

data Admin = Admin
  { _admin_userName :: UserName
  , _admin_password :: Password
  }
  deriving (Show, Generic)

data RegisterError = UserExists deriving (Generic, Show)
data RotateError = SessionDoesNotExist | SessionHasNewerRefreshTokenId deriving (Generic, Show)
data RegisteredUserError = WrongPassword | UserDoesNotExist deriving (Generic, Show)

processSums
  [ ''RegisterError
  , ''RegisteredUserError
  , ''RotateError
  , ''Role
  ]

processRecords
  [ ''Session
  , ''UserName
  , ''HashedPassword
  , ''Admin
  , ''Password
  , ''ExpiresAt
  , ''SessionId
  , ''UserId
  , ''TokenId
  , ''AuthorName
  , ''AccessToken
  , ''RefreshToken
  , ''InsertUser
  , ''SelectUser
  , ''DBUser
  ]

instance ToJWT AccessToken
instance ToJWT RefreshToken
instance FromJWT AccessToken
instance FromJWT RefreshToken

-- Demo encoding

ex1 = encode (Left SessionDoesNotExist :: Either RotateError Int)
ex2 = encode (Left UserExists :: Either RegisterError Int)
ex3 = encode $ AuthorName "authorName"

-- >>> ex1
-- "{\"Left\":\"SessionDoesNotExist\"}"

-- >>> ex2
-- "{\"Left\":\"UserExists\"}"

-- >>> ex3
-- "\"authorName\""