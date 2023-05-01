module API.Types.News (
  CreateNews (..),
  EditNews (..),
  GetNews (..),
  module Service.Types.News,
  QueryParams (..),
) where

import API.Prelude (Generic)
import API.TH (makeRecordToSchemaTypes, makeSumToSchemaTypes, processRecordApiTypes)
import Common.Prelude (Text)

import API.Types.User (AuthorName)
import Data.Default (Default)
import Service.Types.News (Filters (..), GetNews (..), Image (..), Images, NewsText, Title)
import Service.Types.User (CategoryId, CreatedAt, CreatedSince, CreatedUntil)

data CreateNews = CreateNews
  { _createNews_title :: !Title
  , _createNews_text :: !NewsText
  , _createNews_category :: CategoryId
  , _createNews_images :: Images
  }
  deriving (Generic)

data EditNews = EditNews
  { _editNews_id :: Int
  , _editNews_text :: !Text
  , _editNews_category :: Int
  , _editNews_images :: Images
  }
  deriving (Generic)

data QueryParams = QueryParams
  { _queryParams_createdUntil :: Maybe CreatedUntil
  , _queryParams_createdSince :: Maybe CreatedSince
  , _queryParams_createdAt :: Maybe CreatedAt
  , _queryParams_authorName :: Maybe AuthorName
  , _queryParams_category :: Maybe CategoryId
  , _queryParams_titleLike :: Maybe Title
  , _queryParams_textLike :: Maybe NewsText
  , _queryParams_block :: Maybe Int
  }
  deriving (Generic)

instance Default QueryParams

makeSumToSchemaTypes [''CreatedAt, ''CreatedSince, ''CreatedUntil, ''NewsText, ''Title]

makeRecordToSchemaTypes [''GetNews, ''Image]

processRecordApiTypes [''EditNews, ''CreateNews, ''QueryParams]
