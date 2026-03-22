# OpenResty for Termux (Android)

An automated build and environment script to run OpenResty on Android via Termux.

## Features
- Fixes `MAXNS` and `__poll_t` preprocessor errors.
- Relocates installation to home directory.
- Automatically creates environment wrappers with correct `LD_LIBRARY_PATH` and Lua search paths.

## Installation
```bash
# Clone the repository
git clone https://github.com/joaothallis/termux-openresty
cd termux-openresty

# Run the build script
chmod +x build-openresty-termux.sh
./build-openresty-termux.sh
```

## Usage
The script installs wrapper binaries in `~/bin/` by default. Ensure this directory is in your `$PATH`:

```bash
export PATH="$HOME/bin:$PATH"
```

### Commands Available
- `openresty -V`: Show version and configuration.
- `resty -e "print("hello world")"`: Run Lua code from the command line.
- `opm list`: Manage OpenResty packages.
- `nginx`: Standard Nginx command (pre-configured with the correct prefix).

## Technical Details
This script solves three main hurdles in Termux:
1. **Missing `MAXNS`**: Injected via compiler flags.
2. **`__poll_t` Casts**: Bypassed in `ngx_epoll_module.c` using automated patches.
3. **Relocation**: Uses `DESTDIR` and wrapper scripts to avoid the read-only `/usr/local` filesystem.

## Port Configuration
By default, this script patches `nginx.conf` to listen on port **8080**. 
In Termux, non-root users cannot bind to ports below 1024.

To start the server:
```bash
openresty
```
Access it at: `http://localhost:8080`
### Managing the Server
- **Stop**: `openresty -s stop`
- **Reload**: `openresty -s reload` (apply config changes without stopping)
- **Test Config**: `openresty -t`