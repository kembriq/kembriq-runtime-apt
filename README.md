# Kembriq Runtime APT Repository

Repositorio publico de paquetes para Kembriq Runtime.

Este repo aloja un catalogo APT curado para Android arm64, compilado para:

```txt
package: com.kembriq.code
prefix:  /data/data/com.kembriq.code/files/usr
```

Los paquetes publicados aqui no deben contener:

```txt
com.termux
/data/data/com.termux
/data/user/0/com.termux
```

## Layout

```txt
dists/stable/Release
dists/stable/main/binary-aarch64/Packages
dists/stable/main/binary-aarch64/Packages.gz
pool/main/
```

## Estado

El repositorio esta publicado por GitHub Pages. Para generar paquetes reales, ejecutar manualmente el workflow:

```txt
Build Kembriq Runtime
```

Sets recomendados:

```txt
base        -> bootstrap con apt/dpkg/shell/coreutils para instalar runtime inicial
git-python  -> git, python, pip y venv para pruebas de agente
node        -> nodejs-lts para npm/run/preview
all         -> set inicial completo curado
```

El primer objetivo para probar en celular es `base`. Despues de instalar ese bootstrap, la app puede probar `apt update` contra este repo y luego instalar `git-python` o `node`.
