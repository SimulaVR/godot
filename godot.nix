{ stdenv, lib, fetchFromGitHub, scons, libX11, libXcursor
, libXinerama, libXrandr, libXrender, libpulseaudio ? null
, libXi ? null, libXext, libXfixes, freetype, openssl
, alsa-lib, libGLU, zlib, yasm ? null, xwayland, wayland-protocols, libglvnd, libGL, mesa, pixman, libxkbcommon, fontconfig, eudev, callPackage, devBuild ? false, onNixOS ? false, pkgs, xorg, wayland
, pkg-config, autoreconfHook, libbsd, python310, dbus, libv4l, wayland-scanner
}:

let
  options = {
    touch = libXi != null;
    pulseaudio = false;
  };
  xvfb-run = callPackage ./xvfb-run.nix { };
  wlroots = callPackage ../wlroots { };

	/* Modify a stdenv so that it produces debug builds; that is,
		binaries have debug info, and compiler optimisations are
		disabled. */
	keepDebugInfo = stdenv: stdenv //
		{ mkDerivation = args: stdenv.mkDerivation (args // {
				dontStrip = true;
				NIX_CFLAGS_COMPILE = toString (args.NIX_CFLAGS_COMPILE or "") + " -g -ggdb -Og";
			});
		};
	stdenvRes = if devBuild then (keepDebugInfo stdenv) else stdenv;

  xwayland-dev = xwayland.overrideAttrs (oldAttrs: {
    stdenv = stdenvRes;
  });
  libxcb-dev = xorg.libxcb.overrideAttrs (oldAttrs: {
    stdenv = stdenvRes;
  });
  wayland-dev = wayland.overrideAttrs (oldAttrs: {
    stdenv = stdenvRes;
  });
  wayland-protocols-dev = wayland-protocols.overrideAttrs (oldAttrs: {
    stdenv = stdenvRes;
  });



  libxcb-errors = import ../wlroots/libxcb-errors { stdenv = stdenv; pkg-config=pkg-config; autoreconfHook = autoreconfHook; xorg = xorg; libbsd = libbsd; python310 = python310; lib = lib; };

  nixGLIntel = (callPackage ./nixGL.nix { }).nixGLIntel;
  nixGLRes = if (onNixOS == true) then " " else " ${nixGLIntel}/bin/nixGLIntel ";
  nixGLPkg = if (onNixOS == true) then eudev else nixGLIntel;

  generateApiDev = (if onNixOS == true then "xvfb-run $out/bin/godot.x11.tools.64 --gdnative-generate-json-api $out/bin/api.json" else ("${nixGLIntel}/bin/nixGLIntel xvfb-run $out/bin/godot.x11.tools.64 --gdnative-generate-json-api $out/bin/api.json"));
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

  nativeBuildInputs = [ scons pkg-config ];

  buildInputs = [
    libX11 libXcursor libXinerama libXrandr libXrender
    libXi libXext libXfixes freetype openssl alsa-lib libpulseaudio
    libGLU zlib yasm
    wlroots xwayland-dev wayland-protocols-dev libglvnd libGL mesa libxkbcommon freetype fontconfig xorg.xorgproto xorg.libX11 xorg.libXt xorg.libXft xorg.libXext xorg.libSM xorg.libICE eudev xvfb-run nixGLPkg xorg.libpthreadstubs libxcb-dev wayland-dev
    libxcb-errors
		pixman dbus libv4l
  ];

  enableParallelBuilding = true;

  sconsFlags = "target=debug platform=x11";
  preConfigure = ''
    sconsFlags+=" ${lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${builtins.toJSON v}") options)}"
  '';

  outputs = [ "out" "dev" "man" ];

  configurePhase = ''
    cd modules/gdwlroots
    ${wayland-scanner}/bin/wayland-scanner server-header ${wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.h
    ${wayland-scanner}/bin/wayland-scanner private-code ${wayland-protocols}/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml xdg-shell-protocol.c
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

  dontStrip = true;

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
    license     = lib.licenses.mit;
    platforms   = [ "i686-linux" "x86_64-linux" ];
    maintainers = [ lib.maintainers.twey ];
  };
}
