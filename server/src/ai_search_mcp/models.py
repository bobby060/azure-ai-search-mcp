from pydantic import BaseModel, Field


class SearchIndex(BaseModel):
    """Output Schema of list indexes."""

    name: str = Field(description="The name of the index")
    description: str = Field(description="The description of the index")
