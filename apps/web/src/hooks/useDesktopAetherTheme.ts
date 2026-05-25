import { useEffect } from "react";

import { syncBrowserChromeTheme } from "./useTheme";

const STYLE_ELEMENT_ID = "t3-code-fork-aether-theme";
const POLL_INTERVAL_MS = 1000;

let lastAppliedCss: string | null = null;

function ensureStyleElement(): HTMLStyleElement {
  let element = document.getElementById(STYLE_ELEMENT_ID) as HTMLStyleElement | null;
  if (element) return element;

  element = document.createElement("style");
  element.id = STYLE_ELEMENT_ID;
  document.head.append(element);
  return element;
}

function applyAetherThemeCss(css: string | null) {
  if (css === lastAppliedCss) return;
  lastAppliedCss = css;

  if (!css) {
    document.getElementById(STYLE_ELEMENT_ID)?.remove();
    syncBrowserChromeTheme();
    return;
  }

  ensureStyleElement().textContent = css;
  syncBrowserChromeTheme();
}

export function useDesktopAetherTheme() {
  useEffect(() => {
    const getAetherThemeCss = window.desktopBridge?.getAetherThemeCss;
    if (!getAetherThemeCss) return;

    let cancelled = false;

    const refresh = () => {
      void getAetherThemeCss()
        .then((css) => {
          if (!cancelled) applyAetherThemeCss(css);
        })
        .catch(() => {
          if (!cancelled) applyAetherThemeCss(null);
        });
    };

    refresh();
    const interval = window.setInterval(refresh, POLL_INTERVAL_MS);

    return () => {
      cancelled = true;
      window.clearInterval(interval);
    };
  }, []);
}
