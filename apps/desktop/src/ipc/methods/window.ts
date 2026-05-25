import {
  ContextMenuItemSchema,
  DesktopAppBrandingSchema,
  DesktopEnvironmentBootstrapSchema,
  DesktopThemeSchema,
  PickFolderOptionsSchema,
} from "@t3tools/contracts";
import * as Effect from "effect/Effect";
import * as FileSystem from "effect/FileSystem";
import * as Option from "effect/Option";
import * as Schema from "effect/Schema";

import * as DesktopBackendManager from "../../backend/DesktopBackendManager.ts";
import * as DesktopEnvironment from "../../app/DesktopEnvironment.ts";
import * as ElectronDialog from "../../electron/ElectronDialog.ts";
import * as ElectronMenu from "../../electron/ElectronMenu.ts";
import * as ElectronShell from "../../electron/ElectronShell.ts";
import * as ElectronTheme from "../../electron/ElectronTheme.ts";
import * as ElectronWindow from "../../electron/ElectronWindow.ts";
import * as IpcChannels from "../channels.ts";
import { makeIpcMethod, makeSyncIpcMethod } from "../DesktopIpc.ts";

const ContextMenuPosition = Schema.Struct({
  x: Schema.Number,
  y: Schema.Number,
});

const ContextMenuInput = Schema.Struct({
  items: Schema.Array(ContextMenuItemSchema),
  position: Schema.optionalKey(ContextMenuPosition),
});

type AetherColors = Readonly<Record<string, string>>;

const HEX_COLOR_PATTERN = /^#[0-9a-fA-F]{6}$/;

function readTomlStringValues(raw: string): AetherColors {
  const colors: Record<string, string> = {};
  for (const line of raw.split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Za-z0-9_-]+)\s*=\s*"([^"]+)"\s*(?:#.*)?$/);
    if (!match) continue;
    const [, key, value] = match;
    if (key && value && HEX_COLOR_PATTERN.test(value)) {
      colors[key] = value;
    }
  }
  return colors;
}

function requiredColor(colors: AetherColors, key: string): string | null {
  return colors[key] ?? null;
}

function createAetherThemeCss(colors: AetherColors): string | null {
  const background = requiredColor(colors, "background");
  const foreground = requiredColor(colors, "foreground");
  const accent = requiredColor(colors, "accent");
  if (!background || !foreground || !accent) return null;

  const muted = colors.color8 ?? foreground;
  const red = colors.color1 ?? accent;
  const green = colors.color2 ?? accent;
  const pink = colors.color3 ?? accent;
  const blue = colors.color4 ?? accent;
  const magenta = colors.color5 ?? accent;
  const cyan = colors.color6 ?? accent;
  const brightRed = colors.color9 ?? red;
  const brightGreen = colors.color10 ?? green;
  const brightPink = colors.color11 ?? pink;
  const brightBlue = colors.color12 ?? blue;
  const brightMagenta = colors.color13 ?? magenta;
  const brightCyan = colors.color14 ?? cyan;
  const brightForeground = colors.color15 ?? foreground;

  return `
html:root,
html:root.dark {
  color-scheme: dark;
  --background: ${background};
  --app-chrome-background: ${background};
  --foreground: ${foreground};
  --card: color-mix(in srgb, ${background} 92%, ${accent});
  --card-foreground: ${foreground};
  --popover: color-mix(in srgb, ${background} 90%, ${accent});
  --popover-foreground: ${foreground};
  --primary: ${accent};
  --primary-foreground: ${brightForeground};
  --secondary: color-mix(in srgb, ${background} 72%, ${blue});
  --secondary-foreground: ${foreground};
  --muted: color-mix(in srgb, ${background} 76%, ${muted});
  --muted-foreground: color-mix(in srgb, ${foreground} 62%, ${muted});
  --accent: color-mix(in srgb, ${accent} 42%, ${background});
  --accent-foreground: ${foreground};
  --destructive: ${red};
  --destructive-foreground: ${brightRed};
  --border: color-mix(in srgb, ${foreground} 14%, transparent);
  --input: color-mix(in srgb, ${foreground} 18%, transparent);
  --ring: ${brightBlue};
  --info: ${cyan};
  --info-foreground: ${brightCyan};
  --success: ${green};
  --success-foreground: ${brightGreen};
  --warning: ${pink};
  --warning-foreground: ${brightPink};
  --aether-magenta: ${magenta};
  --aether-magenta-bright: ${brightMagenta};
}

html:root body,
html:root.dark body {
  background:
    radial-gradient(circle at 18% 12%, color-mix(in srgb, ${brightBlue} 18%, transparent), transparent 28rem),
    radial-gradient(circle at 82% 10%, color-mix(in srgb, ${brightMagenta} 12%, transparent), transparent 24rem),
    ${background};
}
`.trim();
}

function readAetherThemeCss(input: {
  readonly fileSystem: FileSystem.FileSystem;
  readonly colorsPath: string;
}): Effect.Effect<string | null> {
  const colorsPath = process.env.AETHER_COLORS_FILE ?? input.colorsPath;
  return input.fileSystem.readFileString(colorsPath).pipe(
    Effect.map((raw) => createAetherThemeCss(readTomlStringValues(raw))),
    Effect.catch(() => Effect.succeed(null)),
  );
}

