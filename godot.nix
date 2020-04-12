{ stdenv, lib, fetchFromGitHub, scons, pkgconfig, libX11, libXcursor
, libXinerama, libXrandr, libXrender, libpulseaudio ? null
, libXi ? null, libXext, libXfixes, freetype, openssl
, alsaLib, libGLU, zlib, yasm ? null, xwayland, wayland-protocols, libglvnd, libGL, mesa_noglu, pixman, libxkbcommon, x11, eudev, callPackage, devBuild ? false, driverCheck ? "", pkgs }:

let
  options = {
    touch = libXi != null;
    pulseaudio = false;
  };
  xvfb-run = callPackage ./xvfb-run.nix { };
  wlroots = callPackage ../wlroots/wlroots.nix { };

  driverCheckList = lib.splitString " " driverCheck;
  nvidia-version = if ((builtins.head driverCheckList) == "nvidia") then (builtins.elemAt driverCheckList 1) else null;
  nvidia-hash = if ((builtins.head driverCheckList) == "nvidia") then (builtins.elemAt driverCheckList 2) else null;
  nixVulkanNvidia = ((import ./nixGL.nix) { nvidiaVersion = "${nvidia-version}"; nvidiaHash = "${nvidia-hash}"; pkgs = pkgs; }).nixVulkanNvidia;
  nixGLIntel = ((import ./nixGL.nix) { pkgs = pkgs; }).nixGLIntel;
  nixVulkanIntel = ((import ./nixGL.nix) { pkgs = pkgs; }).nixVulkanIntel;
  nixGLRes = if ((builtins.head driverCheckList) == "nixos") then " " else (if ((builtins.head driverCheckList) == "nvidia") then " ${nixVulkanNvidia}/bin/nixVulkanNvidia " else " ${nixVulkanIntel}/bin/nixVulkanIntel ");
  nixGLPkg = if ((builtins.head driverCheckList) == "nvidia") then nixVulkanNvidia else (if driverCheck == "nixos" then eudev else nixVulkanIntel);

  generateApiDev = (if driverCheck == "nixos" then "xvfb-run $out/bin/godot.x11.tools.64 --gdnative-generate-json-api $out/bin/api.json" else ("${nixGLIntel}/bin/nixGLIntel xvfb-run $out/bin/godot.x11.tools.64 --gdnative-generate-json-api $out/bin/api.json"));

  generateApi = if (devBuild == false) then "cp api.json $out/bin/api.json" else generateApiDev;

  nonDevBuildInstall = if (devBuild == false) then ''

    scons platform=x11 tools=no target=release bits=64 -j $NIX_BUILD_CORES
    scons platform=x11 tools=no target=release_debug bits=64 -j $NIX_BUILD_CORES
    cp bin/godot.x11.opt.64 $out/bin/godot.x11.opt.64
    cp bin/godot.x11.opt.debug.64 $out/bin/godot.x11.opt.debug.64

    '' else ''
    '';

