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

El repositorio esta creado y listo para GitHub Pages. El catalogo inicial esta vacio hasta publicar los primeros `.deb` reconstruidos para Kembriq Runtime.
