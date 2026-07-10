iii GLIBC版本问题及解决办法

问题

iii预编译二进制需要*GLIBC2.34+*，但系统是Ubuntu20.04（GLIBC2.31），无法直接运行。
Ubuntu20.04的libc6无法通过apt升级到2.32+。

解决方案：patchelf＋独立glibc

1．安装 patchelf

```bash
    sudo apt install patchelf
```

2.提取 Ubuntu 22.04 的glibc 2.35

```bash
    mkdir -p /tmp/glibc-patch && cd /tmp/glibc-patch
    curl -sl "http://archive.ubuntu.com/ubuntu/pool/main/g/glibc/libc6_2.35-0ubuntu3.13_amd64.deb" -o libc6.deb
    curl -sl "http://archive.ubuntu.com/ubuntu/pool/main/g/glibc/libc-bin_2.35-0ubuntu3.13_amd64.deb" -0 libc-bin.deb
    mkdir -p extract && dpkg-deb -x libc6.deb extract/ && dpkg-deb -x libc-bin.deb extract/
```

3．永久存放glibc

```bash
    mkdir -p ~/.agentmemory/glibc
    cp -a /tmp/glibc-patch/extract/lib/x86_64-linux-gnu/* ~/.agentmemory/glibc/
    rm -rf /tmp/glibc-patch
```

4. patchelf 改 iii 的 interpreter 和 rpath

```bash
    patchelf --set-interpreter ~/.agentmemory/glibc/ld-linux-x86-64.so.2 \
             --set-rpath ~/.agentmemory/glibc \
             ~/.agentmemory/bin/iii
```