function toWebSocketBaseUrl(httpBaseUrl: URL): string {
  const url = new URL(httpBaseUrl.href);
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
  return url.href;
}

export const getAppBranding = makeSyncIpcMethod({
  channel: IpcChannels.GET_APP_BRANDING_CHANNEL,
  result: Schema.NullOr(DesktopAppBrandingSchema),
  handler: Effect.fn("desktop.ipc.window.getAppBranding")(function* () {
    const environment = yield* DesktopEnvironment.DesktopEnvironment;
    return environment.branding;
  }),
});

export const getLocalEnvironmentBootstrap = makeSyncIpcMethod({
  channel: IpcChannels.GET_LOCAL_ENVIRONMENT_BOOTSTRAP_CHANNEL,
  result: Schema.NullOr(DesktopEnvironmentBootstrapSchema),
  handler: Effect.fn("desktop.ipc.window.getLocalEnvironmentBootstrap")(function* () {
    const backendManager = yield* DesktopBackendManager.DesktopBackendManager;
    const config = yield* backendManager.currentConfig;
    return Option.match(config, {
      onNone: () => null,
      onSome: ({ bootstrap, httpBaseUrl }) => ({
        label: "Local environment",
        httpBaseUrl: httpBaseUrl.href,
        wsBaseUrl: toWebSocketBaseUrl(httpBaseUrl),
        ...(bootstrap.desktopBootstrapToken
          ? { bootstrapToken: bootstrap.desktopBootstrapToken }
          : {}),
      }),
    });
  }),
});

export const pickFolder = makeIpcMethod({
  channel: IpcChannels.PICK_FOLDER_CHANNEL,
  payload: Schema.UndefinedOr(PickFolderOptionsSchema),
  result: Schema.NullOr(Schema.String),
  handler: Effect.fn("desktop.ipc.window.pickFolder")(function* (options) {
    const dialog = yield* ElectronDialog.ElectronDialog;
    const electronWindow = yield* ElectronWindow.ElectronWindow;
    const environment = yield* DesktopEnvironment.DesktopEnvironment;
    const selectedPath = yield* dialog.pickFolder({
      owner: yield* electronWindow.focusedMainOrFirst,
      defaultPath: environment.resolvePickFolderDefaultPath(options),
    });
    return Option.getOrNull(selectedPath);
  }),
});

export const confirm = makeIpcMethod({
  channel: IpcChannels.CONFIRM_CHANNEL,
  payload: Schema.String,
  result: Schema.Boolean,
  handler: Effect.fn("desktop.ipc.window.confirm")(function* (message) {
    const dialog = yield* ElectronDialog.ElectronDialog;
    const electronWindow = yield* ElectronWindow.ElectronWindow;
    return yield* electronWindow.focusedMainOrFirst.pipe(
      Effect.flatMap((owner) => dialog.confirm({ owner, message })),
    );
  }),
});

export const setTheme = makeIpcMethod({
  channel: IpcChannels.SET_THEME_CHANNEL,
  payload: DesktopThemeSchema,
  result: Schema.Void,
  handler: Effect.fn("desktop.ipc.window.setTheme")(function* (theme) {
    const electronTheme = yield* ElectronTheme.ElectronTheme;
    yield* electronTheme.setSource(theme);
  }),
});

export const getAetherThemeCss = makeIpcMethod({
  channel: IpcChannels.GET_AETHER_THEME_CSS_CHANNEL,
  payload: Schema.Void,
  result: Schema.NullOr(Schema.String),
  handler: Effect.fn("desktop.ipc.window.getAetherThemeCss")(function* () {
    const environment = yield* DesktopEnvironment.DesktopEnvironment;
    const fileSystem = yield* FileSystem.FileSystem;
    return yield* readAetherThemeCss({
      fileSystem,
      colorsPath: environment.path.join(
        environment.homeDirectory,
        ".config/aether/theme/colors.toml",
      ),
    });
  }),
});

export const showContextMenu = makeIpcMethod({
  channel: IpcChannels.CONTEXT_MENU_CHANNEL,
  payload: ContextMenuInput,
  result: Schema.NullOr(Schema.String),
  handler: Effect.fn("desktop.ipc.window.showContextMenu")(function* (input) {
    const electronMenu = yield* ElectronMenu.ElectronMenu;
    const electronWindow = yield* ElectronWindow.ElectronWindow;
    const window = yield* electronWindow.focusedMainOrFirst;
    if (Option.isNone(window)) {
      return null;
    }

    const selectedItemId = yield* electronMenu.showContextMenu({
      window: window.value,
      items: input.items,
      position: Option.fromNullishOr(input.position),
    });
    return Option.getOrNull(selectedItemId);
  }),
});

export const openExternal = makeIpcMethod({
  channel: IpcChannels.OPEN_EXTERNAL_CHANNEL,
  payload: Schema.String,
  result: Schema.Boolean,
  handler: Effect.fn("desktop.ipc.window.openExternal")(function* (url) {
    const shell = yield* ElectronShell.ElectronShell;
    return yield* shell.openExternal(url);
  }),
});
