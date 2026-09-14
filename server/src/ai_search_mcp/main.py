import os

from .tools import mcp

# Constants
HOST_NAME = os.getenv("SERVER_HOST_NAME")
HOST_PORT = os.getenv("SERVER_HOST_PORT")

AUTH_TOKEN = os.getenv("AUTH_TOKEN")


def main():
    # Initialize and run the server with FastMCP
    mcp.run(transport="http", 
            host=HOST_NAME, 
            port=HOST_PORT,
            auth=AUTH_TOKEN)


if __name__ == "__main__":
    main()
