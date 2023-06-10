FROM node:lts-hydrogen
WORKDIR /root

# npm requirements.
COPY package.json .
RUN npm install --omit=dev

# tsc configurations.
COPY tsconfig.json .

# Main source code.
ADD src src
RUN npm run build

CMD node ./build/index.js
