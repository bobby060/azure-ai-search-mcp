# Build stage
FROM alpine:3.24.1 AS builder

WORKDIR /app

# Install uv
RUN apk add --no-cache curl \
    && curl -LsSf https://astral.sh/uv/install.sh | sh

ENV PATH="/root/.local/bin:$PATH"

# Copy project files
COPY pyproject.toml README.md uv.lock* ./
COPY src/ ./src/

# Install dependencies with uv
RUN uv sync --frozen

# Runtime stage
FROM alpine:3.24.1


WORKDIR /app

RUN apk upgrade --no-cache libcrypto3 libssl3

# Create a non-root user for security
RUN adduser -D -u 1000 mcp

# Copy virtual environment from builder
COPY --from=builder --chown=mcp:mcp /app/.venv /app/.venv

# Copy application code
COPY --from=builder --chown=mcp:mcp /app/src ./src

# Switch to non-root user
USER mcp

# Activate virtual environment
ENV PATH="/app/.venv/bin:$PATH"

# Expose the port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/sse')" || exit 1

# Run the MCP server
CMD ["start-mcp"]
