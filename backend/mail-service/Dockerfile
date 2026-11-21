FROM node:22-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY server.js ./
COPY finance-intake-worker.mjs finance-intake-core.mjs finance-intake-ocr.mjs ./
ENV PORT=10000
EXPOSE 10000
CMD ["npm", "start"]
