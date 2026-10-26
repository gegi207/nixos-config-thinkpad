{ config, lib, pkgs, ... }:

{
  imports = [ 
    ./hardware-configuration.nix
  ];

  # Koristi systemd-boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Fixovi za freezeove
  boot.kernelParams = [
    "i915.enable_psr=0"      
    "i915.enable_dc=0"       
    "i915.enable_fbc=0"      
    "intel_idle.max_cstate=2"
  ];
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Hostname
  networking.hostName = "djuro-laptop-thinkpad";

  # Network postavke
  networking.networkmanager.enable = true;
  networking.firewall.allowedTCPPorts = [ 445 139 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];

  # Time zone
  time.timeZone = "Europe/Zagreb";

  # Servisi
  services = {
    fwupd.enable = true;
    journald.extraConfig = "SyncIntervalSec=10s";
    openssh.enable = true;
    desktopManager.plasma6.enable = true;
    displayManager.sddm.enable = true;
    displayManager.sddm.wayland.enable = true;
    printing.enable = true;
    input-remapper.enable = true;
    input-remapper.enableUdevRules = true;
    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa.enable = true;
    };
    samba = {
      enable = true;
      # SAMBA Postavke
      settings = {
        global = {
          workgroup = "WORKGROUP";
          "server string" = "Djurin Nixos server";
          "netbios name" = "NIXOS";
          "guest account" = "nobody";
        };
        public = {
          path = "/samba/public";
          browseable = true;  
          "read only" = false;
          "guest ok" = true;
          "force user" = "nobody";
          "force group" = "nogroup";
          "create mask" = "0777";
          "directory mask" = "0777";
          "force directory mode" = "0777";
          "force create mode" = "0777";
        };  
      };
    };
  };  

  # Dopustenje za propriatery programe
  nixpkgs.config.allowUnfree = true;

  # Neke stvari za casting na KDE-u
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
  xdg.portal.config.common.default = [ "kde" ];

  # Graphics driveri
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  # Bluetooth driveri
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Ovo kao treba da neke stvari rade
  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
  ];

  # POPIS SVIH PACKAGEOVA - OVO EDITIRAJ
  environment.systemPackages = with pkgs; [
    # KDE Plasma stvari
    kdePackages.discover
    kdePackages.kcalc
    kdePackages.kcharselect
    kdePackages.kclock
    kdePackages.kcolorchooser
    kdePackages.kolourpaint
    kdePackages.ksystemlog
    kdePackages.sddm-kcm
    kdePackages.isoimagewriter
    kdePackages.partitionmanager
    kdePackages.korganizer
    kdePackages.kdenlive
    kdiff3
    hardinfo2
    wayland-utils
    wl-clipboard
    
    # Korisni programi
    vlc
    firefox
    spotify
    guvcview
    obs-studio
    proton-vpn
    qbittorrent

    # Office programi
    thunderbird
    libreoffice

    # Programi za programiranje
    jetbrains.pycharm
    jetbrains.idea
    jetbrains.clion
    vscode
    git
    sublime4
    lmstudio
    gcc
    gdb
    gnumake

    # Gaming
    steam
    prismlauncher
    lutris

    # Texting
    viber
    discord

    # Misc programi
    fastfetch
    htop
    wine
    winetricks
    vulkan-tools
    mesa-demos
    gnome-network-displays
    samba
    lsof
  ];

  # Fontovi
  fonts.packages = with pkgs; [
    liberation_ttf_v2
    helvetica-neue-lt-std
    dejavu_fonts
    noto-fonts
  ];
  fonts.fontDir.enable = true;

  # Neki sistemski programi
  programs.zsh.enable = true;
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      openssl
    ];
  };

  # VirtualBox
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  users.extraGroups.vboxusers.members = [ "gregor" ];

  # Autodelete za stare generacije
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 5d";
  };

  security.rtkit.enable = true;

  # Touchpad support
  services.libinput.enable = true;

  # User account
  users.users.gregor = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" ];
    packages = with pkgs; [
      tree
    ];
  };

  # NE DIRAJ
  system.stateVersion = "26.05";
}