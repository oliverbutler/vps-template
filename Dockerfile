# Example Dockerfile - Simple Nginx App
FROM nginx:alpine

ARG IMAGE_TAG=unknown
ENV IMAGE_TAG=${IMAGE_TAG}

# Create a custom nginx config to listen on port 3000
RUN echo 'server {
    listen 3000;
    listen [::]:3000;
    server_name localhost;
    
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
    }
    
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}' > /etc/nginx/conf.d/default.conf

# Create a simple HTML page
RUN echo '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Example Nginx App</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 {
            margin-bottom: 1rem;
            font-size: 2.5rem;
        }
        p {
            font-size: 1.2rem;
            margin: 0.5rem 0;
        }
        .version {
            font-size: 0.9rem;
            opacity: 0.8;
            margin-top: 1rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Example Nginx App</h1>
        <p>Welcome to your containerized web application!</p>
        <p>This is a simple example serving static content with Nginx.</p>
        <div class="version">Image Version: '$IMAGE_TAG'</div>
    </div>
</body>
</html>' > /usr/share/nginx/html/index.html

EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
