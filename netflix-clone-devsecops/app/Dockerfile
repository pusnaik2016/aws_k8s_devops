# ==============================================================================
# Dockerfile — Netflix Clone (Multi-Stage Production Build)
# ==============================================================================
# Stage 1: Build the React application with Node.js
# Stage 2: Serve the built static files with Nginx (minimal image)
#
# Security:
#   - Multi-stage build (no build tools in production image)
#   - Non-root user (nginx UID 101)
#   - Read-only root filesystem compatible
#   - HEALTHCHECK directive for container orchestration
#
# Build:
#   docker build --build-arg TMDB_API_KEY=your_key -t netflix-clone .
#
# Run:
#   docker run -p 80:80 netflix-clone
# ==============================================================================

# =============================================================================
# Stage 1: Build — Compile React application
# =============================================================================
FROM node:18-alpine AS builder

# Build argument for TMDB API key (injected at build time)
ARG TMDB_API_KEY
ENV REACT_APP_TMDB_API_KEY=${TMDB_API_KEY}

# Set working directory
WORKDIR /app

# Install dependencies first (better Docker layer caching)
# Only re-install when package files change
COPY package.json package-lock.json* ./
RUN npm ci --production=false --ignore-scripts 2>/dev/null || npm install --ignore-scripts

# Copy source code and build
COPY public/ ./public/
COPY src/ ./src/
COPY nginx.conf ./nginx.conf

# Build the production React bundle
RUN npm run build

# =============================================================================
# Stage 2: Production — Serve with Nginx (minimal image)
# =============================================================================
FROM nginx:1.27-alpine

# Labels for container metadata
LABEL maintainer="DevSecOps Pipeline"
LABEL description="Netflix Clone — React app served via Nginx"
LABEL version="1.0"

# Remove default Nginx configuration
RUN rm -rf /etc/nginx/conf.d/default.conf /usr/share/nginx/html/*

# Copy custom Nginx configuration
COPY --from=builder /app/nginx.conf /etc/nginx/nginx.conf

# Copy the built React application
COPY --from=builder /app/build /usr/share/nginx/html

# Create directories for nginx temp files (for read-only root filesystem)
RUN mkdir -p /tmp/nginx && \
    chown -R nginx:nginx /tmp/nginx /var/cache/nginx /var/log/nginx && \
    chmod -R 755 /usr/share/nginx/html

# Expose port 80 (HTTP)
EXPOSE 80

# Health check — verifies Nginx is serving the application
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:80/healthz || exit 1

# Run as non-root user
USER nginx

# Start Nginx in foreground mode
CMD ["nginx", "-g", "daemon off;"]