in stdenv.mkDerivation rec {
  pname = "godot";
  version = "3.2";

  src = ./.;

  nativeBuildInputs = [ scons pkgconfig ];

  buildInputs = [
    libX11 libXcursor libXinerama libXrandr libXrender
    libXi libXext libXfixes freetype openssl alsaLib libpulseaudio
    libGLU zlib yasm
    wlroots xwayland wayland-protocols libglvnd libGL mesa_noglu libxkbcommon x11 eudev xvfb-run nixGLPkg
  ];

  patches = [
    ./pkg_config_additions.patch
    ./dont_clobber_environment.patch
  ];

  enableParallelBuilding = true;

  sconsFlags = "target=debug platform=x11";
  preConfigure = ''
    sconsFlags+=" ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${builtins.toJSON v}") options)}"
  '';

  outputs = [ "out" "dev" "man" ];

  configurePhase = ''
    cd modules/gdwlroots
    wayland-scanner server-header ${wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.h
    wayland-scanner private-code ${wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.c
    cd ../..
    patchShebangs platform/android/SCsub
    patchShebangs platform/android/java/gradlew
    patchShebangs platform/javascript/SCsub
    patchShebangs platform/SCsub
    patchShebangs platform/windows/SCsub
    patchShebangs platform/x11/SCsub
    patchShebangs platform/server/SCsub
    patchShebangs platform/haiku/SCsub
    patchShebangs platform/uwp/SCsub
    patchShebangs platform/osx/SCsub
    patchShebangs platform/iphone/SCsub
    patchShebangs doc/tools/doc_status.py
    patchShebangs doc/tools/doc_merge.py
    patchShebangs doc/tools/makerst.py
    patchShebangs drivers/dummy/SCsub
    patchShebangs drivers/xaudio2/SCsub
    patchShebangs drivers/winmidi/SCsub
    patchShebangs drivers/SCsub
    patchShebangs drivers/windows/SCsub
    patchShebangs drivers/alsamidi/SCsub
    patchShebangs drivers/png/SCsub
    patchShebangs drivers/wasapi/SCsub
    patchShebangs drivers/coremidi/SCsub
    patchShebangs drivers/alsa/SCsub
    patchShebangs drivers/unix/SCsub
    patchShebangs drivers/pulseaudio/SCsub
    patchShebangs drivers/gles2/SCsub
    patchShebangs drivers/gles2/shaders/SCsub
    patchShebangs drivers/gl_context/SCsub
    patchShebangs drivers/gles3/SCsub
    patchShebangs drivers/gles3/shaders/SCsub
    patchShebangs drivers/coreaudio/SCsub
    patchShebangs misc/hooks/pre-commit-makerst
    patchShebangs misc/hooks/pre-commit-clang-format
    patchShebangs misc/scripts/fix_headers.py
    patchShebangs misc/scripts/make_icons.sh
    patchShebangs misc/scripts/fix_style.sh
    patchShebangs main/SCsub
    patchShebangs nixGL.nix
    patchShebangs nixGL.nix
    patchShebangs nixGL.nix
    patchShebangs nixGL.nix
    patchShebangs scene/3d/SCsub
    patchShebangs scene/audio/SCsub
    patchShebangs scene/resources/SCsub
    patchShebangs scene/resources/default_theme/SCsub
    patchShebangs scene/resources/default_theme/make_header.py
    patchShebangs scene/SCsub
    patchShebangs scene/main/SCsub
    patchShebangs scene/debugger/SCsub
    patchShebangs scene/animation/SCsub
    patchShebangs scene/2d/SCsub
    patchShebangs scene/gui/SCsub
    patchShebangs editor/import/SCsub
    patchShebangs editor/doc/SCsub
    patchShebangs editor/SCsub
    patchShebangs editor/collada/SCsub
    patchShebangs editor/fileserver/SCsub
    patchShebangs editor/plugins/SCsub
    patchShebangs editor/icons/SCsub
    patchShebangs SConstruct
    patchShebangs servers/physics/joints/SCsub
    patchShebangs servers/physics/SCsub
    patchShebangs servers/audio/effects/SCsub
    patchShebangs servers/audio/SCsub
    patchShebangs servers/physics_2d/SCsub
    patchShebangs servers/SCsub
    patchShebangs servers/camera/SCsub
    patchShebangs servers/arvr/SCsub
    patchShebangs servers/visual/SCsub
    patchShebangs core/io/SCsub
    patchShebangs core/crypto/SCsub
    patchShebangs core/os/SCsub
    patchShebangs core/bind/SCsub
    patchShebangs core/SCsub
    patchShebangs core/math/SCsub
    patchShebangs modules/webp/SCsub
    patchShebangs modules/ogg/SCsub
    patchShebangs modules/tinyexr/SCsub
    patchShebangs modules/webm/libvpx/SCsub
    patchShebangs modules/webm/SCsub
    patchShebangs modules/cvtt/SCsub
    patchShebangs modules/vorbis/SCsub
    patchShebangs modules/jsonrpc/SCsub
    patchShebangs modules/gdnative/nativescript/SCsub
    patchShebangs modules/gdnative/SCsub
    patchShebangs modules/gdnative/videodecoder/SCsub
    patchShebangs modules/gdnative/net/SCsub
    patchShebangs modules/gdnative/arvr/SCsub
    patchShebangs modules/gdnative/pluginscript/SCsub
    patchShebangs modules/bullet/SCsub
    patchShebangs modules/mono/SCsub
    patchShebangs modules/upnp/SCsub
    patchShebangs modules/recast/SCsub
    patchShebangs modules/dds/SCsub
    patchShebangs modules/etc/SCsub
    patchShebangs modules/gridmap/SCsub
    patchShebangs modules/SCsub
    patchShebangs modules/theora/SCsub
    patchShebangs modules/arkit/SCsub
    patchShebangs modules/opensimplex/SCsub
    patchShebangs modules/hdr/SCsub
    patchShebangs modules/svg/SCsub
    patchShebangs modules/camera/SCsub
    patchShebangs modules/xatlas_unwrap/SCsub
    patchShebangs modules/squish/SCsub
    patchShebangs modules/csg/SCsub
    patchShebangs modules/mobile_vr/SCsub
    patchShebangs modules/stb_vorbis/SCsub
    patchShebangs modules/enet/SCsub
    patchShebangs modules/jpg/SCsub
    patchShebangs modules/visual_script/SCsub
    patchShebangs modules/regex/SCsub
    patchShebangs modules/pvr/SCsub
    patchShebangs modules/freetype/SCsub
    patchShebangs modules/websocket/SCsub
    patchShebangs modules/webrtc/SCsub
    patchShebangs modules/gdscript/SCsub
    patchShebangs modules/assimp/SCsub
    patchShebangs modules/mbedtls/SCsub
    patchShebangs modules/bmp/SCsub
    patchShebangs modules/opus/SCsub
    patchShebangs modules/vhacd/SCsub
    patchShebangs modules/tga/SCsub
    '';

  dontStrip = devBuild;

  installPhase = ''
    mkdir -p "$out/bin"

    # Making these symlinks doesn't work for some reason
    cp bin/godot.x11.tools.64 $out/bin/godot
    cp bin/godot.x11.tools.64 $out/bin/godot.x11.tools.64

    mkdir "$dev"
    cp -r modules/gdnative/include $dev

    mkdir -p "$man/share/man/man6"
    cp misc/dist/linux/godot.6 "$man/share/man/man6/"

    mkdir -p "$out"/share/{applications,icons/hicolor/scalable/apps}
    cp misc/dist/linux/org.godotengine.Godot.desktop "$out/share/applications/"
    cp icon.svg "$out/share/icons/hicolor/scalable/apps/godot.svg"
    cp icon.png "$out/share/icons/godot.png"
    substituteInPlace "$out/share/applications/org.godotengine.Godot.desktop" \
      --replace "Exec=godot" "Exec=$out/bin/godot"

    '' + generateApi +
    ''
    '' + nonDevBuildInstall;

  meta = {
    homepage    = "https://godotengine.org";
    description = "Free and Open Source 2D and 3D game engine";
    license     = stdenv.lib.licenses.mit;
    platforms   = [ "i686-linux" "x86_64-linux" ];
    maintainers = [ stdenv.lib.maintainers.twey ];
  };
}