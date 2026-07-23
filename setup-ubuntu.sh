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
if ! command -v nginx &> /dev/null; then
    echo "--> Installing NGINX..."
    sudo apt-get install -y nginx
else
    echo "NGINX is already installed."
fi

# 3. Install Node.js (v20 LTS)
echo "--> Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "Node.js is already installed."
fi

# 4. Install PM2
if ! command -v pm2 &> /dev/null; then
    echo "--> Installing PM2 (Process Manager)..."
    sudo npm install -g pm2
else
    echo "PM2 is already installed."
fi

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
sudo bash -c "cat > $NGINX_CONF <<'EOF'
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
sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/

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
