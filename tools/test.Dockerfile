# Lua 5.1 (the WoW client's Lua) with busted and luacheck, for local runs and CI.
#   docker build -f tools/test.Dockerfile -t girthbind-test .
#   docker run --rm -v "$PWD:/src" girthbind-test
FROM nickblah/lua:5.1-luarocks-alpine

RUN apk add --no-cache build-base git \
    && luarocks install busted 2.2.0-1 \
    && luarocks install luacheck 1.2.0-1

WORKDIR /src
CMD ["sh", "-c", "luacheck . && busted"]
