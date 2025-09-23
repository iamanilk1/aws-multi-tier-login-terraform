FROM nginx:1.27-alpine

# Copy static frontend assets
COPY . /usr/share/nginx/html

# Simple health endpoint
RUN echo "OK" > /usr/share/nginx/html/health

EXPOSE 80
