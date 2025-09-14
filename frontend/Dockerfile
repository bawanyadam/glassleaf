# Frontend: Nginx static server proxying /api to backend
FROM nginx:alpine

# Nginx conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Static files
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
