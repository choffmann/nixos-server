{
  modulesPath,
  lib,
  pkgs,
  ...
} @ args: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./hardware-configuration.nix
    ../../modules/matrix.nix
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  sops.defaultSopsFile = ../../secrets/matrix-server.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  sops.secrets.foo = {};
  sops.secrets."homeserver.yaml" = {
    owner = "matrix-synapse";
    restartUnits = ["matrix-synapse.service"];
  };

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
  ];

  time.timeZone = "Europe/Berlin";
  networking.hostName = "matrix";
  networking.domain = "homebin.dev";

  users.users.root.password = "1234";
  users.users.root.hashedPasswordFile = null;
  users.users.root.openssh.authorizedKeys.keys =
    [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJw08ayERLCtV3iZtTRnGWLNJzPyGdfUUm3LUYbDPXT6 choffmann"
    ]
    ++ (args.extraPublicKeys or []); # this is used for unit-testing this module and can be removed if not needed

  services.matrix-synapse.extraConfigFiles = [
    "/run/secrets/homeserver.yaml"
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];
  system.stateVersion = "25.11";
}
