FROM nginx:1.27-alpine

# Copy static frontend assets
COPY . /usr/share/nginx/html

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Simple health endpoint
RUN echo "OK" > /usr/share/nginx/html/health

EXPOSE 80
