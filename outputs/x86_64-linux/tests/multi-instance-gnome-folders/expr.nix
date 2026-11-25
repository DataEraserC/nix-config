{ outputs, lib, ... }:
let
  base = outputs.nixosConfigurations.ai-gnome-wayland;

  # Two synthetic programs on top of the host's own table: one with enough
  # instances to earn a folder, one below the default threshold.
  withMinimumInstances =
    minimumInstances:
    (base.extendModules {
      modules = [
        {
          modules.multi-instance = {
            gnomeAppFolders = {
              enable = true;
              inherit minimumInstances;
            };
            apps = {
              folder-demo = {
                paths = [ ".folder-demo" ];
                desktop = {
                  label = "Folder Demo";
                  icon = "folder-demo";
                  wmclass = "FolderDemo";
                };
              };
              single-demo = {
                paths = [ ".single-demo" ];
                desktop = {
                  label = "Single Demo";
                  icon = "single-demo";
                  wmclass = "SingleDemo";
                };
              };
            };
            instances = {
              folder-demo = 2;
              single-demo = 1;
            };
          };
        }
      ];
    }).config;

  settingsOf =
    config:
    lib.foldl' (
      acc: database: lib.recursiveUpdate acc database.settings
    ) { } config.programs.dconf.profiles.user.databases;
  childrenOf = settings: settings."org/gnome/desktop/app-folders".folder-children;
  grouped = name: settings: lib.elem "multi-instance-${name}" (childrenOf settings);
  folderPath = name: "org/gnome/desktop/app-folders/folders/multi-instance-${name}";

  defaultSettings = settingsOf (withMinimumInstances 2);
  singleAllowedSettings = settingsOf (withMinimumInstances 1);
in
{
  groupedAtDefault = grouped "folder-demo" defaultSettings;
  singleHiddenAtDefault = !(grouped "single-demo" defaultSettings);
  singleGroupedWhenAllowed = grouped "single-demo" singleAllowedSettings;

  folder = defaultSettings.${folderPath "folder-demo"};
  singleFolderAbsent = !(defaultSettings ? ${folderPath "single-demo"});
}
