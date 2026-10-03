FROM node:20-alpine

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

RUN apk add --no-cache \
    ca-certificates \
    chromium \
    freetype \
    harfbuzz \
    nss \
    ttf-freefont

COPY server.js ima-a5-sync.mjs ./

ENV PORT=10000
ENV CHROMIUM_PATH=/usr/bin/chromium-browser
EXPOSE 10000

CMD ["npm", "start"]
