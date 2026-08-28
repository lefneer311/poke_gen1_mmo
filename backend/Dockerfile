# Servidor de partida del Pokémon MMO.
#
# No sirve el juego: el cliente es una página estática (web/) que puede vivir
# en GitHub Pages, y esta imagen solo lleva el coordinador. Publica un único
# puerto porque es lo único que un PaaS o un túnel saben exponer; el
# WebSocket va montado en /ws sobre ese mismo puerto.
#
#   docker build -t pokemon-mmo-server -f backend/Dockerfile .
#   docker run --rm -p 8080:8080 pokemon-mmo-server
#
# Comprobación:  curl http://localhost:8080/health

# ---------------------------------------------------------------- build
FROM node:22-alpine AS build
WORKDIR /app

# Las dependencias se copian solas primero para que un cambio en src/ no
# invalide la capa de npm ci, que es la lenta.
COPY backend/package.json backend/package-lock.json ./
RUN npm ci

COPY backend/tsconfig.json backend/tsconfig.build.json backend/nest-cli.json ./
COPY backend/src ./src
RUN npm run build

# Las de desarrollo (Nest CLI, TypeScript, Jest) ya han hecho su trabajo.
RUN npm prune --omit=dev

# ---------------------------------------------------------------- runtime
FROM node:22-alpine
WORKDIR /app

# Nunca como root: el proceso solo necesita abrir un socket.
USER node

COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --chown=node:node backend/package.json ./
COPY --chown=node:node docs/database/migrations ./migrations

ENV NODE_ENV=production
ENV PORT=8080
# Sin WS_PORT: en producción el WebSocket comparte el puerto HTTP en /ws.
# Definirlo aquí abriría un segundo puerto que nadie podría alcanzar.
ENV HOST=0.0.0.0
ENV DATABASE_MIGRATIONS_DIR=/app/migrations

EXPOSE 8080

# El cliente desktop dial TCP directo; se publica aparte con -p 7778:7778 si
# se quiere jugar desde el ejecutable en vez del navegador.
EXPOSE 7778

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "dist/main.js"]
