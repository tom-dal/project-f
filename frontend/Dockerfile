# Dockerfile per Frontend Flutter Web
FROM nginx:stable-alpine

# Copia i file build di Flutter nella directory servita da nginx
COPY build/web /usr/share/nginx/html

# Copia la configurazione nginx personalizzata per Single Page Application
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Esponi porta 80
EXPOSE 80

# Avvia nginx
CMD ["nginx", "-g", "daemon off;"]
