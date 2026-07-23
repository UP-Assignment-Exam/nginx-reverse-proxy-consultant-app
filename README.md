# NGINX Reverse Proxy Setup

This project uses an NGINX reverse proxy to route traffic between a containerized frontend and backend. 

## Architecture

- **Frontend**: A React application (built with Vite) served by a lightweight Node.js Express server on port `3001` internally.
- **Backend**: A Node.js Express API server on port `3000` internally, connected to MongoDB.
- **NGINX**: Acts as the reverse proxy on port `8081` (host), securely routing requests without exposing the internal services to the host machine.
  - `/api/*` requests are forwarded to the `backend` service.
  - All other requests (`/`) are forwarded to the `frontend` service.

## Getting Started

Make sure you have Docker and Docker Compose installed.

1. Build and start the containers in detached mode:
   ```bash
   docker compose up -d --build
   ```

2. Open your browser and navigate to:
   **[http://localhost:8081](http://localhost:8081)**

3. To view logs:
   ```bash
   docker compose logs -f
   ```

4. To stop the containers:
   ```bash
   docker compose down
   ```
