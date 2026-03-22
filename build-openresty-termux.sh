#!/data/data/com.termux/files/usr/bin/bash
# A build script for OpenResty on Termux (Android)
# Handles missing MAXNS, __poll_t cast errors, and relocation to home directory.

set -e

# Configuration - Change these if needed
OPENRESTY_VERSION="1.29.2.1"
INSTALL_ROOT="$HOME/openresty-install"
WRAPPER_BIN_DIR="$HOME/bin" # Must be in your $PATH

echo "--- Starting OpenResty $OPENRESTY_VERSION Build for Termux ---"

# 1. Install Dependencies
echo "[1/8] Installing build dependencies..."
pkg install -y clang make perl pcre2 openssl zlib wget

# 2. Download and Extract
if [ ! -d "openresty-$OPENRESTY_VERSION" ]; then
    echo "[2/8] Downloading OpenResty source..."
    wget -q "https://openresty.org/download/openresty-$OPENRESTY_VERSION.tar.gz"
    tar -xzf "openresty-$OPENRESTY_VERSION.tar.gz"
fi
cd "openresty-$OPENRESTY_VERSION"

# 3. Configure
echo "[3/8] Configuring Nginx with Termux-specific flags..."
./configure \
    --prefix=/usr/local/openresty \
    --with-cc-opt="-O2 -DMAXNS=3" \
    --with-ld-opt="-Wl,-rpath,/usr/local/openresty/luajit/lib" \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-http_ssl_module

# 4. Patch Epoll Module
EPOLL_SRC="build/nginx-$(echo $OPENRESTY_VERSION | cut -d. -f1-3)/src/event/modules/ngx_epoll_module.c"
echo "[4/8] Patching $EPOLL_SRC for Termux compatibility..."
# Use : as delimiter to avoid conflict with | in C source
sed -i 's:^#if (NGX_READ_EVENT != EPOLLIN|EPOLLRDHUP):#if 0:' "$EPOLL_SRC"
sed -i 's:^#if (NGX_WRITE_EVENT != EPOLLOUT):#if 0:' "$EPOLL_SRC"

# 5. Build
echo "[5/8] Compiling OpenResty (Injecting MAXNS)..."
make -j$(nproc) CC="cc -DMAXNS=3"

# 6. Install to Local Directory
echo "[6/8] Installing to $INSTALL_ROOT..."
mkdir -p "$INSTALL_ROOT"
make install DESTDIR="$INSTALL_ROOT"

# 6.5 Patch default port to 8080 (Termux cannot bind to port 80)
echo "[6.5/8] Patching default port to 8080..."
sed -i "s/listen       80;/listen       8080;/" "$INSTALL_ROOT/usr/local/openresty/nginx/conf/nginx.conf"

# 7. Patch Hardcoded Paths in Binaries
echo "[7/8] Patching hardcoded paths in scripts..."
RESTY_BIN="$INSTALL_ROOT/usr/local/openresty/bin/resty"
# Fix hardcoded nginx sbin path
sed -i "s|/usr/local/openresty/nginx/sbin/nginx|$INSTALL_ROOT/usr/local/openresty/nginx/sbin/nginx|g" "$RESTY_BIN"
# Fix hardcoded /tmp path for Termux
sed -i "s|/tmp|/data/data/com.termux/files/usr/tmp|g" "$RESTY_BIN"

# 8. Create Environment Wrappers
echo "[8/8] Creating wrapper scripts in $WRAPPER_BIN_DIR..."
mkdir -p "$WRAPPER_BIN_DIR"

create_wrapper() {
    local name=$1
    local target=$2
    local extra_args=$3
    cat <<EOW > "$WRAPPER_BIN_DIR/$name"
#!/data/data/com.termux/files/usr/bin/bash
# OpenResty Termux Wrapper
export LD_LIBRARY_PATH="$INSTALL_ROOT/usr/local/openresty/luajit/lib:\$LD_LIBRARY_PATH"
export LUA_PATH="$INSTALL_ROOT/usr/local/openresty/lualib/?.lua;$INSTALL_ROOT/usr/local/openresty/lualib/?/init.lua;;"
export LUA_CPATH="$INSTALL_ROOT/usr/local/openresty/lualib/?.so;;"
exec $target $extra_args "\$@"
EOW
    chmod +x "$WRAPPER_BIN_DIR/$name"
}

create_wrapper "nginx" "$INSTALL_ROOT/usr/local/openresty/nginx/sbin/nginx" "-p $INSTALL_ROOT/usr/local/openresty/nginx"
create_wrapper "openresty" "$INSTALL_ROOT/usr/local/openresty/nginx/sbin/nginx" "-p $INSTALL_ROOT/usr/local/openresty/nginx"
create_wrapper "resty" "$INSTALL_ROOT/usr/local/openresty/bin/resty" ""
create_wrapper "opm" "$INSTALL_ROOT/usr/local/openresty/bin/opm" ""

echo "--- Build Complete! ---"
