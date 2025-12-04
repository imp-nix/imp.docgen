# docgen

Generate API documentation from Nix source files using [nixdoc](https://github.com/nix-community/nixdoc) and [mdbook](https://rust-lang.github.io/mdBook/).

docgen extracts documentation from file comments, function doc comments, and NixOS-style module options, producing markdown suitable for mdbook sites.

## Quick start

Add docgen as a flake input:

```nix
{
  inputs.docgen.url = "github:imp-nix/imp.docgen";
}
```

Create a documentation manifest (`_docs.nix` or similar):

```nix
{
  files = {
    title = "File Reference";
    sections = [
      {
        name = "Core";
        files = [
          "default.nix"
          "api.nix"
          { name = "lib.nix"; fallback = "Internal utilities."; }
        ];
      }
    ];
  };

  methods = {
    title = "API Methods";
    sections = [
      { file = "api.nix"; }
      { file = "lib.nix"; heading = "Utilities"; exports = [ "helper" "util" ]; }
    ];
  };

  options = {
    title = "Module Options";
    anchorPrefix = "opt-";
  };
}
```

Create a docgen instance:

```nix
{
  perSystem = { pkgs, self', ... }:
    let
      dg = docgen.mkDocgen {
        inherit pkgs;
        manifest = ./src/_docs.nix;
        srcDir = ./src;
        siteDir = ./docs;
        name = "myproject";
        optionsJson = self'.packages.options-json;  # optional
      };
    in {
      packages.docs = dg.docs;
      apps.docs.program = dg.serveDocsScript;
      apps.build-docs.program = dg.buildDocsScript;
    };
}
```

## mkDocgen arguments

Required:

| Argument   | Description                               |
| ---------- | ----------------------------------------- |
| `pkgs`     | Nixpkgs package set                       |
| `manifest` | Path or attrset defining what to document |
| `srcDir`   | Source directory containing .nix files    |

Optional:

| Argument       | Default       | Description                                                 |
| -------------- | ------------- | ----------------------------------------------------------- |
| `siteDir`      | `null`        | mdbook site directory (contains book.toml)                  |
| `extraFiles`   | `{}`          | Extra files to copy (e.g. `{ "README.md" = ./README.md; }`) |
| `optionsJson`  | `null`        | JSON file for options.md generation                         |
| `anchorPrefix` | `""`          | Prefix for function anchors                                 |
| `name`         | `"docs"`      | Project name for derivation                                 |
| `referenceDir` | `"reference"` | Subdirectory within docs/src/ for output                    |

Returns an attrset with:

| Attribute            | Description                               |
| -------------------- | ----------------------------------------- |
| `docs`               | Built mdbook site derivation              |
| `apiReference`       | Generated markdown files only             |
| `serveDocsScript`    | Script for local serving with live reload |
| `buildDocsScript`    | Script for local building                 |
| `generateDocsScript` | Low-level markdown generation script      |

## Manifest schema

### files

Generate a file reference with descriptions from file-level doc comments:

```nix
{
  files = {
    title = "File Reference";
    sections = [
      {
        name = "Section Name";
        files = [
          "file.nix"
          { name = "other.nix"; fallback = "Description if no doc comment"; }
        ];
      }
    ];
  };
}
```

### methods

Generate function documentation using nixdoc:

```nix
{
  methods = {
    title = "API Methods";
    sections = [
      { file = "api.nix"; }
      { file = "lib.nix"; heading = "Utilities"; exports = [ "fn1" "fn2" ]; }
    ];
  };
}
```

### options

Generate module options documentation from JSON:

```nix
{
  options = {
    title = "Module Options";
    anchorPrefix = "opt-";
  };
}
```

## Options JSON helper

Convert NixOS-style options to JSON for nixdoc:

```nix
docgen.lib.optionsToJson {
  optionsModule = { lib, ... }: {
    options.myApp = {
      enable = lib.mkEnableOption "myApp";
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port to listen on";
      };
    };
  };
  prefix = "myApp.";  # optional filter
}
```

## Writing doc comments

File-level:

```nix
# This file provides the core API for managing widgets.
#
# It exports functions for creating, updating, and deleting widgets.
{ lib }:
{ ... }
```

Function-level (nixdoc format):

````nix
{
  /**
    Create a new widget with the given name.

    # Arguments

    - `name` (string): The widget name
    - `options` (attrset): Optional configuration

    # Example

    ```nix
    mkWidget "foo" { color = "red"; }
    => { name = "foo"; color = "red"; }
    ```
  */
  mkWidget = name: options: { inherit name; } // options;
}
````

## License

MIT
