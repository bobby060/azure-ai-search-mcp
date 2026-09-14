import os

from azure.core.credentials import AzureAuthorityHosts, DefaultAzureCredential
from azure.search.documents import SearchClient, SearchIndexClient
from fastmcp import FastMCP

from .models import SearchIndex

# Initialize the MCP server
mcp = FastMCP("weather")

AUDIENCE = "https://search.azure.us"

service_endpoint = os.environ["AZURE_SEARCH_SERVICE_ENDPOINT"]
index_name = os.environ["AZURE_SEARCH_INDEX_NAME"]
key = os.environ["AZURE_SEARCH_API_KEY"]

credential = DefaultAzureCredential(authority=AzureAuthorityHosts.AZURE_US)

search_index_client = SearchIndexClient(service_endpoint, credential, audience=AUDIENCE)


def build_client(index_name: str):
    # TODO: Add error handling for invalid index
    return SearchClient(service_endpoint, index_name, credential, audience=AUDIENCE)


@mcp.tool()
async def list_search_indexes() -> list[SearchIndex] | None:
    """List all indexes available on the Azure AI Search instance"""
    return [
        SearchIndex(i.name, i.description) for i in search_index_client.list_indexes
    ]


# TODO: Add validation for query_Type
@mcp.tool()
async def query_index(index_name: str, query: str, query_type: str) -> list[dict]:
    """Search an index for a query.

    Args:
        index_name: name of index to query
        query: search string
        query_type: either simple or semantic
    """
    if query_type not in ["simple", "semantic"]:
        raise ValueError(
            f"query_type {query_type} is not valid.Use either `simple` or `semantic`"
        )

    client = build_client(index_name)
    return [r for r in client.search(query, query_type=query_type)]
