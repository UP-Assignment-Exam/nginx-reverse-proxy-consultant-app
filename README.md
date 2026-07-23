# NGINX Reverse Proxy Setup

This project uses an NGINX reverse proxy to route traffic between a frontend and backend.

## Architecture

- **Frontend**: A React application (built with Vite) served by a lightweight Node.js Express server on port `3001` internally.
- **Backend**: A Node.js Express API server on port `3000` internally, connected to MongoDB.
- **NGINX**: Acts as the reverse proxy on port `8081` (host), securely routing requests without exposing the internal services directly.
  - `/api/*` requests are forwarded to the `backend` service.
  - All other requests (`/`) are forwarded to the `frontend` service.

## Deployment Options

This project provides two distinct ways to deploy and run the application:
1. **Docker Compose** (Recommended for portability and isolation)
2. **Manual Shell Script** (Recommended for traditional VPS/Ubuntu servers without Docker)

---

### Option 1: Using Docker Compose

Docker encapsulates all dependencies (NGINX, Node.js, MongoDB) into self-contained environments.

**Prerequisites**: Docker and Docker Compose installed.

1. Build and start the containers in detached mode:
   ```bash
   docker compose up -d --build
   ```

2. Open your browser and navigate to: **[http://localhost:8081](http://localhost:8081)**

3. Useful Docker commands:
   - **View logs**: `docker compose logs -f`
   - **Stop containers**: `docker compose down`

---

### Option 2: Using the Manual Shell Script (`setup-ubuntu.sh`)

If you prefer to run the applications directly on your server host OS (like an Ubuntu/Debian VPS) without Docker, we have provided an automated setup script: `setup-ubuntu.sh`.

**Prerequisites**: An Ubuntu/Debian based server. You will also need to ensure MongoDB is installed locally on port `27017` or provide a `MONGODB_URI` environment variable to the backend.

#### What the script does under the hood:
1. **Updates Packages**: Runs `apt-get update`.
2. **Installs System Dependencies**: Installs `nginx` and `nodejs` (v20 LTS via NodeSource).
3. **Installs PM2**: Installs `pm2` globally (`npm install -g pm2`). PM2 is a robust process manager that keeps Node.js applications alive in the background and restarts them if they crash.
4. **Sets up the Backend**: 
   - Navigates to the `backend/` directory and runs `npm install`.
   - Starts the backend server using PM2 (`pm2 start npm --name "consultant-backend" -- run dev`).
5. **Sets up the Frontend**:
   - Navigates to the `frontend/` directory and runs `npm install`.
   - Builds the production static assets with `npm run build`.
   - Starts the frontend Express server using PM2 (`pm2 start server.js --name "consultant-frontend"`).
6. **Configures NGINX**:
   - Creates an NGINX server block configuration at `/etc/nginx/sites-available/consultant-app` that listens on port `8081` and proxies traffic to ports `3000` and `3001`.
   - Symlinks this config to `/etc/nginx/sites-enabled/`.
   - Tests and restarts the NGINX service (`systemctl restart nginx`).
7. **Saves PM2 State**: Runs `pm2 save` so your Node.js apps automatically restart if the server reboots.

#### How to run it:

1. Make the script executable:
   ```bash
   chmod +x setup-ubuntu.sh
   ```

2. Run the script (it requires sudo privileges for NGINX and Node installations):
   ```bash
   ./setup-ubuntu.sh
   ```

3. Open your browser and navigate to: **[http://localhost:8081](http://localhost:8081)**

4. Useful PM2 commands to manage the apps later:
   - **View running apps**: `pm2 list`
   - **View logs**: `pm2 logs`
   - **Stop an app**: `pm2 stop consultant-frontend`

---

## File References

### `setup-ubuntu.sh`
<details>
<summary>Click to expand</summary>

```bash
#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "===================================================="
echo " Starting Manual Server Setup (Ubuntu/Debian based) "
echo "===================================================="

# 1. Update packages
echo "--> Updating package list..."
sudo apt-get update

# 2. Install NGINX
echo "--> Installing NGINX..."
sudo apt-get install -y nginx

# 3. Install Node.js (v20 LTS)
echo "--> Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js is already installed."
fi

# 4. Install PM2
echo "--> Installing PM2 (Process Manager)..."
sudo npm install -g pm2

# 5. Start Backend
echo "--> Setting up Backend..."
cd backend
npm install
# Stop if it already exists to allow safely re-running the script
pm2 delete consultant-backend 2>/dev/null || true
# We use PM2 to run your backend process in the background. 
# It runs `npm run dev` to use tsx, just like in local development.
pm2 start npm --name "consultant-backend" -- run dev
cd ..

# 6. Start Frontend
echo "--> Setting up Frontend..."
cd frontend
npm install
npm run build
pm2 delete consultant-frontend 2>/dev/null || true
# PM2 runs the Node.js Express server to serve the built static Vite files
pm2 start server.js --name "consultant-frontend"
cd ..

# 7. Configure NGINX
echo "--> Configuring NGINX Reverse Proxy..."
NGINX_CONF="/etc/nginx/sites-available/consultant-app"

# We use sudo bash to write the nginx configuration to the system folder
sudo bash -c "cat > \$NGINX_CONF <<'EOF'
server {
    listen 8081;

    location /api/ {
        proxy_pass http://localhost:3000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        proxy_pass http://localhost:3001/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF"

# Enable the NGINX configuration
sudo ln -sf \$NGINX_CONF /etc/nginx/sites-enabled/

# Test the NGINX configuration and restart the service
sudo nginx -t
sudo systemctl restart nginx

# 8. Save PM2 state
echo "--> Saving PM2 processes to restart on boot..."
pm2 save

echo "===================================================="
echo " Setup Complete! "
echo " The application is running behind NGINX on port 8081."
echo ""
echo " IMPORTANT:"
echo " Ensure MongoDB is installed and running on localhost:27017, "
echo " or set a MONGODB_URI environment variable for your backend."
echo " If you need to install MongoDB locally on Ubuntu, follow:"
echo " https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/"
echo "===================================================="
```
</details>

### `frontend/Dockerfile`
<details>
<summary>Click to expand</summary>

```dockerfile
FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

EXPOSE 3001
CMD ["npm", "start"]
```
</details>

### `backend/Dockerfile`
<details>
<summary>Click to expand</summary>

```dockerfile
FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000
CMD ["npm", "run", "dev"]
```
</details>

